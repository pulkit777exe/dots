pragma Singleton
// qmllint disable import
// qmllint disable signal-handler-parameters

import QtQuick
import Quickshell
import Quickshell.Io

/*
  Theme service — v0.3.0 + KISS + system-driven.

  Color/theme data lives in ~/.config/colors (Iris + wallpaper catalogs).
  Nothing in this Quickshell tree is a palette source of truth.

  Discovery via scripts/list-themes.py (no hardcoded names). The script outputs
  the same shape as the old central themes.json but generated live:
    { "default": "everforest", "themes": { "ariadne": { "name": "...", "wallpapers": [...], "colors": {...} } } }

  Colors: primary source is iris palette for the active wallpaper.
  Preset colors in themes.json are only fallback when iris unavailable or fails.
*/

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string colorsRoot: home + "/.config/colors"
    readonly property string themesRoot: colorsRoot
    readonly property string scriptPath: Quickshell.shellDir + "/scripts/list-themes.py"
    readonly property string statePath: Quickshell.statePath("theme-state.json")

    property var presets: ({})
    property string currentName: "everforest"
    property var wallpaperIndex: ({})
    // Dynamic mode now means "prefer iris when available". Keep toggle for UI compat but default true.
    property bool dynamicMode: true
    property var _dynamicColors: null
    property var _lastIrisPalette: null

    readonly property var current: presets[currentName] ? presets[currentName] : null
    // Colors: iris primary, preset fallback — with macOS-like smooth transition
    readonly property var _targetColors: _dynamicColors ? _dynamicColors : (current ? current.colors : _fallbackColors)
    property var _fromColors: _fallbackColors
    property var _displayedColors: _targetColors
    property real _colorProgress: 1
    readonly property var colors: _displayedColors
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
    function _deriveSwatchPalette(accentHex) {
        const c = Qt.color(accentHex);
        const s = Math.max(c.hslSaturation, 0.35);
        const l = Math.max(Math.min(c.hslLightness, 0.72), 0.4);
        const offsets = [0, 0.13, -0.13, 0.27, -0.27, 0.42];
        return offsets.map(o => Qt.hsla(((c.hslHue + o) % 1 + 1) % 1, s, l, 1));
    }

    ListModel {
        id: _wallpaperListModel
    }
    readonly property var wallpaperPickerModel: _wallpaperListModel

    function _rebuildWallpaperPickerModel() {
        _wallpaperListModel.clear();
        const theme = root.presets[root.currentName];
        const wallpapers = (theme && theme.wallpapers) ? theme.wallpapers : [];
        const savedIndex = Number(root.wallpaperIndex[root.currentName] !== undefined ? root.wallpaperIndex[root.currentName] : 0);
        const selectedIndex = wallpapers.length > 0
            ? Math.min(savedIndex, wallpapers.length - 1)
            : -1;

        for (let index = 0; index < wallpapers.length; index++) {
            const path = wallpapers[index];
            _wallpaperListModel.append({
                themeKey: root.currentName,
                source: root._fileUrl(path),
                fileName: String(path).split("/").pop(),
                selected: index === selectedIndex
            });
        }
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
        if (Iris.available && source) {
            Iris.generate(source, true);
        } else if (!Iris.available) {
            _dynamicColors = null;
        }
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
        if (_initialWallpaperApplied) {
            _fromColors = _displayedColors;
            _colorProgress = 0;
            _colorAnim.restart();
        } else {
            _displayedColors = _targetColors;
            _colorProgress = 1;
        }
    }
    function _startWallpaperTransition(newWall) {
        if (!_initialWallpaperApplied || !newWall || wallpaperProgress < 1) {
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
        if (currentWallpaper && _initialWallpaperApplied) _startWallpaperTransition(currentWallpaper);
        else {
            wallpaperTo = currentWallpaper;
            _wallpaperFrom = "";
            wallpaperProgress = 1;
        }
        // Dynamic mode means colors track the wallpaper, not just the
        // theme — so picking a *different* wallpaper within the same
        // theme needs to re-extract too, not only the initial toggle
        // of dynamic mode itself. Gated on _initialWallpaperApplied so
        // this doesn't also double up with onAvailableChanged's own
        // generate() call on startup.
        if (_initialWallpaperApplied && root.dynamicMode && currentWallpaper && Iris.available) {
            Iris.generate(currentWallpaper, true);
        }
    }

    function _isDarkPreset() {
        // Prefer target bg for iris dark detection
        let bg = "#202020";
        if (_targetColors && _targetColors.background) bg = _targetColors.background;
        else if (_dynamicColors && _dynamicColors.background) bg = _dynamicColors.background;
        else if (root.current && root.current.colors && root.current.colors.background) bg = root.current.colors.background;
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
    function _shiftFurther(hexA, hexB, amount) {
        const a = _hexToRgb(hexA), b = _hexToRgb(hexB);
        return _toHex(b.r + (b.r - a.r) * amount, b.g + (b.g - a.g) * amount, b.b + (b.b - a.b) * amount);
    }
    function _withAlpha(hex, alpha01) {
        return withAlpha(hex, alpha01);
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
    function _luminance(hex) {
        const c = _hexToRgb(hex);
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) / 255;
    }
    // Compute the HSL saturation (chroma level) of a hex color.
    // Returns 0 (gray) to 1 (fully saturated).
    function _hexSaturation(hex) {
        const c = _hexToRgb(hex);
        const r = c.r / 255, g = c.g / 255, b = c.b / 255;
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        if (max === min) return 0;
        const l = (max + min) / 2;
        return (max - min) / (1 - Math.abs(2 * l - 1));
    }
    // Darker tone helper — blend toward black by factor 0-1 (0=no change, 1=black)
    function _darken(hex, factor) {
        const c = _hexToRgb(hex);
        const f = Math.max(0, Math.min(1, factor));
        return _toHex(c.r * (1 - f), c.g * (1 - f), c.b * (1 - f));
    }

    function _remapIrisPalette(p) {
        const surface = p.surface ?? p.bg;

        // Force darker tone: ensure background is at most 0.22 lightness
        // so bright wallpapers don't produce washed light themes.
        let bg = p.bg;
        let surf = surface;
        if (_hexLightness(bg) > 0.28) bg = _darken(bg, 0.22);
        else if (_hexLightness(bg) > 0.22) bg = _darken(bg, 0.10);
        if (_hexLightness(surf) > 0.32) surf = _darken(surf, 0.18);

        // Chroma/saturation detection for monochrome restraint.
        // Check the saturation of the generated accent color from iris.
        // If the palette is low-chroma (monochrome/grayscale wallpaper),
        // clamp surfaces to near-black and accent to neutral silver.
        // This prevents a gray wallpaper from producing a randomly colored island.
        const accentSat = _hexSaturation(p.accent ? p.accent : "#888888");
        const bgSat = _hexSaturation(bg);
        const isMonochrome = accentSat < 0.15 && bgSat < 0.12;

        let finalBg, finalSurf, finalAccent;
        if (isMonochrome) {
            // Monochrome/grayscale: deep near-black surfaces, neutral silver accent
            finalBg = "#111111";
            finalSurf = "#1c1c1c";
            // Use the iris accent lightness to pick a restrained silver shade
            const accentL = _hexLightness(p.accent ? p.accent : "#888888");
            const silverL = Math.max(0.55, Math.min(0.82, accentL * 1.2));
            finalAccent = Qt.hsla(0, 0, silverL, 1).toString();
        } else {
            // Colorful wallpaper: use iris-derived colors normally
            finalBg = bg;
            finalSurf = surf;
            finalAccent = p.accent;
        }

        const surfAlt = _shiftFurther(finalBg, finalSurf, 1.0);

        return {
            background:     finalBg,
            surface:        finalSurf,
            surfaceAlt:     surfAlt,
            surfaceElevated: _shiftFurther(finalSurf, surfAlt, 0.8),
            surfaceMuted:   _withAlpha(finalSurf, 0.7),
            border:         _withAlpha(p.fg, 0.10),
            divider:        _withAlpha(p.fg, 0.07),
            text:           p.fg,
            textMuted:      p.dim ? p.dim : p.fg,
            accent:         finalAccent,
            accentText:     _luminance(finalAccent) > 0.5 ? "#101010" : "#f5f5f5",
            danger:         p.red ? p.red : "#e06060",
            warning:        p.yellow ? p.yellow : "#e0c060",
            success:        p.green ? p.green : "#60c080"
        };
    }


    Connections {
        target: Iris
        function onPaletteGenerated(palette) {
            root._lastIrisPalette = palette;
            root._dynamicColors = _remapIrisPalette(palette);
            Iris.publish(root.currentName);
        }
        function onGenerationFailed(reason) {
            console.warn("Theme: Iris generation failed, using preset fallback:", reason);
            root._dynamicColors = null;
        }
        function onAvailableChanged() {
            if (Iris.available && root.currentWallpaper) {
                Iris.generate(root.currentWallpaper, true);
            } else if (!Iris.available) {
                root._dynamicColors = null;
            }
        }
    }

    function setDynamicMode(value) {
        root.dynamicMode = value;
        root._persist();
        if (value && root.currentWallpaper && Iris.available) {
            Iris.generate(root.currentWallpaper, true);
        } else if (!value) {
            // If user disables, keep preset colors. Don't clear iris cache so re-enable is instant.
            // But respect request: colors from iris is primary, so even if disabled we keep iris if available?
            // For now, honor toggle: false -> use preset
            root._dynamicColors = null;
        }
    }

    function setTheme(name) {
        if (!presets[name] || name === currentName) return;

        currentName = name;
        _rebuildWallpaperPickerModel();
        _persist();

        // Push this preset's own colors out to Hyprland/Kitty/GTK —
        // without this, only Theme.qml's own in-shell `colors` binding
        // ever changed, and border colors, terminal palette, and GTK
        // apps kept whatever theme was last actually published (which
        // only ever happened via Iris's dynamic wallpaper-color path,
        // never from picking a preset here).
        Iris.publishPreset(name, root.colorsRoot + "/themes/" + name + "/colors.json");

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

        _rebuildWallpaperPickerModel();
        _persist();
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
                    root._applyPresetsData(data);
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
        _rebuildWallpaperPickerModel();
        discovery.running = true;
    }

    FileView {
        id: indexWatcher
        path: root.colorsRoot + "/index.json"
        watchChanges: true
        printErrors: false
        onFileChanged: discovery.running = true
    }

    // Loading state — state may load before presets, so keep pending theme until presets arrive
    property bool _presetsResolved: false
    property bool _stateResolved: false
    property bool _initialWallpaperApplied: false
    property string _pendingTheme: ""

    FileView {
        id: stateLoader
        path: root.statePath
        watchChanges: false
        printErrors: true
        onLoaded: { _applyState(text()); _stateResolved = true; _maybeApplyInitialWallpaper(); }
        onLoadFailed: (err) => { console.warn("Theme: failed to load state", root.statePath, err); _stateResolved = true; _maybeApplyInitialWallpaper(); }
    }
    FileView {
        id: stateWriter
        path: root.statePath
        // writer-only: don't duplicate read error (loader already shows it)
        printErrors: false
    }

    function _maybeApplyInitialWallpaper() {
        if (_initialWallpaperApplied || !_presetsResolved || !_stateResolved) return;
        _initialWallpaperApplied = true;
        if (currentWallpaper) wallpaperChanged(currentWallpaper);
        else if (_wallpapers.length === 0) console.warn("Theme: no wallpapers discovered for", currentName);
    }

    function _applyPresetsData(data) {
        try {
            const themes = (data && data.themes) ? data.themes : {};
            root.presets = themes;
            // Honor saved theme even if state loaded before presets (fixes last wallpaper not remembered)
            if (_pendingTheme && themes[_pendingTheme]) {
                root.currentName = _pendingTheme;
            } else if (data.default && themes[data.default] && !stateLoader.loaded && !_pendingTheme) {
                root.currentName = data.default;
            } else if (!themes[currentName] && Object.keys(themes).length > 0) {
                // currentName not in discovered list (e.g., after rename) -> pick default or first
                if (data.default && themes[data.default]) root.currentName = data.default;
                else root.currentName = Object.keys(themes)[0];
            } else if (_pendingTheme && themes[_pendingTheme] && currentName !== _pendingTheme) {
                // State arrived after presets but before _maybeApplyInitialWallpaper
                root.currentName = _pendingTheme;
            }
        } catch (e) {
            console.warn("Theme: _applyPresetsData failed", e);
        }

        _rebuildWallpaperPickerModel();
        _presetsResolved = true;
        _maybeApplyInitialWallpaper();
    }

    function _applyState(jsonText) {
        try {
            const data = JSON.parse(jsonText);
            if (data.theme) {
                _pendingTheme = data.theme;
                // Set immediately; if presets not yet loaded it will be validated in _applyPresetsData
                // Also set currentName now so wallpaperIndex lookup is correct even before presets
                currentName = data.theme;
            }
            if (data.wallpaperIndex) wallpaperIndex = data.wallpaperIndex;
            if (typeof data.dynamicMode === "boolean") dynamicMode = data.dynamicMode;
            _rebuildWallpaperPickerModel();
        } catch (e) {
            console.warn("Theme: failed to parse state", root.statePath, e);
        }
    }
    function _persist() {
        stateWriter.setText(JSON.stringify({
            theme: currentName,
            wallpaperIndex: wallpaperIndex,
            dynamicMode: dynamicMode
        }));
    }

    IpcHandler {
        target: "theme"
        function get(): string { return currentName; }
        function set(name: string): void { setTheme(name); }
        function cycle(): void { cycleTheme(); }
        function list(): string { return Object.keys(presets).join("\n"); }
        function getWallpaper(): string { return currentWallpaper; }
        function cycleWallpaper(): void { cycleWallpaper(); }
        function toggleDynamic(): void { setDynamicMode(!dynamicMode); }
    }
}
