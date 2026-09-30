pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property int currentPage: data.currentPage


    // Clock & Date
    readonly property bool time24h: data.time24h
    readonly property bool showSeconds: data.showSeconds
    readonly property bool firstDayMonday: data.firstDayMonday

    // Media
    readonly property bool mediaShowMiniPill: data.mediaShowMiniPill
    readonly property bool mediaShowToast: data.mediaShowToast
    readonly property bool mediaAutoPauseOnLock: data.mediaAutoPauseOnLock

    // Launcher

    readonly property int launcherMaxResults: data.launcherMaxResults
    // Reference: 2026-09-20_22-27-53.png, a 1:1 crop of the same session.
    // The launcher panel measures x 204..717 = 514 wide, and the selected row
    // y 90..134 = 45 tall. The old 550x52 was visibly wider and taller than
    // the reference. Neither is persisted, so the defaults take effect as-is.
    readonly property real launcherWidth: data.launcherWidth
    readonly property real launcherRowHeight: data.launcherRowHeight
    readonly property int launcherRowsBeforeScrolling: data.launcherRowsBeforeScrolling

    // Notifications
    readonly property bool notifSoundEnabled: data.notifSoundEnabled

    readonly property int notifPopupTimeoutMs: data.notifPopupTimeoutMs
    readonly property int notifUrgentTimeoutMs: data.notifUrgentTimeoutMs
    // 449 is the reference toast's width measured 1:1 on
    // 2026-09-20_22-28-28.png: the card's outer edge falls at x 258.98 and
    // 708.17 (half-way between the wallpaper and the black fill on each
    // side), i.e. 449.19px. The references are 1:1 crops of a native
    // 1920x1080 session -- confirmed by the control-centre panel measuring
    // the same 514px in the Display crop as in the native home capture -- so
    // this is a live pixel count, not a capture pixel count to be scaled.
    readonly property real notifWidth: data.notifWidth
    readonly property bool notifShowBodyText: data.notifShowBodyText
    readonly property real notifHistoryHeight: data.notifHistoryHeight

    // Volume/Brightness OSD
    readonly property int osdOnScreenTimeMs: data.osdOnScreenTimeMs
    // 5, measured off 2026-09-20_22-28-44.png: the reference's track column
    // reads y 37..41 at x 360. Was 6.
    readonly property real osdLevelBarThickness: data.osdLevelBarThickness

    // Lockscreen
    readonly property int lockscreenTimeoutMins: data.lockscreenTimeoutMins
    readonly property bool lockscreenShowMedia: data.lockscreenShowMedia

    // Appearance
    readonly property real glassOpacity: data.glassOpacity
    readonly property int cornerRadiusPreset: data.cornerRadiusPreset
    readonly property string wallpaperTransitionStyle: data.wallpaperTransitionStyle   //"circleOut" | "fade" | "slide" | "slideVertical" | "instant"
    readonly property int wallpaperTransitionDuration: data.wallpaperTransitionDuration   //ms

    // ---- Storage -------------------------------------------------------
    // True once the file has been read, or once we know there isn't one.
    property bool resolved: false

    // Writes the adapter out. Guarded on `resolved` because the file loads
    // asynchronously: a setter called during startup would otherwise
    // serialise the defaults straight over the saved config.
    function save() {
        if (!root.resolved) return;
        state.writeAdapter();
    }

    // One FileView with an adapter on it. The adapter maps each of its
    // properties to a key in the file and does the parsing and the type
    // checking itself, so there is no hand-written parse and no
    // `typeof d.x === "number"` guard per field: a missing key leaves the
    // declared default in place, and one of the wrong type is dropped
    // rather than throwing on a corrupt file.
    //
    // Written with an explicit writeAdapter() from save() rather than
    // onAdapterUpdated, because loading the file also updates the adapter's
    // properties, and that would rewrite the file on every start.
    FileView {
        id: state
        path: Quickshell.statePath("settings-config.json")
        // Read once at startup. Watching would fight our own writes.
        watchChanges: false
        printErrors: false
        onLoaded: root.resolved = true
        // No saved config yet is the normal first-run case, not an error.
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property int cornerRadiusPreset: 20
            property int currentPage: 0
            property bool firstDayMonday: true
            property real glassOpacity: 0.95
            property int launcherMaxResults: 6
            property real launcherRowHeight: 46
            property int launcherRowsBeforeScrolling: 6
            property real launcherWidth: 514
            property bool lockscreenShowMedia: true
            property int lockscreenTimeoutMins: 10
            property bool mediaAutoPauseOnLock: true
            property bool mediaShowMiniPill: true
            property bool mediaShowToast: false
            property real notifHistoryHeight: 200
            property int notifPopupTimeoutMs: 2000
            property bool notifShowBodyText: true
            property bool notifSoundEnabled: true
            property int notifUrgentTimeoutMs: 6000
            property real notifWidth: 449
            property real osdLevelBarThickness: 5
            property int osdOnScreenTimeMs: 1500
            property bool showSeconds: false
            property bool time24h: true
            property int wallpaperTransitionDuration: 600
            property string wallpaperTransitionStyle: "circleOut"
        }
    }


    function setCurrentPage(v: int){ if(v===root.currentPage) return; data.currentPage=v; save(); }
    function setTime24h(v: bool){ data.time24h=v; save(); }
    function setShowSeconds(v: bool){ data.showSeconds=v; save(); }
    function setFirstDayMonday(v: bool){ data.firstDayMonday=v; save(); }
    function setMediaShowMiniPill(v: bool){ data.mediaShowMiniPill=v; save(); }
    function setMediaShowToast(v: bool){ data.mediaShowToast=v; save(); }
    function setMediaAutoPauseOnLock(v: bool){ data.mediaAutoPauseOnLock=v; save(); }
    function setLauncherWidth(v: real){ data.launcherWidth=v; save(); }
    function setLauncherRowHeight(v: real){ data.launcherRowHeight=v; save(); }
    function setLauncherRowsBeforeScrolling(v: int){ data.launcherRowsBeforeScrolling=v; save(); }
    function setNotifPopupTimeoutMs(v: int){ data.notifPopupTimeoutMs=v; save(); }
    function setNotifUrgentTimeoutMs(v: int){ data.notifUrgentTimeoutMs=v; save(); }
    function setNotifWidth(v: real){ data.notifWidth=v; save(); }
    function setNotifShowBodyText(v: bool){ data.notifShowBodyText=v; save(); }
    function setNotifHistoryHeight(v: real){ data.notifHistoryHeight=v; save(); }
    function setOsdOnScreenTimeMs(v: int){ data.osdOnScreenTimeMs=v; save(); }
    function setOsdLevelBarThickness(v: real){ data.osdLevelBarThickness=v; save(); }
    function setLockscreenTimeoutMins(v: int){ data.lockscreenTimeoutMins=v; save(); }
    function setLockscreenShowMedia(v: bool){ data.lockscreenShowMedia=v; save(); }
    function setGlassOpacity(v: real){ data.glassOpacity=v; save(); }
    function setCornerRadiusPreset(v: int){ data.cornerRadiusPreset=v; save(); }
    function setWallpaperTransitionStyle(v: string){ data.wallpaperTransitionStyle=v; save(); }
    function setWallpaperTransitionDuration(v: int){ data.wallpaperTransitionDuration=v; save(); }
}
