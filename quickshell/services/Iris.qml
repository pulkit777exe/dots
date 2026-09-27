pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
  Iris adapter.

  Iris (Harman1307/iris) is the desktop color generator. It writes
  ~/.cache/iris/*. Quickshell never stores palettes in this repo.

  Shared desktop colors live in ~/.config/colors (current.json, kitty,
  hyprland, gtk, css, sh) via scripts/publish-colors.py.

  Watching ~/.cache/iris/colors.json means `iris <wallpaper>` from a
  terminal updates the shell without a restart.
*/

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheJson: home + "/.cache/iris/colors.json"
    readonly property string colorsDir: home + "/.config/colors"
    readonly property string currentJson: colorsDir + "/current.json"
    readonly property string publishScript: Quickshell.shellDir + "/scripts/publish-colors.py"

    property string irisPath: home + "/.local/bin/iris"
    property bool available: true
    property bool busy: false
    property var lastPalette: null
    property string lastError: ""
    property string lastWallpaper: ""

    signal paletteGenerated(var palette)
    signal generationFailed(string reason)
    signal desktopPublished()

    function generate(wallpaperPath, dark) {
        if (!irisPath) {
            root.lastError = "iris not found";
            root.generationFailed(root.lastError);
            return;
        }
        if (!wallpaperPath) return;
        const path = wallpaperPath.toString().replace("file://", "");
        root.lastWallpaper = path;
        root.busy = true;
        root.lastError = "";
        // Write files so Kitty/Hyprland/GTK can consume the same palette.
        runner.command = [irisPath, path, "--dark", dark ? "1" : "0"];
        runner.running = true;
    }

    function publish(themeName) {
        const args = ["python3", publishScript];
        if (cacheLoader.path)
            args.push(root.cacheJson);
        if (themeName)
            args.push(themeName);
        publisher.command = args;
        publisher.running = true;
    }

    // For a plain preset switch (no Iris wallpaper-color extraction
    // involved): publish that preset's own pre-generated
    // colors/themes/<name>/colors.json snapshot directly, rather than
    // whatever the Iris cache last happened to contain (which is what
    // publish() above would otherwise republish — the stale colors
    // from a previous wallpaper, not this theme's real ones).
    function publishPreset(themeName, snapshotPath) {
        presetPublisher.command = ["python3", publishScript, snapshotPath, themeName];
        presetPublisher.running = true;
    }

    function _ingestIrisJson(text) {
        try {
            const palette = JSON.parse(text);
            root.lastPalette = palette;
            root.paletteGenerated(palette);
            return true;
        } catch (e) {
            root.lastError = "could not parse iris colors.json: " + e;
            root.generationFailed(root.lastError);
            return false;
        }
    }

    Process {
        id: runner
        property string _stderrText: ""
        stderr: StdioCollector { onStreamFinished: { runner._stderrText = text; } }
        onExited: (code) => {
            root.busy = false;
            if (code !== 0) {
                root.lastError = runner._stderrText.trim() || ("iris exited " + code);
                root.generationFailed(root.lastError);
                return;
            }
            cacheLoader.reload();
        }
    }

    Process {
        id: publisher
        stdout: StdioCollector {}
        stderr: StdioCollector { id: pubErr }
        onExited: (code) => {
            if (code === 0) root.desktopPublished();
            else console.warn("Iris: publish-colors failed", pubErr.text);
        }
    }

    Process {
        id: presetPublisher
        stdout: StdioCollector {}
        stderr: StdioCollector { id: presetPubErr }
        onExited: (code) => {
            if (code === 0) root.desktopPublished();
            else console.warn("Iris: publish-colors (preset) failed", presetPubErr.text);
        }
    }

    FileView {
        id: cacheLoader
        path: root.cacheJson
        watchChanges: true
        printErrors: false
        onLoaded: root._ingestIrisJson(text())
        onFileChanged: cacheLoader.reload()
    }

    Process {
        id: probe
        command: ["bash", "-c", "if [ -x \"$HOME/.local/bin/iris\" ]; then echo \"$HOME/.local/bin/iris\"; elif command -v iris >/dev/null; then command -v iris; else echo no; fi"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const p = line.trim();
                if (p === "no" || p === "") {
                    root.available = false;
                    root.irisPath = "";
                } else {
                    root.irisPath = p;
                    root.available = true;
                }
            }
        }
    }
    Component.onCompleted: probe.running = true
}
