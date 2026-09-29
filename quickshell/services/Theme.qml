pragma Singleton
// qmllint disable import
// qmllint disable signal-handler-parameters

import QtQuick
import Quickshell
import Quickshell.Io

/*
  Theme service — v0.3.0 + KISS + system-driven.

  Color/theme data lives in ~/.config/colors (hand-authored palettes +
  wallpaper catalogs). Nothing in this Quickshell tree is a palette source
  of truth.

  Discovery via scripts/list-themes.py (no hardcoded names). The script outputs
  the same shape as the old central themes.json but generated live:
    { "default": "everforest", "current": "everforest", "themes": { "ariadne": { "name": "...", "wallpapers": [...], "colors": {...} } } }

  Colors: purely static. The active theme's own
  colors/themes/<name>/colors.json *is* the palette — there is no wallpaper
  sampling, no generator, and no dynamic override. ThemePicker/settings/IPC
  pick a name; that file's colors are applied in-shell and published out to
  ~/.config/colors for the rest of the desktop by scripts/publish-colors.py.
*/

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string colorsRoot: home + "/.config/colors"
    readonly property string themesRoot: colorsRoot
    readonly property string scriptPath: Quickshell.shellDir + "/scripts/list-themes.py"
    readonly property string statePath: Quickshell.statePath("theme-state.json")

    property var presets: ({})
    property string currentName: ""
    property var wallpaperIndex: ({})

    readonly property var current: presets[currentName] ? presets[currentName] : null
    // Colors: the active theme's own static palette, with a last-resort
    // fallback if discovery hasn't landed (or the theme has no colors.json).
    readonly property var _targetColors: (current && current.colors) ? current.colors : _fallbackColors
    property var _fromColors: _fallbackColors
    property var _displayedColors: _targetColors
    property real _colorProgress: 1
    readonly property var colors: _displayedColors

    // ── Dark-surface tokens ───────────────────────────────────────────
    //
    // `colors.background` and `colors.surface` are NOT usable as the fill for
    // this shell's panels and cards. In ariadne they are #046e5e and #059d86 --
    // saturated teals, authored for a *light* theme's page and card
    // backgrounds. Every surface that used them rendered teal: the power menu's
    // "inactive" tiles, the launcher, the clipboard, the Wi-Fi and audio
    // dialogs, and Surface's own default backgroundColor.
    //
    // These three are derived from the theme's `foreground` instead, so they
    // stay warm or cool with the theme rather than hardcoding ariadne's cast:
    //
    //   panelFill     #000000        the panel body -- measured off
    //                                 2026-09-20_22-25-51 and 22-28-15
    //   surfaceCard   foreground@6.3%  -> (16,14,12) in ariadne; the settings
    //                                 app's cards (2026-09-20_22-30-18)
    //   surfaceRaised foreground@10.5% -> (24,22,20) in ariadne; the control
    //                                 centre's cards and the power menu's
    //                                 tiles (2026-09-20_22-28-15)
    readonly property color panelFill: "#000000"
    readonly property color surfaceCard: Qt.alpha(colors.foreground, 0.063)
    readonly property color surfaceRaised: Qt.alpha(colors.foreground, 0.105)

    // Tide compatibility — KISS aliases used by Tide-style SettingsApp
    readonly property bool darkMode: _isDarkPreset()
    // Back-compat for surfaces that cache colors.accent etc.
    readonly property string displayName: current ? current.name : currentName

    // Wallpaper — system-discovered, not hardcoded, with crossfade
    readonly property var _wallpapers: (current && current.wallpapers) ? current.wallpapers : []
    readonly property int currentWallpaperIndex: Math.min((wallpaperIndex[currentName] !== undefined ? wallpaperIndex[currentName] : 0), Math.max(0, _wallpapers.length - 1))
    function _fileUrl(path) {
        if (!path) return "";
        const s = path.toString();
        if (s.startsWith("file://")) return s;
        if (s.startsWith("/")) return "file://" + s;
        return "file://" + root.colorsRoot + "/" + s;
    }

    readonly property string currentWallpaper: _wallpapers.length > 0
        ? _fileUrl(_wallpapers[currentWallpaperIndex])
        : ""
    // For QML wallpaper view crossfade
    property string _wallpaperFrom: ""
    property string wallpaperFrom: _wallpaperFrom
    property string wallpaperTo: currentWallpaper
    property real wallpaperProgress: 1  // 0→1 during crossfade
    property bool wallpaperTransitioning: wallpaperProgress < 1

    readonly property var pickerModel: {
        let out = [];
        for (let key in presets) {
            const t = presets[key];
            const accent = (t.colors && t.colors.accent) ? t.colors.accent : _fallbackColors.accent;
            const bg = (t.colors && t.colors.background) ? t.colors.background : _fallbackColors.background;
            out.push({
                key: key,
                name: t.name ? t.name : key,
                accent: accent,
                cardColor: bg,
                selected: key === currentName,
                // Real per-theme data only has 3-4 distinct accent-family
                // hues (accent/danger/warning/success), often with
                // duplicates — not enough for an honest hand-authored
                // multi-color palette. Derived instead of invented: hue-
                // rotated around the theme's real accent, so it's an
                // actual reflection of that theme's color, not a guess
                // at colors the theme doesn't define.
                swatchColors: [
                    (t.colors && t.colors.accent) ? t.colors.accent : accent,
                    (t.colors && t.colors.success) ? t.colors.success : accent,
                    (t.colors && t.colors.warning) ? t.colors.warning : accent,
                    (t.colors && t.colors.danger) ? t.colors.danger : ((t.colors && t.colors.error) ? t.colors.error : accent),
                    (t.colors && t.colors.textMuted) ? t.colors.textMuted : ((t.colors && t.colors.muted) ? t.colors.muted : accent),
                    (t.colors && t.colors.surfaceAlt) ? t.colors.surfaceAlt : bg
                ],
            });
        }
        return out;
    }

    // Six hue-rotated variants of a base accent color — same lightness/
    // saturation family, spread around the color wheel. Used for the
    // theme picker's multi-dot preview (see pickerModel above).
    // A plain JS array, not a ListModel.
    //
    // WallpaperPicker reads its list as an array -- `wallpapers.length`,
    // `wallpapers[i].selected`, a for-loop over it -- and a ListModel has no
    // `length`, so passing one left the picker holding `undefined`: the grid
    // rendered empty and the footer fell through to its zero branch and showed
    // "0/0" instead of the reference's "6/12 · Enter to apply".
    //
    // Reassigned rather than mutated, so bindings on it re-evaluate.
    property var wallpaperPickerModel: []

    function rebuildPickerModel() {
        const theme = root.presets[root.currentName];
        const wallpapers = (theme && theme.wallpapers) ? theme.wallpapers : [];
        const savedIndex = Number(root.wallpaperIndex[root.currentName] !== undefined ? root.wallpaperIndex[root.currentName] : 0);
        const selectedIndex = wallpapers.length > 0
            ? Math.min(savedIndex, wallpapers.length - 1)
            : -1;

        const out = [];
        for (let index = 0; index < wallpapers.length; index++) {
            const path = wallpapers[index];
            out.push({
                themeKey: root.currentName,
                source: root._fileUrl(path),
                fileName: String(path).split("/").pop(),
                selected: index === selectedIndex
            });
        }
        root.wallpaperPickerModel = out;
    }

    readonly property var _fallbackColors: ({
        background: "#202020", surface: "#282828", surfaceAlt: "#303030",
        surfaceElevated: "#383838", surfaceMuted: "#b0282828",
        border: "#404040", divider: "#30404040",
        foreground: "#f0f0f0", muted: "#b0b0b0",
        text: "#f0f0f0", textMuted: "#b0b0b0",
        accent: "#88c0d0", accentVariant: "#6aa8b8", accentText: "#202020",
        error: "#e06060", danger: "#e06060", warning: "#e0c060", success: "#60c080"
    })

    signal themeChanged(string name)
    signal wallpaperChanged(string source)

    onWallpaperChanged: (source) => {
        if (!source) return;
        const path = source.replace("file://", "");
        root._applyWallpaper(path);
    }

    function _applyWallpaper(path) {
        wallpaperApply.command = ["bash", "-c",
            'p="' + path.replace(/"/g, '\\"') + '"; ' +
            'if command -v hyprctl >/dev/null 2>&1; then ' +
            '  hyprctl hyprpaper preload "$p" >/dev/null 2>&1; ' +
            '  hyprctl hyprpaper wallpaper ",$p" >/dev/null 2>&1 && exit 0; ' +
            '  hyprctl hyprpaper reload ",$p" >/dev/null 2>&1 && exit 0; ' +
            'fi; ' +
            'if command -v swww >/dev/null 2>&1; then swww img "$p" --transition-type fade --transition-duration 0.38; exit 0; fi; ' +
            'pkill -x swaybg >/dev/null 2>&1; swaybg -o "*" -i "$p" -m fill &'
        ];
        wallpaperApply.running = true;
    }
    Process { id: wallpaperApply }

    // --- macOS-like smooth color interpolation ---
    function _lerpHex(a, b, t) {
        // Interpolate two hex colors (with optional alpha #AARRGGBB)
        let hasAlpha = a.length === 9 || b.length === 9;
        let ah = a, bh = b;
        let aAlpha = 1, bAlpha = 1;
        if (ah.length === 9) { aAlpha = parseInt(ah.slice(1,3),16)/255; ah = "#" + ah.slice(3); }
        if (bh.length === 9) { bAlpha = parseInt(bh.slice(1,3),16)/255; bh = "#" + bh.slice(3); }
        const ca = _hexToRgb(ah), cb = _hexToRgb(bh);
        const r = Math.round(ca.r + (cb.r - ca.r) * t);
        const g = Math.round(ca.g + (cb.g - ca.g) * t);
        const b_ = Math.round(ca.b + (cb.b - ca.b) * t);
        const hex = _toHex(r,g,b_);
        if (hasAlpha) {
            const alpha = Math.round((aAlpha + (bAlpha - aAlpha)*t)*255);
            return "#" + alpha.toString(16).padStart(2,"0") + hex.slice(1);
        }
        return hex;
    }
    function _interpolateColors(from, to, t) {
        if (!from || !to) return to ? to : (from ? from : _fallbackColors);
        let out = {};
        const keys = new Set([...Object.keys(from), ...Object.keys(to)]);
        for (const k of keys) {
            const fv = from[k], tv = to[k];
            if (typeof fv === "string" && typeof tv === "string" && fv.startsWith("#") && tv.startsWith("#")) {
                out[k] = _lerpHex(fv, tv, t);
            } else out[k] = t < 0.5 ? fv : tv;
        }
        return out;
    }
    function _startColorTransition() {
        if (wallpaperApplied) {
            _fromColors = _displayedColors;
            _colorProgress = 0;
            _colorAnim.restart();
        } else {
            _displayedColors = _targetColors;
            _colorProgress = 1;
        }
    }
    function _startWallpaperTransition(newWall) {
        if (!wallpaperApplied || !newWall || wallpaperProgress < 1) {
            _wallpaperFrom = "";
        } else {
            _wallpaperFrom = wallpaperTo;
        }
        wallpaperTo = newWall;
        wallpaperProgress = 0;
        _wallpaperAnim.restart();
    }

    // Color transition — duration follows the Motion page's "Fades &
    // colour" slider (MotionConfig.fadeMs), same as every color fade
    // elsewhere in the app. Snaps instantly when Reduce Motion is on.
    NumberAnimation {
        id: _colorAnim
        target: root
        property: "_colorProgress"
        from: 0; to: 1
        duration: MotionConfig.fade()
        easing.type: Easing.OutCubic
        onFinished: { root._displayedColors = root._targetColors; }
    }
    on_ColorProgressChanged: {
        if (_colorProgress >= 1) _displayedColors = _targetColors;
        else _displayedColors = _interpolateColors(_fromColors, _targetColors, _colorProgress);
    }
    on_TargetColorsChanged: _startColorTransition()

    // Wallpaper crossfade — also a "fade", same slider. Runs a little
    // longer than a plain color fade reads as (1.6x) since it's
    // dissolving a whole image, not a swatch — proportional to the
    // live setting rather than a second fixed constant.
    NumberAnimation {
        id: _wallpaperAnim
        target: root
        property: "wallpaperProgress"
        from: 0; to: 1
        duration: ConfigStore.wallpaperTransitionDuration > 0 ? ConfigStore.wallpaperTransitionDuration : MotionConfig.fade(1.6)
        easing.type: Easing.InOutCubic
    }
    onCurrentWallpaperChanged: {
        if (currentWallpaper && wallpaperApplied) _startWallpaperTransition(currentWallpaper);
        else {
            wallpaperTo = currentWallpaper;
            _wallpaperFrom = "";
            wallpaperProgress = 1;
        }
    }

    function _isDarkPreset() {
        // Static palette only — no dynamic override to consult.
        let bg = "#202020";
        if (_targetColors && _targetColors.background) bg = _targetColors.background;
        return _hexLightness(bg) < 0.5;
    }
    function _hexToRgb(hex) {
        let h = hex.replace("#", "");
        if (h.length === 3) h = h.split("").map(ch => ch + ch).join("");
        const num = parseInt(h, 16);
        return { r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255 };
    }
    function _hexLightness(hex) {
        const c = _hexToRgb(hex);
        const r = c.r / 255, g = c.g / 255, b = c.b / 255;
        return (Math.max(r, g, b) + Math.min(r, g, b)) / 2;
    }
    function _toHex(r, g, b) {
        const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
        const pad = (v) => clamp(v).toString(16).padStart(2, "0");
        return "#" + pad(r) + pad(g) + pad(b);
    }
    // Public: translucent variant of any theme color. Accepts "#RRGGBB",
    // "#AARRGGBB" (alpha replaced), or a color object. Surfaces use this
    // for icon washes and near-opaque panel backgrounds.
    function withAlpha(c, alpha01) {
        let h = String(c).replace("#", "");
        if (h.length === 8) h = h.slice(2);
        const a = Math.max(0, Math.min(255, Math.round(alpha01 * 255)));
        return "#" + a.toString(16).padStart(2, "0") + h;
    }

    // ---- Publish the active theme's static palette to the rest of the
    // desktop (~/.config/colors: hyprland.conf, colors.css/.sh, gtk.css).
    // This is the whole "apply theme" story now: the hand-authored
    // colors/themes/<name>/colors.json is both what the shell renders and
    // what gets written out for Hyprland/GTK. ----
    readonly property string publishScript: Quickshell.shellDir + "/scripts/publish-colors.py"

    function publish(themeName) {
        const name = themeName || currentName;
        if (!name) return;
        publisher.command = ["python3", publishScript, name];
        publisher.running = true;
    }
    Process {
        id: publisher
        stdout: StdioCollector {}
        stderr: StdioCollector { id: pubErr }
        onExited: (code) => {
            if (code !== 0) console.warn("Theme: publish-colors failed for", currentName, pubErr.text);
        }
    }

    function setTheme(name) {
        if (!presets[name] || name === currentName) return;

        currentName = name;
        // Keep savedTheme in step. It is what applyPresets() treats
        // as the authoritative selection, and discovery re-runs whenever
        // anything under colors/ changes — including this theme's own
        // publish-colors.py output. Left stale, the next re-run would snap
        // the shell back to the theme it booted with.
        savedTheme = name;
        rebuildPickerModel();
        saveState();

        // Push this theme's own static colors out to Hyprland/GTK/CSS —
        // without this, only Theme.qml's own in-shell `colors` binding
        // ever changed, and border colors and GTK apps kept whatever
        // theme was last actually published.
        publish(name);

        themeChanged(name);
        wallpaperChanged(currentWallpaper);
    }
    function selectByPickerIndex(index) {
        const entry = pickerModel[index];
        if (entry) setTheme(entry.key);
    }
    function cycleTheme() {
        const keys = Object.keys(presets);
        if (keys.length === 0) return;
        const idx = keys.indexOf(currentName);
        setTheme(keys[(idx + 1) % keys.length]);
    }
    function setWallpaper(index) {
        if (index < 0 || index >= _wallpapers.length) return;

        let updated = Object.assign({}, wallpaperIndex);
        updated[currentName] = index;
        wallpaperIndex = updated;

        rebuildPickerModel();
        saveState();
        wallpaperChanged(currentWallpaper);
    }
    function cycleWallpaper() {
        if (_wallpapers.length === 0) return;
        setWallpaper((currentWallpaperIndex + 1) % _wallpapers.length);
    }

    // ---- Discovery from ~/.config/colors (never this repo) ----
    Process {
        id: discovery
        command: ["python3", root.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.applyPresets(data);
                } catch (e) {
                    console.warn("Theme: failed to parse discovery output:", e, text.slice(0, 500));
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) console.warn("Theme: discovery script failed code", code);
        }
    }

    Process {
        id: watcher
        command: [Quickshell.shellDir + "/scripts/inotify-watch.py", "-r", root.colorsRoot]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => debouncedReload.restart()
        }
        onExited: (code) => restartWatcher.start()
    }
    Timer { id: restartWatcher; interval: 3000; onTriggered: watcher.running = true }
    Timer { id: debouncedReload; interval: 400; onTriggered: discovery.running = true }

    Component.onCompleted: {
        rebuildPickerModel();
        discovery.running = true;
    }

    FileView {
        id: indexWatcher
        path: root.colorsRoot + "/index.json"
        watchChanges: true
        printErrors: false
        onFileChanged: discovery.running = true
    }

    // ---- Startup ordering ----
    // The theme list and the saved state arrive independently and in either
    // order, so nothing may decide currentName until both have landed.
    // resolveTheme() is the single decider and simply does nothing until
    // then; whichever side arrives second triggers it. That replaces a
    // four-branch chain which had to re-check the same conditions in
    // different combinations.
    property bool presetsResolved: false
    property bool stateResolved: false
    property bool wallpaperApplied: false
    // The theme theme-state.json holds, or the one just picked in ThemePicker.
    property string savedTheme: ""
    // colors/index.json's `current`, with `default` as its seed. Declarative
    // only: it sets the theme on a machine that has never chosen one.
    property string declaredTheme: ""

    FileView {
        id: stateLoader
        path: root.statePath
        watchChanges: false
        printErrors: true
        onLoaded: { applyState(text()); stateResolved = true; resolveTheme(); applyInitialWallpaper(); }
        onLoadFailed: (err) => { console.warn("Theme: failed to load state", root.statePath, err); stateResolved = true; resolveTheme(); applyInitialWallpaper(); }
    }
    FileView {
        id: stateWriter
        path: root.statePath
        // writer-only: don't duplicate read error (loader already shows it)
        printErrors: false
    }

    // The one place the active theme is decided. Precedence, highest first:
    //   1. savedTheme     — what theme-state.json holds, or was just picked
    //   2. declaredTheme  — colors/index.json's `current`, the declarative knob
    //   3. the first theme that exists
    // Does nothing until both the theme list and the saved state have
    // arrived, so the order they turn up in cannot change the answer, and a
    // saved theme that no longer exists (a rename) falls through on its own.
    function resolveTheme() {
        if (!presetsResolved || !stateResolved) return;
        const keys = Object.keys(presets);
        if (keys.length === 0) return;

        let wanted = keys[0];
        if (declaredTheme && presets[declaredTheme]) wanted = declaredTheme;
        if (savedTheme && presets[savedTheme]) wanted = savedTheme;
        if (currentName !== wanted) currentName = wanted;
    }

    function applyInitialWallpaper() {
        if (wallpaperApplied || !presetsResolved || !stateResolved) return;
        wallpaperApplied = true;
        if (currentWallpaper) wallpaperChanged(currentWallpaper);
        else if (_wallpapers.length === 0) console.warn("Theme: no wallpapers discovered for", currentName);
        // resolveTheme() has now run with both sides loaded, so currentName is
        // final and this is the one place that knows which theme the desktop
        // should be on at startup. Without it the shell would render the
        // saved theme while hyprland.conf/gtk/css still held the last
        // published one.
        publish(currentName);
    }

    function applyPresets(data) {
        try {
            root.presets = (data && data.themes) ? data.themes : {};
            root.declaredTheme = (data && data.current) || (data && data.default) || "";
        } catch (e) {
            console.warn("Theme: applyPresets failed", e);
        }

        rebuildPickerModel();
        presetsResolved = true;
        resolveTheme();
        applyInitialWallpaper();
    }

    function applyState(jsonText) {
        try {
            const data = JSON.parse(jsonText);
            // Only record the choice here. resolveTheme() owns currentName, so
            // that it can check the theme still exists before adopting it.
            if (data.theme) savedTheme = data.theme;
            if (data.wallpaperIndex) wallpaperIndex = data.wallpaperIndex;
            rebuildPickerModel();
        } catch (e) {
            console.warn("Theme: failed to parse state", root.statePath, e);
        }
    }
    function saveState() {
        stateWriter.setText(JSON.stringify({
            theme: currentName,
            wallpaperIndex: wallpaperIndex
        }));
    }

    IpcHandler {
        target: "theme"
        // Every read goes through `root.` on purpose. Qualified reads return
        // live values; unqualified ones inside IpcHandler resolve against a
        // context that doesn't see later assignments, so `get` reported the
        // startup theme forever. Likewise a handler must not call a
        // same-named function unqualified — `cycleWallpaper` recursed into
        // itself until RangeError. Don't undo either.
        function get(): string { return root.currentName; }
        function set(name: string): void { setTheme(name); }
        function cycle(): void { cycleTheme(); }
        function list(): string { return Object.keys(root.presets).join("\n"); }
        function getWallpaper(): string { return root.currentWallpaper; }
        function cycleWallpaper(): void { root.cycleWallpaper(); }
        function publish(theme: string): void { root.publish(theme); }
    }
}
