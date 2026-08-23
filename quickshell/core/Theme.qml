pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Single source of truth for WHAT COLORS + METRICS the Island uses.
 *
 * Themes are fixed palettes (see themes/*.json) -- picking a wallpaper never
 * changes colors, only switching theme does. This singleton only READS
 * files directly (themes/*.json, the persisted state file); all WRITES go
 * through scripts/island-set-theme.sh and island-set-metric.sh so there is
 * exactly one code path that mutates theme state on disk, and it's testable
 * outside of Quickshell entirely. See ARCHITECTURE.md sections 2 and 4.
 *
 * NOTE: written against Quickshell's documented FileView/Process API. Not
 * runtime-tested against a live Quickshell instance -- verify FileView's
 * exact read/reload signature against your installed version before
 * treating this as final.
 */
QtObject {
    id: root

    readonly property string islandDir: Quickshell.shellDir
    readonly property string themesDir: islandDir + "/themes"
    readonly property string scriptsDir: islandDir + "/scripts"
    readonly property string stateFile:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/island/theme.json"

    readonly property var themeNames: [
        "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha",
        "gruvbox", "gruvbox-material", "everforest",
        "horizon", "anime", "ariadne", "e-ink", "industrial"
    ]

    property var themes: ({})       // name -> parsed theme object
    property string activeName: "catppuccin-mocha"
    property int barHeight: 37
    property int fontSize: 15

    readonly property var active: themes[activeName] ?? null

    readonly property var fallbackColors: ({
        bg: "#000000", surface: "#111111", surfaceHover: "#222222",
        accent: "#888888", text: "#ffffff", textMuted: "#aaaaaa",
        danger: "#ff4444", success: "#44ff44", warning: "#ffaa44"
    })
    readonly property var colors: active ? active.colors : fallbackColors
    readonly property var wallpapers: active ? (active.wallpapers ?? []) : []
    readonly property bool einkMode: activeName === "e-ink"
    readonly property string fontFamily: Config.fontFamily

    signal themesReady()
    property int _loadedCount: 0

    // -- public actions: shell out, then optimistically update in-memory
    // state so the UI feels instant instead of waiting on a disk round trip --

    function setTheme(name) {
        if (!themes[name] || name === activeName) return
        activeName = name
        setThemeProcess.command = [scriptsDir + "/island-set-theme.sh", name]
        setThemeProcess.running = true
    }

    function setBarHeight(px) {
        barHeight = px
        setMetricProcess.command = [scriptsDir + "/island-set-metric.sh", "bar-height", String(px)]
        setMetricProcess.running = true
    }

    function setFontSize(px) {
        fontSize = px
        setMetricProcess.command = [scriptsDir + "/island-set-metric.sh", "font-size", String(px)]
        setMetricProcess.running = true
    }

    function applyWallpaper(relativePath) {
        applyWallpaperProcess.command = [scriptsDir + "/apply-wallpaper.sh", islandDir + "/wallpapers/" + relativePath]
        applyWallpaperProcess.running = true
    }

    property Process setThemeProcess: Process {
        onExited: (code) => { if (code !== 0) console.warn("Theme: island-set-theme.sh failed", code) }
    }
    property Process setMetricProcess: Process {
        onExited: (code) => { if (code !== 0) console.warn("Theme: island-set-metric.sh failed", code) }
    }
    property Process applyWallpaperProcess: Process {
        onExited: (code) => { if (code !== 0) console.warn("Theme: apply-wallpaper.sh failed", code) }
    }

    // -- loading: one FileView per theme file, plus the persisted state file --

    property Component _themeLoader: Component {
        FileView {
            id: fv
            property string themeName: ""
            path: root.themesDir + "/" + themeName + ".json"
            onLoaded: {
                try {
                    const parsed = JSON.parse(text())
                    const merged = Object.assign({}, root.themes)
                    merged[fv.themeName] = parsed
                    root.themes = merged
                } catch (e) {
                    console.warn("Theme: failed to parse", fv.themeName, e)
                } finally {
                    root._loadedCount += 1
                    if (root._loadedCount === root.themeNames.length) root.themesReady()
                }
            }
            onLoadFailed: (error) => console.warn("Theme: could not read", path, error)
        }
    }

    property FileView _stateFileView: FileView {
        path: root.stateFile
        onLoaded: {
            try {
                const s = JSON.parse(text())
                if (s.active) root.activeName = s.active
                if (s.barHeight !== undefined) root.barHeight = s.barHeight
                if (s.fontSize !== undefined) root.fontSize = s.fontSize
            } catch (e) {
                console.warn("Theme: failed to parse state file", e)
            }
        }
        onLoadFailed: (error) => {
            // first run: no state file yet, defaults above stand
            console.log("Theme: no persisted state yet, using defaults")
        }
    }

    Component.onCompleted: {
        for (const name of themeNames) {
            _themeLoader.createObject(root, { themeName: name })
        }
    }
}
