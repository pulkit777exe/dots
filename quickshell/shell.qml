import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.surfaces
import qs.modules
















ShellRoot {
    id: shellRoot

    
    
    
    
    
    
    // Only reference to Keybinds in the tree. It is a `pragma Singleton`, so
    // this line is what constructs it -- and constructing it is what registers
    // the shell/uis IpcHandlers. Delete this and every overlay is unreachable,
    // with no error and no warning anywhere.
    property var keybinds: Keybinds

    
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: wallWin
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "black"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-wallpaper"

            readonly property string transitionStyle: ConfigStore.wallpaperTransitionStyle
            readonly property real progress: Theme.wallpaperProgress
            readonly property bool isTransitioning: Theme.wallpaperTransitioning

            
            Image {
                id: wallFrom
                anchors.fill: parent
                source: Theme.wallpaperFrom
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: wallWin.transitionStyle !== "circleOut" || !wallWin.isTransitioning

                opacity: {
                    if (wallWin.transitionStyle === "instant") return 0;
                    if (wallWin.transitionStyle === "fade") return 1 - wallWin.progress;
                    return 1;
                }
                scale: wallWin.transitionStyle === "fade" ? (1 + (1 - wallWin.progress) * 0.015) : 1
                x: wallWin.transitionStyle === "slide" ? (-width * wallWin.progress) : 0
                y: wallWin.transitionStyle === "slideVertical" ? (-height * wallWin.progress) : 0
            }

            
            Image {
                id: wallTo
                anchors.fill: parent
                source: Theme.wallpaperTo || Theme.currentWallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: wallWin.transitionStyle !== "circleOut" || !wallWin.isTransitioning

                opacity: {
                    if (wallWin.transitionStyle === "instant") return wallWin.progress >= 1 ? 1 : 1;
                    if (wallWin.transitionStyle === "fade") return wallWin.progress;
                    return 1;
                }
                scale: wallWin.transitionStyle === "fade" ? (1 + (1 - wallWin.progress) * 0.025) : 1
                x: wallWin.transitionStyle === "slide" ? (width * (1 - wallWin.progress)) : 0
                y: wallWin.transitionStyle === "slideVertical" ? (height * (1 - wallWin.progress)) : 0
            }

            
            
            
            Item {
                id: circleWipeContainer
                anchors.fill: parent
                visible: wallWin.transitionStyle === "circleOut" && wallWin.isTransitioning

                
                Image {
                    anchors.fill: parent
                    source: Theme.wallpaperFrom
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                
                Item {
                    id: circleMaskItem
                    anchors.fill: parent
                    visible: false  

                    Rectangle {
                        readonly property real diagLen: Math.sqrt(
                            wallWin.width * wallWin.width + wallWin.height * wallWin.height)
                        readonly property real side: Math.max(0, diagLen * wallWin.progress + 2)
                        anchors.centerIn: parent
                        width: side; height: side
                        radius: side / 2
                        color: "black"
                    }
                }

                
                Image {
                    id: wallpaperCircle
                    anchors.fill: parent
                    source: Theme.wallpaperTo || Theme.currentWallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: circleMaskItem
                        maskThresholdMin: 0.0
                        maskThresholdMax: 1.0
                    }
                }
            }

            
            Rectangle {
                anchors.fill: parent
                color: Theme.colors.background
                opacity: (Theme.wallpaperFrom === "" && Theme.wallpaperTo === "") ? 0.3 : 0
                Behavior on color { ColorAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                z: -1
            }
        }
    }

    
    
    
    
    
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-backdrop"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
            mask: Region { item: UiState.anyOpen ? backdropClickTarget : null }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.30)
                opacity: UiState.anyOpen ? 1 : 0
                visible: opacity > 0.005
                Behavior on opacity {
                    NumberAnimation {
                        duration: MotionConfig.fade(1.4)
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                id: backdropClickTarget
                anchors.fill: parent
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: UiState.closeAll()
                }
            }
        }
    }

    
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            
            
            
            exclusiveZone: island.barHeight + (island.notchMode ? 0 : island.gapFromEdge)
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-bar"
            focusable: Auth.pending === null && UiState.anyOpen
            WlrLayershell.keyboardFocus: Auth.pending !== null ? WlrKeyboardFocus.None : (UiState.anyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None)

            
            
            
            
            // The window's height comes from the island's own implicitHeight,
            // which is the max of the three dot panels' real heights.
            //
            // It used to be two hand-kept numbers here -- 1045 when settings
            // was open, 700 for everything else. That is a second place to
            // remember the panel heights, and it had already drifted: the
            // control centre's sound view is 719px tall, so 700 clipped its
            // last 19px with nothing logged. A panel height changed in
            // ControlCenter.qml and the window did not follow.
            //
            // Taking island.implicitHeight means a panel can be any height
            // it likes and the window is always tall enough, because it is
            // reading the layout rather than restating it.
            implicitHeight: Math.max(island.implicitHeight, island.barHeight + (island.notchMode ? 0 : island.gapFromEdge) + 16)

            readonly property bool isFullscreen: Boolean(Hyprland.activeWindow && Hyprland.activeWindow.fullscreen) && !UiState.anyOpen

            mask: Region {
                Region { item: isFullscreen ? null : island.leftSurfaceItem }
                Region { item: isFullscreen ? null : island.centerSurfaceItem }
                Region { item: isFullscreen ? null : island.rightSurfaceItem }
            }

            HyprlandFocusGrab {
                active: UiState.anyOpen && Auth.pending === null
                windows: [barWindow]
            }

            Island {
                id: island
                screenName: barWindow.screen ? barWindow.screen.name : ""
                opacity: barWindow.isFullscreen ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
            }
        }
    }

    
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-overlay"
            focusable: Auth.pending !== null
            WlrLayershell.keyboardFocus: Auth.pending !== null
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

            mask: Region {
                Region { item: Notifications.active.length > 0 ? notifWrap : null }
                
                
                Region { item: Auth.pending !== null ? authWrap : null }
            }

            
            Item {
                id: notifWrap
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                width: stack.width
                height: stack.implicitHeight

                NotificationStack { id: stack }
            }

            
            
            
            
            
            

            
            Item {
                id: authWrap
                anchors.fill: parent
                visible: Auth.pending !== null

                AuthOverlay {}
            }
        }
    }
}
