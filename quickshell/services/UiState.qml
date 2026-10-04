pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    
    enum Mode {
        Closed,
        ControlCenter,
        Launcher,
        Settings,
        Clipboard,
        ThemePicker,
        WallpaperPicker,
        Calendar,
        PowerMenu,
        Media
    }

    property int mode: UiState.Mode.Closed

    
    // Ten of the thirteen `property bool` declarations below are READONLY
    // projections of `mode`, which is one int already carrying an enum. The
    // state space is therefore the eleven enum members, not 2^10, and no two
    // of these can be true at once -- which is exactly what the ten WRITABLE
    // booleans they replaced could not say.
    //
    // The three writable ones are orthogonal and shadow nothing.
    // `calendarMonth` is reset by close() and toggle() and can only be set
    // while mode is Calendar. `osdVisible` is transient, written by showOsd()
    // and its own hide Timer. `osdMuted` is a snapshot of Volume.muted taken
    // when the OSD fired -- NOT `osdLevel === 0`: PipeWire lets a sink be
    // muted at 50%, and OSD.qml passes false for the brightness OSD, so
    // deriving it from the level would be wrong.
    //
    // Measured and left alone on purpose: these projections are also the
    // public names behind the uis:isXOpen IPC functions and behind the
    // nine-surfaces test, so renaming them to reach the number would be
    // cosmetic and would break both.
    readonly property bool anyOpen: mode !== UiState.Mode.Closed
    readonly property bool launcherOpen: mode === UiState.Mode.Launcher
    readonly property bool controlCenterOpen: mode === UiState.Mode.ControlCenter
    readonly property bool powerMenuOpen: mode === UiState.Mode.PowerMenu
    readonly property bool settingsOpen: mode === UiState.Mode.Settings
    readonly property bool clipboardOpen: mode === UiState.Mode.Clipboard
    readonly property bool themePickerOpen: mode === UiState.Mode.ThemePicker
    readonly property bool wallpaperPickerOpen: mode === UiState.Mode.WallpaperPicker
    readonly property bool calendarOpen: mode === UiState.Mode.Calendar
    readonly property bool mediaOpen: mode === UiState.Mode.Media
    
    
    
    

    
    
    
    
    
    
    property string ccView: "home"

    
    
    
    
    
    
    
    
    property bool calendarMonth: false

    
    
    
    
    
    
    property bool osdVisible: false
    property string osdKind: "volume"   
    property int osdLevel: 0
    property bool osdMuted: false

    function showOsd(kind, level, muted) {
        osdKind = kind;
        osdLevel = level;
        osdMuted = muted === true;
        osdVisible = true;
        osdHideTimer.restart();
    }

    Timer {
        id: osdHideTimer
        interval: ConfigStore.osdOnScreenTimeMs
        onTriggered: root.osdVisible = false
    }


    
    function close() {
        mode = UiState.Mode.Closed;
        calendarMonth = false;
    }

    function toggle(newMode) {
        mode = (mode === newMode) ? UiState.Mode.Closed : newMode;
        
        
        calendarMonth = false;
    }

    
    function showCalendarMonth() {
        if (mode === UiState.Mode.Calendar) calendarMonth = true;
    }

    
    
    function showCalendarWeek() { calendarMonth = false; }

    
    function toggleLauncher() { toggle(UiState.Mode.Launcher); }
    function toggleControlCenter() { toggle(UiState.Mode.ControlCenter); }
    function togglePowerMenu() { toggle(UiState.Mode.PowerMenu); }
    function toggleSettings() { toggle(UiState.Mode.Settings); }
    function toggleClipboard() { toggle(UiState.Mode.Clipboard); }
    function toggleThemePicker() { toggle(UiState.Mode.ThemePicker); }
    function toggleWallpaperPicker() { toggle(UiState.Mode.WallpaperPicker); }
    function toggleCalendar() { toggle(UiState.Mode.Calendar); }
    function toggleMedia() { toggle(UiState.Mode.Media); }

    function closeAll() { close(); }
}
