pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property int currentPage: data.currentPage


    
    readonly property bool time24h: data.time24h
    readonly property bool showSeconds: data.showSeconds
    readonly property bool firstDayMonday: data.firstDayMonday

    
    readonly property bool mediaShowMiniPill: data.mediaShowMiniPill
    readonly property bool mediaShowToast: data.mediaShowToast
    readonly property bool mediaAutoPauseOnLock: data.mediaAutoPauseOnLock

    

    readonly property int launcherMaxResults: data.launcherMaxResults
    
    
    
    
    readonly property real launcherWidth: data.launcherWidth
    readonly property real launcherRowHeight: data.launcherRowHeight
    readonly property int launcherRowsBeforeScrolling: data.launcherRowsBeforeScrolling

    
    readonly property bool notifSoundEnabled: data.notifSoundEnabled

    readonly property int notifPopupTimeoutMs: data.notifPopupTimeoutMs
    readonly property int notifUrgentTimeoutMs: data.notifUrgentTimeoutMs
    
    
    
    
    
    
    
    readonly property real notifWidth: data.notifWidth
    readonly property bool notifShowBodyText: data.notifShowBodyText
    readonly property real notifHistoryHeight: data.notifHistoryHeight

    
    readonly property int osdOnScreenTimeMs: data.osdOnScreenTimeMs
    
    
    readonly property real osdLevelBarThickness: data.osdLevelBarThickness

    
    readonly property int lockscreenTimeoutMins: data.lockscreenTimeoutMins
    readonly property bool lockscreenShowMedia: data.lockscreenShowMedia

    
    readonly property real glassOpacity: data.glassOpacity
    readonly property int cornerRadiusPreset: data.cornerRadiusPreset
    readonly property string wallpaperTransitionStyle: data.wallpaperTransitionStyle   
    readonly property int wallpaperTransitionDuration: data.wallpaperTransitionDuration   

    
    
    property bool resolved: false

    
    
    
    function save() {
        if (!root.resolved) return;
        state.writeAdapter();
    }

    
    
    
    
    
    
    
    
    
    
    FileView {
        id: state
        path: Quickshell.statePath("settings-config.json")
        
        watchChanges: false
        printErrors: false
        onLoaded: root.resolved = true
        
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
