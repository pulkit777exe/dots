import QtQuick
import "../components"
import "../services"
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    // Geometry from BarConfig
    property bool notchMode: BarConfig.notchMode
    property real notchFlare: BarConfig.notchFlare
    property real barHeight: BarConfig.barHeight
    property real collapsedWidth: BarConfig.collapsedWidth
    property real expandedHeight: BarConfig.expandedHeight
    property real gapFromEdge: BarConfig.gapFromScreenEdge

    // Expose surface items for shell.qml click-masking
    property alias leftSurfaceItem: leftDotWrap
    property alias centerSurfaceItem: centerNotchWrap
    property alias rightSurfaceItem: rightDotWrap

    implicitHeight: Math.max(leftDotWrap.height + leftDotWrap.y, Math.max(centerNotchWrap.height + centerNotchWrap.y, rightDotWrap.height + rightDotWrap.y)) + 20

    // Clock
    property string currentTime: Qt.formatTime(new Date(), "hh:mm")
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "hh:mm")
    }

    // Top offset based on notch mode
    readonly property real topOffset: notchMode ? 0 : gapFromEdge
    readonly property real dotSpacing: 10

    // ============================================================
    // LEFT DOT / MEDIA PLAYER
    // ============================================================
    Item {
        id: leftDotWrap
        y: root.topOffset
        // "Album art circle while a player is open" — no player, no
        // circle, rather than a lone music-note icon sitting there
        // with nothing to show.
        visible: BarConfig.albumArtCircleEnabled && Media.hasPlayer

        // When expanded as Media Player: width 440, height 160
        // When collapsed: circular dot (barHeight × barHeight)
        readonly property bool isExpanded: UiState.mediaOpen
        property real targetW: isExpanded ? 440 : root.barHeight
        property real targetH: isExpanded ? 160 : root.barHeight

        width: targetW
        height: targetH

        // Position: when collapsed, sits immediately to the left of center notch
        // When expanded, anchors smoothly near top center-left
        x: isExpanded
            ? (root.width / 2 - width - 8)
            : (centerNotchWrap.x - width - root.dotSpacing)

        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on x {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }

        // Surface Card
        Surface {
            id: leftSurface
            anchors.fill: parent
            cornerRadius: leftDotWrap.isExpanded ? BarConfig.expandedCornerRadius : (root.barHeight / 2)
            topLeftRadius: (root.notchMode && !leftDotWrap.isExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !leftDotWrap.isExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            backgroundColor: leftDotWrap.isExpanded ? "#141414" : "#000000"
            shadow: leftDotWrap.isExpanded

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            // ---- Collapsed Dot Content (Reference 1) ----
            Item {
                anchors.fill: parent
                visible: !leftDotWrap.isExpanded
                opacity: leftDotWrap.isExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                Item {
                    id: dotArtContainer
                    anchors.centerIn: parent
                    width: root.barHeight - 6
                    height: root.barHeight - 6
                    scale: leftDotHover.containsMouse ? 1.05 : 1.0
                    y: leftDotHover.containsMouse ? 1 : 0

                    Behavior on scale {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }
                    Behavior on y {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }

                    // Circular mask via native clipping — no Qt5Compat
                    // dependency (see ARCHITECTURE.md: GraphicalEffects
                    // isn't installed on the target machine and already
                    // crashed once; Surface.qml's shadow was rewritten
                    // to avoid it, this should follow the same rule).
                    Rectangle {
                        id: dotArtClip
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        clip: true
                        visible: Media.artUrl.length > 0

                        Image {
                            id: dotRawArt
                            anchors.fill: parent
                            source: Media.artUrl
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        icon: "music_note"
                        size: 16
                        iconColor: Qt.rgba(1, 1, 1, 0.8)
                        visible: Media.artUrl.length === 0
                    }
                }

                MouseArea {
                    id: leftDotHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggleMedia()
                }
            }

            // ---- Expanded Media Player Content (Reference 3) ----
            MediaPlayerSurface {
                anchors.fill: parent
                visible: leftDotWrap.isExpanded
                opacity: leftDotWrap.isExpanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }
        }
    }

    // ============================================================
    // CENTER NOTCH / CALENDAR / SETTINGS / POPUPS
    // ============================================================
    Item {
        id: centerNotchWrap
        y: root.topOffset
        anchors.horizontalCenter: parent.horizontalCenter

        readonly property bool isCalendar: UiState.calendarOpen
        readonly property bool isSettings: UiState.settingsOpen
        readonly property bool isLauncher: UiState.launcherOpen
        readonly property bool isClipboard: UiState.clipboardOpen
        readonly property bool isPowerMenu: UiState.powerMenuOpen
        readonly property bool isThemePicker: UiState.themePickerOpen
        readonly property bool isWallpaperPicker: UiState.wallpaperPickerOpen

        readonly property bool isCenterExpanded: isCalendar || isSettings || isLauncher || isClipboard || isPowerMenu || isThemePicker || isWallpaperPicker

        property real targetW: {
            if (isCalendar) return 300
            if (isSettings) return 820
            if (isLauncher) return 550
            if (isClipboard) return 480
            if (isPowerMenu) return powerInner.implicitWidth + 24
            if (isThemePicker) return themePickerContent.width + 24
            if (isWallpaperPicker) return wallpaperPickerContent.width + 24
            return root.collapsedWidth
        }

        property real targetH: {
            if (isCalendar) return 115
            if (isSettings) return 580
            if (isLauncher) return launcherContent.implicitHeight + 24
            if (isClipboard) return clipboardInner.implicitHeight + 24
            if (isPowerMenu) return powerInner.implicitHeight + 24
            if (isThemePicker) return themePickerContent.implicitHeight + 24
            if (isWallpaperPicker) return wallpaperPickerContent.implicitHeight + 24
            return root.barHeight
        }

        width: targetW
        height: targetH

        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }

        Surface {
            id: centerSurface
            anchors.fill: parent
            cornerRadius: centerNotchWrap.isCenterExpanded ? BarConfig.expandedCornerRadius : (root.barHeight / 2)
            topLeftRadius: (root.notchMode && !centerNotchWrap.isCenterExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !centerNotchWrap.isCenterExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            backgroundColor: "#000000"
            shadow: centerNotchWrap.isCenterExpanded

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            // ---- Collapsed Pill Content (Reference 1) ----
            Item {
                anchors.fill: parent
                visible: !centerNotchWrap.isCenterExpanded
                opacity: centerNotchWrap.isCenterExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                StyledText {
                    anchors.centerIn: parent
                    text: root.currentTime
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Solid.fg(1)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggleCalendar()
                }
            }

            // ---- Expanded Calendar Content (Reference 4) ----
            Calendar {
                anchors.fill: parent
                visible: centerNotchWrap.isCalendar
                opacity: centerNotchWrap.isCalendar ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }

            // ---- Expanded Settings Content (Reference 5) ----
            SettingsApp {
                id: settingsInner
                anchors.fill: parent
                visible: centerNotchWrap.isSettings
                opacity: centerNotchWrap.isSettings ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                shadow: false
                borderWidth: 0
            }

            // ---- Expanded Launcher Content ----
            Launcher {
                id: launcherContent
                anchors.fill: parent
                anchors.margins: 12
                visible: centerNotchWrap.isLauncher
                opacity: centerNotchWrap.isLauncher ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                shadow: false
                backgroundColor: "transparent"
                borderWidth: 0
                results: AppLauncher.results
                onActivated: (res) => { AppLauncher.launch(res); UiState.close(); }
            }

            // ---- Expanded Clipboard Content ----
            Item {
                id: clipboardContent
                anchors.fill: parent
                anchors.margins: 12
                visible: centerNotchWrap.isClipboard
                opacity: centerNotchWrap.isClipboard ? 1 : 0
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

            // ---- Expanded PowerMenu Content ----
            Item {
                id: powerMenuContent
                anchors.fill: parent
                anchors.margins: 12
                visible: centerNotchWrap.isPowerMenu
                opacity: centerNotchWrap.isPowerMenu ? 1 : 0
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

            // ---- Expanded Theme Picker Content ----
            ThemePicker {
                id: themePickerContent
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 12
                themes: Theme.pickerModel
                shadow: false
                backgroundColor: "transparent"
                borderWidth: 0
                visible: centerNotchWrap.isThemePicker
                opacity: centerNotchWrap.isThemePicker ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                onThemeSelected: (index) => { Theme.selectByPickerIndex(index); UiState.close(); }
            }

            // ---- Expanded Wallpaper Picker Content ----
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
                visible: centerNotchWrap.isWallpaperPicker
                opacity: centerNotchWrap.isWallpaperPicker ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                onWallpaperSelected: (idx) => { Theme.setWallpaper(idx); UiState.close(); }
            }
        }
    }

    // ============================================================
    // RIGHT DOT / CONTROL CENTER
    // ============================================================
    Item {
        id: rightDotWrap
        y: root.topOffset
        // "Status circle (battery and Wi-Fi)" toggle. Unlike the
        // album-art dot this has no "only when relevant" condition —
        // battery/Wi-Fi status is always relevant — so it's a plain
        // on/off, no Media-style gate.
        visible: BarConfig.statusCircleEnabled

        readonly property bool isExpanded: UiState.controlCenterOpen
        property real targetW: isExpanded ? 440 : root.barHeight
        property real targetH: isExpanded ? controlCenterContent.implicitHeight : root.barHeight

        width: targetW
        height: targetH

        // Position: when collapsed, sits immediately to the right of center notch
        // When expanded, anchors smoothly near top center-right
        x: isExpanded
            ? (root.width / 2 + 8)
            : (centerNotchWrap.x + centerNotchWrap.width + root.dotSpacing)

        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on x {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }

        Surface {
            id: rightSurface
            anchors.fill: parent
            cornerRadius: rightDotWrap.isExpanded ? BarConfig.expandedCornerRadius : (root.barHeight / 2)
            topLeftRadius: (root.notchMode && !rightDotWrap.isExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !rightDotWrap.isExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            backgroundColor: rightDotWrap.isExpanded ? "#141414" : "#000000"
            shadow: rightDotWrap.isExpanded

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            // ---- Collapsed Dot Content (Reference 1) ----
            Item {
                anchors.fill: parent
                visible: !rightDotWrap.isExpanded
                opacity: rightDotWrap.isExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                Item {
                    id: rightDotArtContainer
                    anchors.centerIn: parent
                    width: root.barHeight - 2
                    height: root.barHeight - 2
                    scale: rightDotHover.containsMouse ? 1.05 : 1.0
                    y: rightDotHover.containsMouse ? 1 : 0

                    Behavior on scale {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }
                    Behavior on y {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }

                    // Circular Battery Ring
                    BatteryRing {
                        anchors.fill: parent
                        percentage: Battery.percentage
                        charging: Battery.charging
                        strokeWidth: 2.2
                    }

                    // Centered Wi-Fi / Status Icon
                    Icon {
                        anchors.centerIn: parent
                        icon: !Wifi.enabled ? "wifi_off" : (Wifi.connected ? "wifi" : "wifi_find")
                        size: 15
                        iconColor: Qt.rgba(1, 1, 1, 0.92)
                    }
                }

                MouseArea {
                    id: rightDotHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggleControlCenter()
                }
            }

            // ---- Expanded Control Center Content (Reference 2) ----
            ControlCenter {
                id: controlCenterContent
                anchors.fill: parent
                visible: rightDotWrap.isExpanded
                opacity: rightDotWrap.isExpanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                shadow: false
                borderWidth: 0
                backgroundColor: "transparent"
            }
        }
    }

    // Keyboard dismiss
    Keys.onEscapePressed: UiState.closeAll()
    focus: UiState.anyOpen
    Keys.enabled: UiState.anyOpen
}
