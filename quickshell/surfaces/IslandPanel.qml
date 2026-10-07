import QtQuick
import "../components"
import "../services"
import Quickshell

// The island: one surface, and a mapping from "which mode is open" to "how
// big is this panel" -- targetW and targetH below -- plus the twelve faces
// that mapping selects between.
//
// It used to be three regions: a centre notch with a dot on each side, each
// with its own Surface and its own x spring, and the dots hung off the
// centre's measured edges. That is gone. The rest state, the wide state and
// every surface are now the same panel at a different size, so there is one
// radius to keep in step, one shadow, one position, and one Region for the
// window mask to find. The container transform this was always reaching for
// -- see docs/DESIGN.md -- needs the two states to be ONE item for the morph
// to be a morph rather than a crossfade between neighbours.
//
// The faces are all children of one Surface, all anchored to fill it, and
// at most one is visible at a time (UiState.mode is a single enum, plus the
// home face and the OSD). They are NOT in a StackView or behind a Loader:
// they are declared together and switched by `visible`, because every one of
// them has to report its size the moment it becomes visible, and a Loader
// would report nothing until it had loaded.
Item {
    id: root

    // Resolved per-monitor bar geometry -- see IslandMetrics.qml.
    property var metrics

    // Which monitor this panel is on. Used twice: to clamp the settings
    // page's height to the screen it is actually on, and to tell the
    // workspace indicator which workspaces belong to this island.
    property string screenName: ""

    // The settings panel drops below the island row so it does not cover the
    // bar, which costs it this much of the screen's height. targetH reads the
    // same number back out of the screen height, so the two are declared
    // together rather than being a 76 written in two places.
    readonly property int settingsTopInset: 76
    readonly property int settingsBottomMargin: 8

    readonly property real screenHeight: (Quickshell.screens.find(function (s) {
        return s.name === root.screenName
    })?.height ?? 1080)

    // The clock lives here rather than on Island: it is the only thing that
    // draws it, and a Timer that exists only to feed one text belongs with
    // that text rather than with the bar's layout. The date rides the same
    // timer -- it changes on a scale of days, but a second resolution is
    // free when the timer already exists and a midnight rollover is not worth
    // a timer of its own.
    property string currentTime: Qt.formatTime(new Date(), "hh:mm")
    property string currentDate: Qt.formatDate(new Date(), "ddd, MMM d")
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = Qt.formatTime(new Date(), "hh:mm")
            root.currentDate = Qt.formatDate(new Date(), "ddd, MMM d")
        }
    }

    y: isSettings ? settingsTopInset : metrics.topOffset
    Behavior on y {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation { spring: 5.8; damping: 0.70; mass: 0.55 }
    }
    // Centred in the bar window. Island is this item's direct parent and is
    // the full-width item shell.qml anchors, so `parent` is the right thing
    // to be centred against -- there is no panel stack above this. Centring
    // is also what makes the morph work: width springs, x follows, so the
    // island grows out of its own middle in both directions.
    anchors.horizontalCenter: parent.horizontalCenter

    readonly property bool isCalendar: UiState.calendarOpen
    readonly property bool isSettings: UiState.settingsOpen
    readonly property bool isLauncher: UiState.launcherOpen
    readonly property bool isClipboard: UiState.clipboardOpen
    readonly property bool isPowerMenu: UiState.powerMenuOpen
    readonly property bool isThemePicker: UiState.themePickerOpen
    readonly property bool isWallpaperPicker: UiState.wallpaperPickerOpen
    readonly property bool isMedia: UiState.mediaOpen
    readonly property bool isControlCenter: UiState.controlCenterOpen
    readonly property bool isOsd: UiState.osdVisible

    // The home face is what is showing when no mode is. It has two layouts of
    // its own -- the pill and the wide panel -- which is why the OSD and the
    // surfaces are keyed off the enum and only the home state reads
    // homeFace.rich.
    readonly property bool isHome: !UiState.anyOpen

    // A surface is open: a rounded card with a shadow, sitting where the
    // island was. The OSD is deliberately absent -- it is a transient over
    // the top of whatever is already open -- and so is `rich`, which is home
    // rather than a surface and keeps the pill's radius.
    readonly property bool isSurfaceOpen: !isHome

    // The narrow case, where notch mode's squared-off top corners apply.
    readonly property bool homeRest: isHome && !homeFace.rich

    // Width per mode. Where a surface declares its own width, that is read
    // instead of a number being repeated here -- the +24 is the margin the
    // surface is anchored with, so the panel is exactly as wide as the thing
    // inside it plus its own padding.
    //
    // The home branch is the one that is not a kept number: it is the face's
    // own content width, floored at metrics.collapsedWidth so the setting
    // still means "at least this wide". The face is content-sized by
    // contract (see IslandHomeFace), so this can never read back the value
    // it is setting -- implicitWidth is computed from the children, never
    // from `width`.
    property real targetW: {
        if (isOsd) return 275
        if (isMedia) return 406
        if (isControlCenter) return 460
        if (isCalendar) return UiState.calendarMonth ? 341 : 259
        if (isSettings) return 1320
        if (isLauncher) return 550
        if (isClipboard) return 480
        if (isPowerMenu) return powerInner.implicitWidth + 24
        if (isThemePicker) return themePickerContent.width + 24
        // The wallpaper picker is the exception to the +24: it carries its own
        // 16 of padding (see WallpaperPicker's ColumnLayout), so the panel
        // being the picker exactly is what puts the title 16 from the edge
        // rather than 12+16. Wrapped, it measured 28 against the reference's
        // 15 and pushed the panel 32 too wide.
        if (isWallpaperPicker) return wallpaperPickerContent.width
        return Math.max(homeFace.implicitWidth, metrics.collapsedWidth)
    }

    // Height per mode, same shape as targetW above. The settings entry is the
    // one that reads its own screen's height rather than a kept number: a
    // page that grows past the display would otherwise push the window off
    // the bottom edge, where the Flickable can scroll but the user cannot see
    // the title bar. Clamped per screen, not against screens[0], because one
    // panel is built per output.
    property real targetH: {
        if (isOsd) return 43
        if (isMedia) return 214
        if (isControlCenter) return controlCenterContent.implicitHeight
        if (isCalendar) return UiState.calendarMonth ? 281 : 117
        if (isSettings) return Math.min(settingsInner.implicitHeight,
            screenHeight - settingsTopInset - settingsBottomMargin)
        if (isLauncher) return launcherContent.implicitHeight + 24
        if (isClipboard) return clipboardInner.implicitHeight + 24
        if (isPowerMenu) return powerInner.implicitHeight + 24
        if (isThemePicker) return themePickerContent.implicitHeight + 24
        // Same as targetW above: the picker's own height is the panel height.
        if (isWallpaperPicker) return wallpaperPickerContent.implicitHeight
        return homeFace.implicitHeight
    }

    width: targetW
    height: targetH

    // A stiffer spring for the OSD: it appears on a volume keypress and is
    // gone in a second, so the panel has to arrive fast enough to be read as
    // feedback rather than as an animation.
    Behavior on width {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation {
            spring: root.isOsd ? 11 : 5.8
            damping: root.isOsd ? 0.75 : 0.68
            mass: root.isOsd ? 0.5 : 0.55
        }
    }
    Behavior on height {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation {
            spring: root.isOsd ? 11 : 5.8
            damping: root.isOsd ? 0.75 : 0.68
            mass: root.isOsd ? 0.5 : 0.55
        }
    }

    Surface {
        id: centerSurface
        anchors.fill: parent
        // An OSD is a pill in its own right; a surface that has opened is a
        // rounded card; home is whatever the collapsed radius works out to on
        // this monitor -- at BOTH of its sizes, because the wide home panel
        // measures the same radius as the pill and not the surfaces'.
        cornerRadius: root.isOsd
            ? root.height / 2
            : (root.isSurfaceOpen ? root.metrics.expandedCornerRadius : root.metrics.effectiveCollapsedRadius)
        topLeftRadius: (root.metrics.notchMode && root.homeRest) ? 0 : cornerRadius
        topRightRadius: (root.metrics.notchMode && root.homeRest) ? 0 : cornerRadius
        bottomLeftRadius: cornerRadius
        bottomRightRadius: cornerRadius
        // The control centre is deliberately neutral so it can sit over any
        // wallpaper/theme without turning into a coloured slab. Other island
        // states keep their palette-driven background.
        backgroundColor: root.isControlCenter ? Theme.panelFill : Theme.colors.background
        shadow: root.isSurfaceOpen || root.isOsd || homeFace.rich

        Behavior on cornerRadius {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 5.8; damping: 0.68; mass: 0.55 }
        }
        Behavior on topLeftRadius {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 5.8; damping: 0.68; mass: 0.55 }
        }
        Behavior on topRightRadius {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 5.8; damping: 0.68; mass: 0.55 }
        }

        // ------------------------------------------------------------------
        // The face stack. Order matters: siblings paint in declaration order,
        // so anything after another draws over it. The only exception is the
        // OSD, which raises itself with `z` when it is showing.
        // ------------------------------------------------------------------

        // Home: the pill at rest, the wide panel on hover or while a track is
        // loaded. One face rather than two, so the workspace bars, the clock
        // and the status indicators are declared once -- see
        // IslandHomeFace.qml for the sizing and stacking contracts.
        IslandHomeFace {
            id: homeFace
            anchors.fill: parent
            metrics: root.metrics
            screenName: root.screenName
            currentTime: root.currentTime
            currentDate: root.currentDate
            visible: root.isHome
            // Faded, not hidden, when an OSD is up: the pill underneath is
            // still this item's Surface and the OSD is what this 43px strip
            // is showing.
            opacity: root.isHome && !root.isOsd ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        }

        OSD {
            id: osdContent
            anchors.fill: parent
            visible: root.isOsd
            shadow: false

            // Sibling order decides the paint, and this is declared early
            // enough that every panel below draws over it. That meant a
            // volume keypress with the control centre or settings open
            // produced no feedback at all: the notch resized to 275x43, the
            // OSD was painted underneath, and the panel stayed on top. The
            // state was never lost -- mode is untouched by an OSD -- only the
            // feedback was invisible.
            //
            // So the OSD moves to the front whenever one is showing, and the
            // panel underneath is untouched and comes back when the OSD's own
            // timer expires. `z` rather than a move in the tree, because
            // reordering siblings would change the paint of every other
            // overlay pair for no reason.
            z: root.isOsd ? 100 : 0
        }

        // The two calendar faces are mutually exclusive views of one mode, so
        // both are declared and switched on calendarMonth.
        Calendar {
            anchors.fill: parent
            visible: root.isCalendar && !UiState.calendarMonth
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        }

        MonthCalendar {
            anchors.fill: parent
            visible: root.isCalendar && UiState.calendarMonth
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        }

        SettingsApp {
            id: settingsInner
            anchors.fill: parent
            visible: root.isSettings
            opacity: root.isSettings ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            // The panel's own Surface is the frame; a second one inside it
            // would double the border and the shadow.
            shadow: false
            borderWidth: 0
        }

        Launcher {
            id: launcherContent
            anchors.fill: parent
            anchors.margins: 12
            visible: root.isLauncher
            opacity: root.isLauncher ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            shadow: false
            backgroundColor: "transparent"
            borderWidth: 0
            results: AppLauncher.results
            onActivated: (res) => { AppLauncher.launch(res); UiState.close(); }
        }

        // Clipboard and the power menu each get a wrapper Item purely to hold
        // anchors.margins: their surfaces size to their content's width, and
        // the margin is what targetW's +24 is accounting for.
        Item {
            id: clipboardContent
            anchors.fill: parent
            anchors.margins: 12
            visible: root.isClipboard
            opacity: root.isClipboard ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            ClipboardHistory {
                id: clipboardInner
                width: parent.width
                shadow: false
                backgroundColor: "transparent"
                borderWidth: 0
                onCloseRequested: UiState.close()
            }
        }

        Item {
            id: powerMenuContent
            anchors.fill: parent
            anchors.margins: 12
            visible: root.isPowerMenu
            opacity: root.isPowerMenu ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            PowerMenu {
                id: powerInner
                width: parent.width
                shadow: false
                backgroundColor: "transparent"
                borderWidth: 0
                onActionTaken: UiState.close()
            }
        }

        // The two pickers are top-anchored and centred rather than filled:
        // they are short, and centring them vertically inside a panel sized
        // to their content would leave them off by half their own height.
        ThemePicker {
            id: themePickerContent
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 12
            themes: Theme.pickerModel
            shadow: false
            backgroundColor: "transparent"
            borderWidth: 0
            visible: root.isThemePicker
            opacity: root.isThemePicker ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            onThemeSelected: (index) => { Theme.selectByPickerIndex(index); UiState.close(); }
        }

        WallpaperPicker {
            id: wallpaperPickerContent
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            themeName: Theme.displayName
            themeKey: Theme.currentName
            wallpapers: Theme.wallpaperPickerModel
            shadow: false
            backgroundColor: "transparent"
            borderWidth: 0
            visible: root.isWallpaperPicker
            opacity: root.isWallpaperPicker ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            onWallpaperSelected: (idx) => { Theme.setWallpaper(idx); UiState.close(); }
        }

        // The media player and the control centre moved here from their own
        // dots. They keep the slide they had -- the content rises into place
        // rather than crossfading, so the island reads as opening rather than
        // as being replaced -- and they now arrive centred in the bar, where
        // the dots used to unroll leftward and rightward off the notch's
        // edges.
        //
        // The y is on the wrapper, not on the content: the content is
        // anchors.fill, and an explicit y on an anchored item silently
        // overrides the anchor.
        Item {
            id: mediaSlide
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height
            visible: root.isMedia
            y: root.isMedia ? 0 : -BarConfig.panelSlideIn
            Behavior on y {
                enabled: !MotionConfig.reduceMotion
                NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
            }

            MediaPlayerSurface {
                anchors.fill: parent
                opacity: root.isMedia ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }
        }

        Item {
            id: controlCenterSlide
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height
            visible: root.isControlCenter
            y: root.isControlCenter ? 0 : -BarConfig.panelSlideIn
            Behavior on y {
                enabled: !MotionConfig.reduceMotion
                NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
            }

            ControlCenter {
                id: controlCenterContent
                anchors.fill: parent
                opacity: root.isControlCenter ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                // The panel's own Surface is the frame; a second one inside it
                // would double the border and the shadow.
                shadow: false
                borderWidth: 0
                backgroundColor: "transparent"
            }
        }
    }
}
