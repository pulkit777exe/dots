import QtQuick
import "../components"
import "../services"
import Quickshell

// The centre panel: the notch at rest, and every surface that opens in it.
//
// One region of the bar, and the only one that is a stack rather than a
// dot. Its job is a mapping from "which mode is open" to "how big is this
// panel" -- targetW and targetH below -- plus the ten faces that mapping
// selects between. Seven of the nine modes size themselves from a child's
// own implicit size rather than a number kept here, so a page that grows
// takes the panel with it.
//
// The faces are all children of one Surface, all anchored to fill it, and
// exactly one is visible at a time (UiState.mode is a single enum). They
// are NOT in a StackView or behind a Loader: they are declared together and
// switched by `visible`, because every one of them has to report its size
// the moment it becomes visible, and a Loader would report nothing until it
// had loaded.
Item {
    id: root

    // Resolved per-monitor bar geometry -- see IslandMetrics.qml.
    property var metrics

    // Which monitor this panel is on. Only used to clamp the settings page's
    // height to the screen it is actually on: one panel is built per screen,
    // so screens[0] would be the wrong answer on every screen but the first.
    property string screenName: ""

    // The settings panel drops below the notch row so it does not cover the
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
    // that text rather than with the bar's layout.
    property string currentTime: Qt.formatTime(new Date(), "hh:mm")
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "hh:mm")
    }

    y: isSettings ? settingsTopInset : metrics.topOffset
    // Centred in the bar window. Island is this item's direct parent and is
    // the full-width item shell.qml anchors, so `parent` is the right thing
    // to be centred against -- there is no panel stack above this.
    anchors.horizontalCenter: parent.horizontalCenter

    readonly property bool isCalendar: UiState.calendarOpen
    readonly property bool isSettings: UiState.settingsOpen
    readonly property bool isLauncher: UiState.launcherOpen
    readonly property bool isClipboard: UiState.clipboardOpen
    readonly property bool isPowerMenu: UiState.powerMenuOpen
    readonly property bool isThemePicker: UiState.themePickerOpen
    readonly property bool isWallpaperPicker: UiState.wallpaperPickerOpen
    readonly property bool isOsd: UiState.osdVisible

    // The panel is "expanded" for the seven full surfaces. The OSD is not one
    // of them: it is a transient over the top of whatever is already open,
    // which is why isOsd is deliberately absent from this list.
    readonly property bool isCenterExpanded: isCalendar || isSettings || isLauncher || isClipboard || isPowerMenu || isThemePicker || isWallpaperPicker

    // Width per mode. Where a surface declares its own width, that is read
    // instead of a number being repeated here -- the +24 is the margin the
    // surface is anchored with, so the panel is exactly as wide as the thing
    // inside it plus its own padding.
    property real targetW: {
        if (isOsd) return 275
        if (isCalendar) return UiState.calendarMonth ? 341 : 259
        if (isSettings) return 1320
        if (isLauncher) return 550
        if (isClipboard) return 480
        if (isPowerMenu) return powerInner.implicitWidth + 24
        if (isThemePicker) return themePickerContent.width + 24
        if (isWallpaperPicker) return wallpaperPickerContent.width + 24
        return metrics.collapsedWidth
    }

    // Height per mode, same shape as targetW above. The settings entry is the
    // one that reads its own screen's height rather than a kept number: a
    // page that grows past the display would otherwise push the window off
    // the bottom edge, where the Flickable can scroll but the user cannot see
    // the title bar. Clamped per screen, not against screens[0], because one
    // panel is built per output.
    property real targetH: {
        if (isOsd) return 43
        if (isCalendar) return UiState.calendarMonth ? 281 : 117
        if (isSettings) return Math.min(settingsInner.implicitHeight,
            screenHeight - settingsTopInset - settingsBottomMargin)
        if (isLauncher) return launcherContent.implicitHeight + 24
        if (isClipboard) return clipboardInner.implicitHeight + 24
        if (isPowerMenu) return powerInner.implicitHeight + 24
        if (isThemePicker) return themePickerContent.implicitHeight + 24
        if (isWallpaperPicker) return wallpaperPickerContent.implicitHeight + 24
        return metrics.barHeight
    }

    width: targetW
    height: targetH

    // A stiffer spring for the OSD: it appears on a volume keypress and is
    // gone in a second, so the panel has to arrive fast enough to be read as
    // feedback rather than as an animation.
    Behavior on width {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation {
            spring: root.isOsd ? 11 : 4.8
            damping: MotionConfig.springDamping
            mass: root.isOsd ? 0.6 : 0.8
        }
    }
    Behavior on height {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation {
            spring: root.isOsd ? 11 : 4.8
            damping: MotionConfig.springDamping
            mass: root.isOsd ? 0.6 : 0.8
        }
    }

    Surface {
        id: centerSurface
        anchors.fill: parent
        // An OSD is a pill in its own right; a surface that has opened is a
        // rounded card; the notch is whatever the collapsed radius works out
        // to on this monitor.
        cornerRadius: root.isOsd
            ? root.height / 2
            : (root.isCenterExpanded ? metrics.expandedCornerRadius : metrics.effectiveCollapsedRadius)
        topLeftRadius: (metrics.notchMode && !root.isCenterExpanded) ? 0 : cornerRadius
        topRightRadius: (metrics.notchMode && !root.isCenterExpanded) ? 0 : cornerRadius
        bottomLeftRadius: cornerRadius
        bottomRightRadius: cornerRadius
        backgroundColor: Theme.colors.background
        shadow: root.isCenterExpanded || root.isOsd

        Behavior on cornerRadius {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }

        // ------------------------------------------------------------------
        // The face stack. Order matters: siblings paint in declaration order,
        // so anything after another draws over it. The only exception is the
        // OSD, which raises itself with `z` when it is showing.
        // ------------------------------------------------------------------

        // The notch at rest: the clock.
        Item {
            anchors.fill: parent
            visible: !root.isCenterExpanded
            opacity: root.isCenterExpanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

            MouseArea {
                id: notchHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: UiState.toggleCalendar()
            }

            // Lifts on hover, half the dot's lift: the clock is wider than it
            // is tall, so the full lift would drop it below the bar.
            Item {
                width: parent.width
                height: parent.height
                y: -(notchHover.containsMouse ? BarConfig.stageLiftOnHover / 2 : 0)
                scale: notchHover.containsMouse ? 1.05 : 1.0

                Behavior on scale {
                    enabled: !MotionConfig.reduceMotion
                    SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                }
                Behavior on y {
                    enabled: !MotionConfig.reduceMotion
                    SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: root.currentTime
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    textColor: Theme.colors.text
                    // Faded out rather than hidden when an OSD is up: the
                    // clock is still there underneath, it is just not what
                    // this 43px strip is showing.
                    visible: !root.isOsd
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                }
            }
        }

        OSD {
            id: osdContent
            anchors.fill: parent
            visible: root.isOsd
            shadow: false

            // Sibling order decides the paint, and this is the first
            // child of centerSurface, so every panel below draws over
            // it. That meant a volume keypress with the control centre
            // or settings open produced no feedback at all: the notch
            // resized to 275x43, the OSD was painted underneath, and the
            // panel stayed on top. The state was never lost -- mode is
            // untouched by an OSD -- only the feedback was invisible.
            //
            // So the OSD moves to the front whenever one is showing, and
            // the panel underneath is untouched and comes back when the
            // OSD's own timer expires. `z` rather than a move in the
            // tree, because reordering siblings would change the paint
            // of every other overlay pair for no reason.
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
            anchors.topMargin: 12
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
    }
}
