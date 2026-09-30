import QtQuick
import "../components"
import "../services"
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    
    property bool notchMode: BarConfig.notchMode
    property real notchFlare: BarConfig.notchFlare
    property real barHeight: BarConfig.barHeight
    property real collapsedWidth: BarConfig.collapsedWidth
    property real expandedHeight: BarConfig.expandedHeight
    property real gapFromEdge: BarConfig.gapFromScreenEdge

    
    property alias leftSurfaceItem: leftDotWrap
    property alias centerSurfaceItem: centerNotchWrap
    property alias rightSurfaceItem: rightDotWrap

    implicitHeight: Math.max(leftDotWrap.height + leftDotWrap.y, Math.max(centerNotchWrap.height + centerNotchWrap.y, rightDotWrap.height + rightDotWrap.y)) + 20

    
    property string currentTime: Qt.formatTime(new Date(), "hh:mm")
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "hh:mm")
    }

    
    readonly property real topOffset: notchMode ? 0 : gapFromEdge
    readonly property real dotSpacing: 10

    
    
    
    Item {
        id: leftDotWrap
        y: root.topOffset
        
        
        
        
        
        
        visible: BarConfig.albumArtCircleEnabled

        
        
        
        
        
        readonly property bool isExpanded: UiState.mediaOpen
        property real targetW: isExpanded ? 406 : root.barHeight
        property real targetH: isExpanded ? 214 : root.barHeight

        width: targetW
        height: targetH

        
        
        
        readonly property real collapsedX: centerNotchWrap.x - root.barHeight - root.dotSpacing
        readonly property real collapsedCentre: collapsedX + root.barHeight / 2

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        x: isExpanded
            ? Math.max(root.gapFromEdge,
                Math.min(collapsedX + root.barHeight - targetW,
                         root.width - targetW - root.gapFromEdge))
            : collapsedX

        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        Behavior on x {
            enabled: !MotionConfig.reduceMotion && !centerNotchWrap.isOsd
            SpringAnimation { spring: 9; damping: MotionConfig.springDamping; mass: 0.6 }
        }

        
        Surface {
            id: leftSurface
            anchors.fill: parent
            cornerRadius: leftDotWrap.isExpanded ? BarConfig.expandedCornerRadius : BarConfig.effectiveCollapsedRadius
            topLeftRadius: (root.notchMode && !leftDotWrap.isExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !leftDotWrap.isExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            
            
            
            
            backgroundColor: "#000000"
            shadow: leftDotWrap.isExpanded

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            
            Item {
                anchors.fill: parent
                visible: !leftDotWrap.isExpanded
                opacity: leftDotWrap.isExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                Item {
                    id: dotArtContainer
                    anchors.centerIn: parent
                    width: root.barHeight - 2 * BarConfig.innerPadding
                    height: width
                    
                    
                    
                    
                    
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2 - (leftDotHover.containsMouse ? BarConfig.stageLiftOnHover : 0)
                    scale: leftDotHover.containsMouse ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }
                    Behavior on y {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }

                    
                    
                    
                    
                    
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

            
            
            
            
            
            
            
            Item {
                id: mediaSlide
                anchors.fill: parent
                visible: leftDotWrap.isExpanded
                // On a wrapper, not on the content: the content is
                // anchors.fill, and an explicit y on an anchored item
                // silently overrides the anchor.
                y: leftDotWrap.isExpanded ? 0 : -BarConfig.panelSlideIn
                Behavior on y {
                    enabled: !MotionConfig.reduceMotion
                    NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
                }

                MediaPlayerSurface {
                    anchors.fill: parent
                    opacity: leftDotWrap.isExpanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    
    
    
    Item {
        id: centerNotchWrap
        
        
        
        y: isSettings ? 76 : root.topOffset
        anchors.horizontalCenter: parent.horizontalCenter

        readonly property bool isCalendar: UiState.calendarOpen
        readonly property bool isSettings: UiState.settingsOpen
        readonly property bool isLauncher: UiState.launcherOpen
        readonly property bool isClipboard: UiState.clipboardOpen
        readonly property bool isPowerMenu: UiState.powerMenuOpen
        readonly property bool isThemePicker: UiState.themePickerOpen
        readonly property bool isWallpaperPicker: UiState.wallpaperPickerOpen
        
        
        
        readonly property bool isOsd: UiState.osdVisible

        
        
        
        
        readonly property bool isCenterExpanded: isCalendar || isSettings || isLauncher || isClipboard || isPowerMenu || isThemePicker || isWallpaperPicker

        property real targetW: {
            if (isOsd) return 275
            if (isCalendar) return UiState.calendarMonth ? 341 : 259
            if (isSettings) return 1320
            if (isLauncher) return 550
            if (isClipboard) return 480
            if (isPowerMenu) return powerInner.implicitWidth + 24
            if (isThemePicker) return themePickerContent.width + 24
            if (isWallpaperPicker) return wallpaperPickerContent.width + 24
            return root.collapsedWidth
        }

        property real targetH: {
            if (isOsd) return 43
            if (isCalendar) return UiState.calendarMonth ? 281 : 117
            if (isSettings) return 969
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
            SpringAnimation {
                spring: centerNotchWrap.isOsd ? 11 : 4.8
                damping: MotionConfig.springDamping
                mass: centerNotchWrap.isOsd ? 0.6 : 0.8
            }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation {
                spring: centerNotchWrap.isOsd ? 11 : 4.8
                damping: MotionConfig.springDamping
                mass: centerNotchWrap.isOsd ? 0.6 : 0.8
            }
        }

        Surface {
            id: centerSurface
            anchors.fill: parent
            
            
            
            
            cornerRadius: centerNotchWrap.isOsd
                ? centerNotchWrap.height / 2
                : (centerNotchWrap.isCenterExpanded ? BarConfig.expandedCornerRadius : BarConfig.effectiveCollapsedRadius)
            topLeftRadius: (root.notchMode && !centerNotchWrap.isCenterExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !centerNotchWrap.isCenterExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            backgroundColor: "#000000"
            shadow: centerNotchWrap.isCenterExpanded || centerNotchWrap.isOsd

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            
            Item {
                anchors.fill: parent
                
                
                
                
                
                
                visible: !centerNotchWrap.isCenterExpanded
                opacity: centerNotchWrap.isCenterExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                MouseArea {
                    id: notchHover
                    anchors.fill: parent
                    
                    
                    
                    
                    
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggleCalendar()
                }

                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
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
                        color: "#F7EFE1"
                        visible: !centerNotchWrap.isOsd
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                    }
                }
            }

            
            
            
            
            OSD {
                id: osdContent
                anchors.fill: parent
                visible: centerNotchWrap.isOsd
                shadow: false
            }

            
            Calendar {
                anchors.fill: parent
                visible: centerNotchWrap.isCalendar && !UiState.calendarMonth
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }

            
            MonthCalendar {
                anchors.fill: parent
                visible: centerNotchWrap.isCalendar && UiState.calendarMonth
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }

            
            SettingsApp {
                id: settingsInner
                anchors.fill: parent
                visible: centerNotchWrap.isSettings
                opacity: centerNotchWrap.isSettings ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                shadow: false
                borderWidth: 0
            }

            
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

    
    
    
    Item {
        id: rightDotWrap
        y: root.topOffset
        
        
        
        
        visible: BarConfig.statusCircleEnabled

        readonly property bool isExpanded: UiState.controlCenterOpen
        
        
        
        
        
        
        
        
        
        
        
        property real targetW: isExpanded ? 514 : root.barHeight
        property real targetH: isExpanded ? controlCenterContent.implicitHeight : root.barHeight

        width: targetW
        height: targetH

        
        readonly property real collapsedX: centerNotchWrap.x + centerNotchWrap.width + root.dotSpacing
        readonly property real collapsedCentre: collapsedX + root.barHeight / 2

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        x: isExpanded
            ? Math.max(root.gapFromEdge,
                Math.min(collapsedX, root.width - targetW - root.gapFromEdge))
            : collapsedX

        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        Behavior on x {
            enabled: !MotionConfig.reduceMotion && !centerNotchWrap.isOsd
            SpringAnimation { spring: 9; damping: MotionConfig.springDamping; mass: 0.6 }
        }

        Surface {
            id: rightSurface
            anchors.fill: parent
            cornerRadius: rightDotWrap.isExpanded ? BarConfig.expandedCornerRadius : BarConfig.effectiveCollapsedRadius
            topLeftRadius: (root.notchMode && !rightDotWrap.isExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !rightDotWrap.isExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            
            
            
            
            
            backgroundColor: "#000000"

            shadow: rightDotWrap.isExpanded

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            
            Item {
                anchors.fill: parent
                visible: !rightDotWrap.isExpanded
                opacity: rightDotWrap.isExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                Item {
                    id: rightDotArtContainer
                    anchors.centerIn: parent
                    width: root.barHeight - 2 * BarConfig.innerPadding
                    height: width
                    
                    
                    
                    
                    
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2 - (rightDotHover.containsMouse ? BarConfig.stageLiftOnHover : 0)
                    scale: rightDotHover.containsMouse ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }
                    Behavior on y {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }

                    
                    BatteryRing {
                        anchors.fill: parent
                        percentage: Battery.percentage
                        charging: Battery.charging
                        strokeWidth: 2.2
                    }

                    
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

            
            
            
            
            
            
            Item {
                id: controlCenterSlide
                anchors.fill: parent
                visible: rightDotWrap.isExpanded

                y: rightDotWrap.isExpanded ? 0 : -BarConfig.panelSlideIn
                Behavior on y {
                    enabled: !MotionConfig.reduceMotion
                    NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
                }

                ControlCenter {
                    id: controlCenterContent
                    anchors.fill: parent
                    opacity: rightDotWrap.isExpanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                    shadow: false
                    borderWidth: 0
                    backgroundColor: "transparent"
                }
            }
        }
    }

    
    Keys.onEscapePressed: UiState.closeAll()
    focus: UiState.anyOpen
    Keys.enabled: UiState.anyOpen
}
