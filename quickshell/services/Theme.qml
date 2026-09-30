pragma Singleton



import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string colorsRoot: home + "/.config/colors"
    readonly property string scriptPath: Quickshell.shellDir + "/scripts/list-themes.py"
    readonly property string statePath: Quickshell.statePath("theme-state.json")

    property var presets: ({})
    property string currentName: ""
    property var wallpaperIndex: ({})

    readonly property var current: presets[currentName] ? presets[currentName] : null
    
    
    readonly property var targetColors: (current && current.colors) ? current.colors : fallbackColors
    property var fromColors: fallbackColors
    property var displayedColors: targetColors
    property real colorProgress: 1
    readonly property var colors: displayedColors

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    readonly property color panelFill: "#000000"
    readonly property color surfaceRaised: Qt.alpha(colors.foreground, 0.105)

    
    readonly property bool darkMode: isDarkPreset()
    
    readonly property string displayName: current ? current.name : currentName

    
    readonly property var themeWallpapers: (current && current.wallpapers) ? current.wallpapers : []
    readonly property int currentWallpaperIndex: Math.min((wallpaperIndex[currentName] !== undefined ? wallpaperIndex[currentName] : 0), Math.max(0, themeWallpapers.length - 1))
    function fileUrl(path) {
        if (!path) return "";
        const s = path.toString();
        if (s.startsWith("file://")) return s;
        if (s.startsWith("/")) return "file://" + s;
        return "file://" + root.colorsRoot + "/" + s;
    }

    readonly property string currentWallpaper: themeWallpapers.length > 0
        ? fileUrl(themeWallpapers[currentWallpaperIndex])
        : ""
    
    property string wallpaperFrom: ""
    property string wallpaperTo: currentWallpaper
    property real wallpaperProgress: 1  
    property bool wallpaperTransitioning: wallpaperProgress < 1

    readonly property var pickerModel: {
        let out = [];
        for (let key in presets) {
            const t = presets[key];
            const accent = (t.colors && t.colors.accent) ? t.colors.accent : fallbackColors.accent;
            const bg = (t.colors && t.colors.background) ? t.colors.background : fallbackColors.background;
            out.push({
                key: key,
                name: t.name ? t.name : key,
                accent: accent,
                cardColor: bg,
                selected: key === currentName,
                
                
                
                
                
                
                
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
                source: root.fileUrl(path),
                fileName: String(path).split("/").pop(),
                selected: index === selectedIndex
            });
        }
        root.wallpaperPickerModel = out;
    }

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
        const path = source.replace("file://", "");
        root.applyWallpaper(path);
    }

    function applyWallpaper(path) {
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

    function lerpHex(a, b, t) {
        let hasAlpha = a.length === 9 || b.length === 9;
        let ah = a, bh = b;
        let aAlpha = 1, bAlpha = 1;
        if (ah.length === 9) { aAlpha = parseInt(ah.slice(1,3),16)/255; ah = "#" + ah.slice(3); }
        if (bh.length === 9) { bAlpha = parseInt(bh.slice(1,3),16)/255; bh = "#" + bh.slice(3); }
        const ca = hexToRgb(ah), cb = hexToRgb(bh);
        const r = Math.round(ca.r + (cb.r - ca.r) * t);
        const g = Math.round(ca.g + (cb.g - ca.g) * t);
        const b_ = Math.round(ca.b + (cb.b - ca.b) * t);
        const hex = toHex(r,g,b_);
        if (hasAlpha) {
            const alpha = Math.round((aAlpha + (bAlpha - aAlpha)*t)*255);
            return "#" + alpha.toString(16).padStart(2,"0") + hex.slice(1);
        }
        return hex;
    }
    function interpolateColors(from, to, t) {
        if (!from || !to) return to ? to : (from ? from : fallbackColors);
        let out = {};
        const keys = new Set([...Object.keys(from), ...Object.keys(to)]);
        for (const k of keys) {
            const fv = from[k], tv = to[k];
            if (typeof fv === "string" && typeof tv === "string" && fv.startsWith("#") && tv.startsWith("#")) {
                out[k] = lerpHex(fv, tv, t);
            } else out[k] = t < 0.5 ? fv : tv;
        }
        return out;
    }
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
            wallpaperFrom = "";
        } else {
            wallpaperFrom = wallpaperTo;
        }
        wallpaperTo = newWall;
        wallpaperProgress = 0;
        wallpaperAnim.restart();
    }

    
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

    function isDarkPreset() {
        
        let bg = "#202020";
        if (targetColors && targetColors.background) bg = targetColors.background;
        return hexLightness(bg) < 0.5;
    }
    function hexToRgb(hex) {
        let h = hex.replace("#", "");
        if (h.length === 3) h = h.split("").map(ch => ch + ch).join("");
        const num = parseInt(h, 16);
        return { r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255 };
    }
    function hexLightness(hex) {
        const c = hexToRgb(hex);
        const r = c.r / 255, g = c.g / 255, b = c.b / 255;
        return (Math.max(r, g, b) + Math.min(r, g, b)) / 2;
    }
    function toHex(r, g, b) {
        const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
        const pad = (v) => clamp(v).toString(16).padStart(2, "0");
        return "#" + pad(r) + pad(g) + pad(b);
    }
    
    
    
    function withAlpha(c, alpha01) {
        let h = String(c).replace("#", "");
        if (h.length === 8) h = h.slice(2);
        const a = Math.max(0, Math.min(255, Math.round(alpha01 * 255)));
        return "#" + a.toString(16).padStart(2, "0") + h;
    }

    
    
    
    
    
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

    
    
    
    
    
    
    
    property bool presetsResolved: false
    property bool stateResolved: false
    property bool wallpaperApplied: false
    
    property string savedTheme: ""
    
    
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
