pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property int currentPage: 0
    property real sidebarWidth: 240

    // Clock & Date
    property bool time24h: true
    property bool showSeconds: false
    property bool firstDayMonday: true

    // Media
    property bool mediaShowMiniPill: true
    property bool mediaShowToast: false
    property bool mediaAutoPauseOnLock: true

    // Launcher
    property bool launcherIncludeCommands: true
    property int launcherMaxResults: 6
    // Reference: 2026-09-20_22-27-53.png, a 1:1 crop of the same session.
    // The launcher panel measures x 204..717 = 514 wide, and the selected row
    // y 90..134 = 45 tall. The old 550x52 was visibly wider and taller than
    // the reference. Neither is persisted, so the defaults take effect as-is.
    property real launcherWidth: 514
    property real launcherRowHeight: 46
    property int launcherRowsBeforeScrolling: 6

    // Notifications
    property bool notifSoundEnabled: true
    property bool notifIslandMorph: true
    property int notifPopupTimeoutMs: 2000
    property int notifUrgentTimeoutMs: 6000
    // 449 is the reference toast's width measured 1:1 on
    // 2026-09-20_22-28-28.png: the card's outer edge falls at x 258.98 and
    // 708.17 (half-way between the wallpaper and the black fill on each
    // side), i.e. 449.19px. The references are 1:1 crops of a native
    // 1920x1080 session -- confirmed by the control-centre panel measuring
    // the same 514px in the Display crop as in the native home capture -- so
    // this is a live pixel count, not a capture pixel count to be scaled.
    property real notifWidth: 449
    property bool notifShowBodyText: true
    property real notifHistoryHeight: 200

    // Volume/Brightness OSD
    property int osdOnScreenTimeMs: 1500
    // 5, measured off 2026-09-20_22-28-44.png: the reference's track column
    // reads y 37..41 at x 360. Was 6.
    property real osdLevelBarThickness: 5

    // Lockscreen
    property int lockscreenTimeoutMins: 10
    property bool lockscreenShowMedia: true

    // Appearance
    property real glassOpacity: 0.95
    property int cornerRadiusPreset: 20
    property string wallpaperTransitionStyle: "circleOut"  // "circleOut" | "fade" | "slide" | "slideVertical" | "instant"
    property int wallpaperTransitionDuration: 600          // ms

    readonly property string statePath: Quickshell.statePath("settings-config.json")
    property bool _loaded: false

    FileView {
        id: loader; path: root.statePath; watchChanges: false; printErrors: false
        onLoaded: { root._applyState(text()); root._loaded = true }
        onLoadFailed: root._loaded = true
    }
    FileView { id: writer; path: root.statePath; printErrors: false }

    function _applyState(jsonText: string) {
        try {
            const d = JSON.parse(jsonText);
            if (typeof d.currentPage === "number") root.currentPage = d.currentPage;
            if (typeof d.sidebarWidth === "number") root.sidebarWidth = d.sidebarWidth;
            if (typeof d.time24h === "boolean") root.time24h = d.time24h;
            if (typeof d.showSeconds === "boolean") root.showSeconds = d.showSeconds;
            if (typeof d.firstDayMonday === "boolean") root.firstDayMonday = d.firstDayMonday;
            if (typeof d.mediaShowMiniPill === "boolean") root.mediaShowMiniPill = d.mediaShowMiniPill;
            if (typeof d.mediaShowToast === "boolean") root.mediaShowToast = d.mediaShowToast;
            if (typeof d.mediaAutoPauseOnLock === "boolean") root.mediaAutoPauseOnLock = d.mediaAutoPauseOnLock;
            if (typeof d.launcherIncludeCommands === "boolean") root.launcherIncludeCommands = d.launcherIncludeCommands;
            if (typeof d.launcherMaxResults === "number") root.launcherMaxResults = d.launcherMaxResults;
            if (typeof d.launcherWidth === "number") root.launcherWidth = d.launcherWidth;
            if (typeof d.launcherRowHeight === "number") root.launcherRowHeight = d.launcherRowHeight;
            if (typeof d.launcherRowsBeforeScrolling === "number") root.launcherRowsBeforeScrolling = d.launcherRowsBeforeScrolling;
            if (typeof d.notifSoundEnabled === "boolean") root.notifSoundEnabled = d.notifSoundEnabled;
            if (typeof d.notifPopupTimeoutMs === "number") root.notifPopupTimeoutMs = d.notifPopupTimeoutMs;
            if (typeof d.notifUrgentTimeoutMs === "number") root.notifUrgentTimeoutMs = d.notifUrgentTimeoutMs;
            if (typeof d.notifWidth === "number") root.notifWidth = d.notifWidth;
            if (typeof d.notifShowBodyText === "boolean") root.notifShowBodyText = d.notifShowBodyText;
            if (typeof d.notifHistoryHeight === "number") root.notifHistoryHeight = d.notifHistoryHeight;
            if (typeof d.osdOnScreenTimeMs === "number") root.osdOnScreenTimeMs = d.osdOnScreenTimeMs;
            if (typeof d.osdLevelBarThickness === "number") root.osdLevelBarThickness = d.osdLevelBarThickness;
            if (typeof d.notifIslandMorph === "boolean") root.notifIslandMorph = d.notifIslandMorph;
            if (typeof d.lockscreenTimeoutMins === "number") root.lockscreenTimeoutMins = d.lockscreenTimeoutMins;
            if (typeof d.lockscreenShowMedia === "boolean") root.lockscreenShowMedia = d.lockscreenShowMedia;
            if (typeof d.glassOpacity === "number") root.glassOpacity = d.glassOpacity;
            if (typeof d.cornerRadiusPreset === "number") root.cornerRadiusPreset = d.cornerRadiusPreset;
            if (typeof d.wallpaperTransitionStyle === "string") root.wallpaperTransitionStyle = d.wallpaperTransitionStyle;
            if (typeof d.wallpaperTransitionDuration === "number") root.wallpaperTransitionDuration = d.wallpaperTransitionDuration;
        } catch(e){}
    }

    function _persist() {
        if (!root._loaded) return
        writer.setText(JSON.stringify({
            currentPage: root.currentPage,
            sidebarWidth: root.sidebarWidth,
            time24h: root.time24h,
            showSeconds: root.showSeconds,
            firstDayMonday: root.firstDayMonday,
            mediaShowMiniPill: root.mediaShowMiniPill,
            mediaShowToast: root.mediaShowToast,
            mediaAutoPauseOnLock: root.mediaAutoPauseOnLock,
            launcherIncludeCommands: root.launcherIncludeCommands,
            launcherMaxResults: root.launcherMaxResults,
            launcherWidth: root.launcherWidth,
            launcherRowHeight: root.launcherRowHeight,
            launcherRowsBeforeScrolling: root.launcherRowsBeforeScrolling,
            notifSoundEnabled: root.notifSoundEnabled,
            notifPopupTimeoutMs: root.notifPopupTimeoutMs,
            notifUrgentTimeoutMs: root.notifUrgentTimeoutMs,
            notifWidth: root.notifWidth,
            notifShowBodyText: root.notifShowBodyText,
            notifHistoryHeight: root.notifHistoryHeight,
            osdOnScreenTimeMs: root.osdOnScreenTimeMs,
            osdLevelBarThickness: root.osdLevelBarThickness,
            notifIslandMorph: root.notifIslandMorph,
            lockscreenTimeoutMins: root.lockscreenTimeoutMins,
            lockscreenShowMedia: root.lockscreenShowMedia,
            glassOpacity: root.glassOpacity,
            cornerRadiusPreset: root.cornerRadiusPreset,
            wallpaperTransitionStyle: root.wallpaperTransitionStyle,
            wallpaperTransitionDuration: root.wallpaperTransitionDuration
        }))
    }

    function setCurrentPage(v: int){ if(v===root.currentPage) return; root.currentPage=v; _persist() }
    function setSidebarWidth(v: real){ if(v===root.sidebarWidth) return; root.sidebarWidth=v; _persist() }
    function setTime24h(v: bool){ root.time24h=v; _persist() }
    function setShowSeconds(v: bool){ root.showSeconds=v; _persist() }
    function setFirstDayMonday(v: bool){ root.firstDayMonday=v; _persist() }
    function setMediaShowMiniPill(v: bool){ root.mediaShowMiniPill=v; _persist() }
    function setMediaShowToast(v: bool){ root.mediaShowToast=v; _persist() }
    function setMediaAutoPauseOnLock(v: bool){ root.mediaAutoPauseOnLock=v; _persist() }
    function setLauncherIncludeCommands(v: bool){ root.launcherIncludeCommands=v; _persist() }
    function setLauncherMaxResults(v: int){ root.launcherMaxResults=v; _persist() }
    function setLauncherWidth(v: real){ root.launcherWidth=v; _persist() }
    function setLauncherRowHeight(v: real){ root.launcherRowHeight=v; _persist() }
    function setLauncherRowsBeforeScrolling(v: int){ root.launcherRowsBeforeScrolling=v; _persist() }
    function setNotifSoundEnabled(v: bool){ root.notifSoundEnabled=v; _persist() }
    function setNotifPopupTimeoutMs(v: int){ root.notifPopupTimeoutMs=v; _persist() }
    function setNotifUrgentTimeoutMs(v: int){ root.notifUrgentTimeoutMs=v; _persist() }
    function setNotifWidth(v: real){ root.notifWidth=v; _persist() }
    function setNotifShowBodyText(v: bool){ root.notifShowBodyText=v; _persist() }
    function setNotifHistoryHeight(v: real){ root.notifHistoryHeight=v; _persist() }
    function setOsdOnScreenTimeMs(v: int){ root.osdOnScreenTimeMs=v; _persist() }
    function setOsdLevelBarThickness(v: real){ root.osdLevelBarThickness=v; _persist() }
    function setNotifIslandMorph(v: bool){ root.notifIslandMorph=v; _persist() }
    function setLockscreenTimeoutMins(v: int){ root.lockscreenTimeoutMins=v; _persist() }
    function setLockscreenShowMedia(v: bool){ root.lockscreenShowMedia=v; _persist() }
    function setGlassOpacity(v: real){ root.glassOpacity=v; _persist() }
    function setCornerRadiusPreset(v: int){ root.cornerRadiusPreset=v; _persist() }
    function setWallpaperTransitionStyle(v: string){ root.wallpaperTransitionStyle=v; _persist() }
    function setWallpaperTransitionDuration(v: int){ root.wallpaperTransitionDuration=v; _persist() }
}
