pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The theme layer: discover the palettes in ~/.config/colors, hold the one
// in use, publish a change, and say which wallpaper is showing.
//
// Discovery and publishing are scripts -- walking wallpaper directories and
// knowing the generated-file list are not QML jobs. Everything else here is
// state: presets, the active name, the per-theme wallpaper index.

Singleton {
    id: root

    readonly property string colorsRoot: Quickshell.env("HOME") + "/.config/colors"

    property var presets: ({})
    property string currentName: ""
    property var wallpaperIndex: ({})

    property bool presetsResolved: false
    property bool stateResolved: false
    property bool initialApplied: false
    property string savedTheme: ""
    property string declaredTheme: ""

    readonly property var current: presets[currentName] ? presets[currentName] : null
    readonly property string displayName: current && current.name ? current.name : currentName

    // What the shell draws with before list-themes.py answers, and the
    // fallback for a theme missing a key. The literals belong here: this is
    // the theme layer, and it is the only place colours are written down.
    readonly property var fallbackColors: ({
        background: "#202020", surface: "#282828", surfaceAlt: "#303030",
        surfaceElevated: "#383838", surfaceMuted: "#b0282828",
        border: "#404040", divider: "#30404040",
        foreground: "#f0f0f0", muted: "#b0b0b0",
        text: "#f0f0f0", textMuted: "#b0b0b0",
        accent: "#88c0d0", accentVariant: "#6aa8b8", accentText: "#202020",
        error: "#e06060", danger: "#e06060", warning: "#e0c060", success: "#60c080"
    })

    // The active palette, with the Appearance-page accent override folded
    // in: one merge at the top means every `Theme.colors.accent` in the
    // tree follows the override without knowing it exists.
    readonly property var colors: {
        const base = current && current.colors ? current.colors : fallbackColors;
        const ovr = Config.accentOverride;
        if (!/^#[0-9a-fA-F]{6}$/.test(ovr)) return base;
        const merged = Object.assign({}, base);
        merged.accent = ovr;
        return merged;
    }

    // The two colours no palette has a say in: the base every translucent
    // surface composites against, and the shell's own near-black chrome
    // (control centre cards, tracks, borders) which is deliberately not
    // themed -- panels read the same on every palette.
    readonly property color panelFill: "#000000"
    readonly property QtObject cc: QtObject {
        readonly property color surface: "#000000"
        readonly property color card: "#171514"
        readonly property color cardHover: "#211e1c"
        readonly property color item: "#25211f"
        readonly property color itemHover: "#302b29"
        readonly property color track: "#080808"
        readonly property color trackCard: "#11100f"
        readonly property color border: "#2d2927"
    }

    signal themeChanged(string name)

    // ---- colour helpers -------------------------------------------------

    // Alpha first, "#aarrggbb", the form Qt parses back as a colour.
    function withAlpha(c, alpha01): string {
        let h = String(c).replace("#", "");
        if (h.length === 8) h = h.slice(2);
        const a = Math.max(0, Math.min(255, Math.round(alpha01 * 255)));
        return "#" + a.toString(16).padStart(2, "0") + h;
    }

    // Every font size passes through here, so the font-size setting is one
    // expression away from everywhere: px(13) at the default 15px is 13.
    function px(v): int {
        return Math.max(1, Math.round(v * Config.fontSize / 15));
    }

    // Colour burst: with it on, each top-level surface gets its own palette
    // colour as its accent. Stable per name, so the island is always the
    // same colour and the control centre always another.
    function accentFor(surface): color {
        if (!Config.colorBurst) return colors.accent;
        const pool = [colors.accent, colors.success, colors.accentVariant || colors.accent, colors.warning];
        let h = 0;
        for (let i = 0; i < surface.length; i++) h = (h * 31 + surface.charCodeAt(i)) >>> 0;
        return pool[h % pool.length];
    }

    // ---- wallpapers -----------------------------------------------------

    readonly property var wallpapers: (current && current.wallpapers) ? current.wallpapers : []
    readonly property int wallpaperIndexCurrent: {
        const i = wallpaperIndex[currentName];
        return Math.min(i === undefined ? 0 : i, Math.max(0, wallpapers.length - 1));
    }

    function fileUrl(path) {
        if (!path) return "";
        if (path.startsWith("file://") || path.startsWith("http")) return path;
        if (path.startsWith("/")) return "file://" + path;
        return "file://" + colorsRoot + "/" + path;
    }

    readonly property string currentWallpaper:
        wallpapers.length > 0 ? fileUrl(wallpapers[wallpaperIndexCurrent]) : ""

    // ---- picker models ---------------------------------------------------

    // One row per theme for the theme picker, alphabetically so the strip
    // and the "n/total" counter agree with each other across reloads.
    function pickerRows() {
        const keys = Object.keys(presets).sort();
        const out = [];
        for (const key of keys) {
            const t = presets[key];
            const c = t.colors || {};
            const accent = c.accent || fallbackColors.accent;
            out.push({
                key: key,
                name: t.name ? t.name : key,
                accent: accent,
                cardColor: c.background || fallbackColors.background,
                selected: key === currentName,
                swatchColors: [
                    c.danger || c.error || accent,
                    c.success || accent,
                    c.warning || accent,
                    c.muted || c.textMuted || accent,
                    c.accentVariant || c.error || accent,
                    c.accent || accent
                ]
            });
        }
        return out;
    }

    // ---- changing theme / wallpaper --------------------------------------

    function setTheme(name) {
        if (!presets[name] || name === currentName) return;
        currentName = name;
        savedTheme = name;
        saveState();
        publish(name);
        themeChanged(name);
    }

    function selectByPickerIndex(index) {
        const rows = pickerRows();
        if (index >= 0 && index < rows.length) setTheme(rows[index].key);
    }

    function cycleTheme() {
        const keys = Object.keys(presets).sort();
        if (keys.length === 0) return;
        const idx = keys.indexOf(currentName);
        setTheme(keys[(idx + 1) % keys.length]);
    }

    function setWallpaper(index) {
        if (index < 0 || index >= wallpapers.length) return;
        const updated = Object.assign({}, wallpaperIndex);
        updated[currentName] = index;
        wallpaperIndex = updated;   // fresh object: `var` handlers only fire on reassignment
        saveState();
    }

    function cycleWallpaper() {
        if (wallpapers.length === 0) return;
        setWallpaper((wallpaperIndexCurrent + 1) % wallpapers.length);
    }

    // ---- discovery --------------------------------------------------------
    //
    // A script, not FileView + JsonAdapter: discovery walks wallpaper
    // directories and merges defaults. That logic lives in list-themes.py;
    // a second copy here would be a second answer to the same question.
    readonly property string discoveryScript: Quickshell.shellDir + "/scripts/list-themes.py"
    readonly property string publishScript: Quickshell.shellDir + "/scripts/publish-colors.py"
    readonly property string stateFile: Quickshell.statePath("theme-state.json")

    Process {
        id: discovery
        command: ["python3", root.discoveryScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.presets = data && data.themes ? data.themes : {};
                    root.declaredTheme = (data && data.current) || (data && data.default) || "";
                } catch (e) {
                    console.warn("Theme: failed to parse discovery output:", e);
                }
                root.presetsResolved = true;
                root.resolveTheme();
                root.applyInitialWallpaper();
            }
        }
        onExited: (code) => { if (code !== 0) console.warn("Theme: discovery script failed", code); }
    }

    function publish(themeName) {
        const name = themeName || currentName;
        if (!name) return;
        publisher.command = ["python3", root.publishScript, name];
        publisher.running = true;
    }

    Process {
        id: publisher
        stdout: StdioCollector {}
        stderr: StdioCollector { id: pubErr }
        onExited: (code) => {
            if (code !== 0) console.warn("Theme: publish-colors failed for", root.currentName, pubErr.text);
        }
    }

    // ---- saved state ------------------------------------------------------
    //
    // Presets and state arrive independently (there may be no state file on
    // a first run); resolveTheme() picks only once both are in.
    FileView {
        id: stateLoader
        path: root.stateFile
        watchChanges: false
        printErrors: false
        onLoaded: { root.applyState(text()); root.stateResolved = true; root.resolveTheme(); root.applyInitialWallpaper(); }
        onLoadFailed: { root.stateResolved = true; root.resolveTheme(); root.applyInitialWallpaper(); }
    }
    FileView {
        id: stateWriter
        path: root.stateFile
        printErrors: false
    }

    function applyState(jsonText) {
        try {
            const d = JSON.parse(jsonText);
            if (d.theme) savedTheme = d.theme;
            if (d.wallpaperIndex) wallpaperIndex = d.wallpaperIndex;
        } catch (e) {
            console.warn("Theme: failed to parse state", e);
        }
    }

    function saveState() {
        stateWriter.setText(JSON.stringify({ theme: currentName, wallpaperIndex: wallpaperIndex }));
    }

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
        if (initialApplied || !presetsResolved || !stateResolved) return;
        initialApplied = true;
        if (wallpapers.length === 0 && currentName)
            console.warn("Theme: no wallpapers discovered for", currentName);
        publish(currentName);
    }

    Component.onCompleted: discovery.running = true

    IpcHandler {
        target: "theme"
        function get(): string { return root.currentName; }
        function set(name: string): void { root.setTheme(name); }
        function cycle(): void { root.cycleTheme(); }
        function list(): string { return Object.keys(root.presets).sort().join("\n"); }
        function getWallpaper(): string { return root.currentWallpaper; }
        function cycleWallpaper(): void { root.cycleWallpaper(); }
        function publish(theme: string): void { root.publish(theme); }
    }
}
