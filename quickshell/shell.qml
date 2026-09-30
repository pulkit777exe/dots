import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.surfaces
import qs.modules

// shell.qml
// Entry point: `quickshell -c /path/to/this/dir` (or symlink this whole
// directory to ~/.config/quickshell/<name>/ and run `qs -c <name>`).
//
// Four layer-shell windows per screen:
//   WallpaperWindow - Background layer, wallpaper crossfade.
//   BackdropWindow  - Top layer (BELOW Overlay), fullscreen dark scrim.
//                     Separate from Island's Overlay window — the Island
//                     simply renders above it, no mask-subtraction needed,
//                     which is the architectural fix for the seam artifact.
//   BarWindow       - Overlay, top strip, Island morphing surface.
//   OverlayWindow   - Overlay, full-screen, notifications/OSD/auth.
//
// Every surface is mounted once and simply reacts to UiState / service
// properties — there is no polling anywhere in this file either.
ShellRoot {
    id: shellRoot

    // Do not delete this as unused. Keybinds is a `pragma Singleton`, and
    // this reference is the only thing in the tree that instantiates it. It
    // looks like a plain alias because nothing reads it, but constructing the
    // singleton is what registers its IpcHandlers -- and those are the shell's
    // entire control surface, `shell` and `uis`. Removing this line loads the
    // config cleanly, logs nothing, and leaves every surface unreachable.
    property var keybinds: Keybinds

    // ---- Wallpaper: Background layer with macOS-like crossfade ----
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

            // Base outgoing wallpaper
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

            // Base incoming wallpaper
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

            // Circle Out / Radial Wipe — proper circular reveal using MultiEffect + mask
            // circleMaskItem is a growing rounded-rectangle rendered off-screen;
            // wallpaperCircle uses it as a mask source through MultiEffect.
            Item {
                id: circleWipeContainer
                anchors.fill: parent
                visible: wallWin.transitionStyle === "circleOut" && wallWin.isTransitioning

                // Old wallpaper underneath
                Image {
                    anchors.fill: parent
                    source: Theme.wallpaperFrom
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                // Circle mask — grows from 0 to cover the full diagonal
                Item {
                    id: circleMaskItem
                    anchors.fill: parent
                    visible: false  // rendered only as mask source

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

                // New wallpaper revealed through the growing circle mask
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

            // Fallback solid color while wallpapers load or if none
            Rectangle {
                anchors.fill: parent
                color: Theme.colors.background
                opacity: (Theme.wallpaperFrom === "" && Theme.wallpaperTo === "") ? 0.3 : 0
                Behavior on color { ColorAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                z: -1
            }
        }
    }

    // ---- Backdrop scrim: WlrLayer.Top — dedicated window BELOW Overlay ----
    // The Island lives on WlrLayer.Overlay; this window on WlrLayer.Top.
    // Compositors render Top below Overlay, so the Island always paints
    // cleanly above the scrim — zero mask-subtraction, zero seam artifacts.
    // Clicking the scrim dismisses the open surface.
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
            // Pass through pointer events when no popup is open
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

    // ---- Island / Bar: Overlay layer ----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            // Keep exclusiveZone at collapsed pill height so tiled windows
            // don't jump when island expands — expanded island overlays,
            // like macOS Dynamic Island.
            exclusiveZone: island.barHeight + (island.notchMode ? 0 : island.gapFromEdge)
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-bar"
            focusable: Auth.pending === null && UiState.anyOpen
            WlrLayershell.keyboardFocus: Auth.pending !== null ? WlrKeyboardFocus.None : (UiState.anyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None)

            // Settings is a full-height panel: the reference measures it
            // 1346x971 sitting at y 75..1045. The generic 700 for "any
            // surface open" clipped it, so settings gets its own height --
            // 75 (its top offset) + 971 (its height).
            implicitHeight: UiState.settingsOpen ? 1045
                : (UiState.anyOpen ? 700 : (island.barHeight + (island.notchMode ? 0 : island.gapFromEdge) + 16))

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
                opacity: barWindow.isFullscreen ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
            }
        }
    }

    // ---- Overlay: Notifications, OSD, Auth ----
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
                // No OSD region: the OSD lives in the island's own window now,
                // so this overlay has nothing to punch through for it.
                Region { item: Auth.pending !== null ? authWrap : null }
            }

            // ---- Notifications: top-right stack ----
            Item {
                id: notifWrap
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                width: stack.width
                height: stack.implicitHeight

                NotificationStack { id: stack }
            }

            // The volume/brightness OSD is NOT here. It is the island's
            // centre notch morphed into a 275x43 bar -- see OSD.qml and
            // centerNotchWrap in Island.qml. It used to be a window in this
            // overlay, which put it on a different layer from the bar, so the
            // bar's clock drew over it and it could not occlude the island
            // the way 2026-09-20_22-28-44.png shows.

            // ---- Auth prompt: full-window scrim + centered dialog ----
            Item {
                id: authWrap
                anchors.fill: parent
                visible: Auth.pending !== null

                AuthOverlay {}
            }
        }
    }
}
