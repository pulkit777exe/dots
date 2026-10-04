pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The theme layer: discover the palettes in colors/, hold the one in use,
// blend between two of them, publish the result, apply the wallpaper.
//
// Three collaborators, split because none is "being the theme": ColorMath
// (hex arithmetic), ThemeRows (the pickers' row lists) and ColorWatch (the
// colors/ watchers and the 400ms debounce). Each is handed what it needs
// rather than reaching back for it: a helper that read Theme.fallbackColors
// would have to import the module Theme is declared in, and QML answers that
// with a load-time failure, not a warning. What stays is Theme's own -- the
// degraded-mode palette, the state that picks one, and the three processes
// that discover, publish and apply.

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string colorsRoot: home + "/.config/colors"
    readonly property string scriptPath: Quickshell.shellDir + "/scripts/list-themes.py"
    readonly property string statePath: Quickshell.statePath("theme-state.json")

    ColorMath { id: colorMath }
    ThemeRows { id: rows }
    WallpaperSetter { id: wallpaperApply }
    // The debounce is ColorWatch's; what a reload MEANS -- re-run
    // list-themes.py -- is this file's.
    ColorWatch {
        id: colorWatch
        colorsRoot: root.colorsRoot
        onReloadRequested: discovery.running = true
    }

    property var presets: ({})
    property string currentName: ""
    property var wallpaperIndex: ({})

    readonly property var current: presets[currentName] ? presets[currentName] : null

    readonly property var targetColors: (current && current.colors) ? current.colors : fallbackColors
    property var fromColors: fallbackColors
    property var displayedColors: targetColors
    property real colorProgress: 1
    readonly property var colors: displayedColors

    // The two colours no palette has a say in. panelFill is the base every
    // translucent surface is read against -- Surface.qml's background, and
    // what the scrims and drop shadows take an alpha of -- so it stays a
    // literal: a palette that could set it decides how opaque the shell's
    // own panels are.
    readonly property color panelFill: "#000000"
    readonly property color surfaceRaised: Qt.alpha(colors.foreground, 0.105)

    readonly property bool darkMode: isDarkPreset()

    readonly property string displayName: current ? current.name : currentName

    readonly property var themeWallpapers: (current && current.wallpapers) ? current.wallpapers : []
    readonly property int currentWallpaperIndex: Math.min((wallpaperIndex[currentName] !== undefined ? wallpaperIndex[currentName] : 0), Math.max(0, themeWallpapers.length - 1))

    // Two callers: the wallpaper binding below and one row per wallpaper in
    // the picker. Theme is the only thing that knows where colors/ lives.
    function fileUrl(path) {
        return rows.fileUrl(path, root.colorsRoot);
    }

    readonly property string currentWallpaper: themeWallpapers.length > 0
        ? fileUrl(themeWallpapers[currentWallpaperIndex])
        : ""

    property string wallpaperFrom: ""
    property string wallpaperTo: currentWallpaper
    property real wallpaperProgress: 1
    property bool wallpaperTransitioning: wallpaperProgress < 1

    readonly property var pickerModel:
        rows.themeRows(root.presets, root.currentName, root.fallbackColors)

    property var wallpaperPickerModel: []

    // Assigned rather than bound: every caller changes one of this
    // function's inputs and wants the new rows to exist before it goes on.
    function rebuildPickerModel() {
        wallpaperPickerModel =
            rows.wallpaperRows(root.presets, root.currentName, root.wallpaperIndex, root.colorsRoot);
    }

    // The degraded-mode palette: what the shell draws with before
    // list-themes.py has answered, and what themeRows() falls back to for a
    // theme missing a key. The literals belong here -- this is the theme
    // layer, and the only QML in the tree carrying a palette of its own.
    readonly property var fallbackColors: ({
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
        wallpaperApply.apply(source.replace("file://", ""));
    }

    // ---- colour transition ----------------------------------------------
    //
    // A theme change is a cross-fade of the whole palette, not a cut, and an
    // explicit restart() rather than a Behavior so two changes in quick
    // succession continue from where the first had got to.
    NumberAnimation {
        id: colorAnim
        target: root
        property: "colorProgress"
        from: 0; to: 1
        duration: MotionConfig.fade()
        easing.type: Easing.OutCubic
        onFinished: { root.displayedColors = root.targetColors; }
    }
    onColorProgressChanged: {
        if (colorProgress >= 1) displayedColors = targetColors;
        else displayedColors = interpolateColors(fromColors, targetColors, colorProgress);
    }
    onTargetColorsChanged: startColorTransition()

    // The first palette to arrive must NOT animate: a fade here is a fade
    // from the fallback palette on a shell that has not finished starting.
    function startColorTransition() {
        if (wallpaperApplied) {
            fromColors = displayedColors;
            colorProgress = 0;
            colorAnim.restart();
        } else {
            displayedColors = targetColors;
            colorProgress = 1;
        }
    }

    function startWallpaperTransition(newWall) {
        if (!wallpaperApplied || !newWall || wallpaperProgress < 1) {
            // No previous wallpaper to fade from: empty the `from` side.
            wallpaperFrom = "";
        } else {
            wallpaperFrom = wallpaperTo;
        }
        wallpaperTo = newWall;
        wallpaperProgress = 0;
        wallpaperAnim.restart();
    }

    // ---- wallpaper transition -------------------------------------------
    //
    // The animation only moves wallpaperProgress; a surface cross-fades
    // between wallpaperFrom and wallpaperTo, so nothing waits for the image.
    NumberAnimation {
        id: wallpaperAnim
        target: root
        property: "wallpaperProgress"
        from: 0; to: 1
        duration: ConfigStore.wallpaperTransitionDuration > 0 ? ConfigStore.wallpaperTransitionDuration : MotionConfig.fade(1.6)
        easing.type: Easing.InOutCubic
    }
    onCurrentWallpaperChanged: {
        if (currentWallpaper && wallpaperApplied) startWallpaperTransition(currentWallpaper);
        else {
            wallpaperTo = currentWallpaper;
            wallpaperFrom = "";
            wallpaperProgress = 1;
        }
    }

    // ---- the three colour helpers, delegated ---------------------------
    //
    // Implemented in ColorMath.qml; these stay the public names, because
    // withAlpha() is called 134 times as `Theme.withAlpha(...)`.
    function isDarkPreset() {
        return colorMath.isDark(targetColors, fallbackColors.background);
    }

    function interpolateColors(from, to, t) {
        return colorMath.interpolate(from, to, t, fallbackColors);
    }

    function withAlpha(c, alpha01) {
        return colorMath.withAlpha(c, alpha01);
    }

    // ---- publishing ------------------------------------------------------
    //
    // publish-colors.py writes the generated colors/kitty.conf,
    // colors/colors.css and the rest, which is how the DE and the terminals
    // pick up a theme change. A Process rather than an inline write because
    // the script is the one place that knows the file list. Those generated
    // files are gitignored; the palettes they come from are not, and nothing
    // here writes those.
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

        savedTheme = name;
        rebuildPickerModel();
        saveState();

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
        if (index < 0 || index >= themeWallpapers.length) return;

        // A fresh object: wallpaperIndex is a `var`, and its change handler
        // only fires for a reassignment.
        let updated = Object.assign({}, wallpaperIndex);
        updated[currentName] = index;
        wallpaperIndex = updated;

        rebuildPickerModel();
        saveState();
        wallpaperChanged(currentWallpaper);
    }
    function cycleWallpaper() {
        if (themeWallpapers.length === 0) return;
        setWallpaper((currentWallpaperIndex + 1) % themeWallpapers.length);
    }

    // ---- discovery -------------------------------------------------------
    //
    // Read by a script, not a FileView + JsonAdapter, because the discovery
    // is not a parse: it walks wallpaper directories, falls back through
    // candidate paths per theme, and merges a palette with defaults. That
    // logic lives in list-themes.py; a second copy here would be a second
    // answer to the same question.
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

    Component.onCompleted: {
        rebuildPickerModel();
        discovery.running = true;
    }

    // ---- saved state ------------------------------------------------------
    //
    // Two gates, not a load order: presets and state arrive independently --
    // the state file may not exist on a first run -- and resolveTheme() is the
    // only thing that may pick the active theme until both are in.
    property bool presetsResolved: false
    property bool stateResolved: false
    property bool wallpaperApplied: false

    property string savedTheme: ""

    // What index.json declares: the lowest of three priorities, below a saved
    // theme and above the first discovered theme.
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
        printErrors: false
    }

    // The picker's rows are a function of the theme NAME, so the model follows
    // the name rather than each caller remembering to rebuild. Without this the
    // picker was empty on every fresh load: `resolveTheme()` assigns
    // `currentName`, but every explicit `rebuildPickerModel()` call site fires
    // while `currentName` is still "", so `wallpaperRows()` looked up
    // `presets[""]` and returned []. It only filled in if a later `setTheme` or
    // `setWallpaper` happened to run.
    onCurrentNameChanged: rebuildPickerModel()

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
        else if (themeWallpapers.length === 0) console.warn("Theme: no wallpapers discovered for", currentName);

        publish(currentName);
    }

    function applyPresets(data) {
        try {
            root.presets = (data && data.themes) ? data.themes : {};
            root.declaredTheme = (data && data.current) || (data && data.default) || "";
            // Re-pointed here: this caller has just read colors/.
            colorWatch.sync(root.presets);
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

        function get(): string { return root.currentName; }
        function set(name: string): void { setTheme(name); }
        function cycle(): void { cycleTheme(); }
        function list(): string { return Object.keys(root.presets).join("\n"); }
        function getWallpaper(): string { return root.currentWallpaper; }
        function cycleWallpaper(): void { root.cycleWallpaper(); }
        function publish(theme: string): void { root.publish(theme); }
    }
}
