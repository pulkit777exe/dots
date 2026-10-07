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

            readonly property bool isFullscreen: Compositor.activeWindowFullscreen && !UiState.anyOpen

            // Same condition as hiddenForFullscreen: when the island is kept
            // up for an OSD it has to stay interactive, or the pill is drawn
            // but cannot be clicked and the mask silently eats the input.
            mask: Region {
                Region { item: island.hiddenForFullscreen ? null : island.surfaceItem }
            }

            // Hiding the bar also has to give the space back. An exclusive
            // zone is a claim on the compositor's layout, so leaving it set
            // while the bar is invisible reserves barHeight + gap that
            // nothing draws in: a fullscreen window stops short of the top
            // of the screen by exactly that much, with a black band above
            // it that looks like a rendering fault.
            //
            // `anyOpen` keeps the zone reserved when an overlay is up, so a
            // panel that is open on top of a fullscreen window still gets
            // the room it needs and is not clipped by its own window.
            exclusiveZone: (barWindow.isFullscreen && !UiState.anyOpen && island.hiddenForFullscreen)
                ? 0
                : (island.barHeight + (island.notchMode ? 0 : island.gapFromEdge))

            HyprlandFocusGrab {
                active: UiState.anyOpen && Auth.pending === null
                windows: [barWindow]
            }

            Island {
                id: island
                screenName: barWindow.screen ? barWindow.screen.name : ""

                // The resting bar is what fullscreen hides. An OSD or a
                // notification is not: both are the shell telling you
                // something changed, and a volume keypress that produces no
                // feedback at all while a video is playing is indistinguishable
                // from a broken key.
                //
                // `isFullscreen` above already excludes the case where a panel
                // is open, so this only ever fires over a plain fullscreen
                // window. Adding osdVisible and the notification count is what
                // keeps the island up for exactly as long as the transient
                // lasts -- it then fades out on its own when the OSD timer
                // expires, because `osdVisible` goes false.
                //
                // The OSD has to be shown this way because it lives inside the
                // island's notch, not in the overlay window the way
                // notifications do. That is also why notifications already
                // worked over fullscreen and the OSD did not.
                readonly property bool hiddenForFullscreen:
                    barWindow.isFullscreen && !UiState.osdVisible && Notifications.active.length === 0

                opacity: hiddenForFullscreen ? 0 : 1
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
