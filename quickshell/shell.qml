import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.surfaces
import qs.modules

// Four window kinds, one per screen:
//   wallpaper   background layer, draws the active wallpaper
//   backdrop    top layer, dims and click-closes whatever is open
//   bar         overlay layer, holds the island and every popup
//   overlay     overlay layer, holds notification toasts
//
// The bar window sizes itself from what is actually on screen -- the
// island's own box, plus any visible popup -- so a panel can be any height
// and never gets clipped by the window it lives in.

ShellRoot {
    id: shellRoot

    // Only reference to Keybinds in the tree: it is a singleton, and this
    // line is what constructs it, which is what registers the IPC handlers
    // and global shortcuts. Delete it and every overlay is unreachable.
    property var keybinds: Keybinds

    // ---- wallpaper --------------------------------------------------------
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "black"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-wallpaper"

            Image {
                anchors.fill: parent
                source: Theme.currentWallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
            }
        }
    }

    // ---- backdrop ---------------------------------------------------------
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
                    NumberAnimation { duration: Config.fade(1.4); easing.type: Easing.OutCubic }
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

    // ---- bar + popups ------------------------------------------------------
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
            focusable: UiState.anyOpen
            WlrLayershell.keyboardFocus: UiState.anyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property var popups: [cc, themePicker, wallpaperPicker, powerMenu, settings, launcher]
            readonly property bool isFullscreen: Compositor.activeWindowFullscreen && !UiState.anyOpen
            readonly property real topY: Config.notchMode ? 0 : Config.gapFromEdge

            implicitHeight: {
                let bottom = island.y + island.height;
                for (const p of barWindow.popups)
                    if (p.visible) bottom = Math.max(bottom, p.y + p.height);
                return bottom + 16;
            }

            // Reserve the bar's strip normally; give it back over plain
            // fullscreen so maximised windows reach the screen edge.
            exclusiveZone: (barWindow.isFullscreen && island.hidden)
                ? 0
                : (Config.barHeight + (Config.notchMode ? 0 : Config.gapFromEdge));

            // Only the panels take pointer input; the rest of this tall
            // window is click-through.
            mask: Region {
                Region { item: island.visible ? island : null }
                Region { item: cc.visible ? cc : null }
                Region { item: themePicker.visible ? themePicker : null }
                Region { item: wallpaperPicker.visible ? wallpaperPicker : null }
                Region { item: powerMenu.visible ? powerMenu : null }
                Region { item: settings.visible ? settings : null }
                Region { item: launcher.visible ? launcher : null }
            }

            HyprlandFocusGrab { active: UiState.anyOpen; windows: [barWindow] }

            Island {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                y: barWindow.topY
                screenName: barWindow.screen ? barWindow.screen.name : ""
            }

            ControlCenter {
                id: cc
                anchors.horizontalCenter: parent.horizontalCenter
                topY: barWindow.topY
            }

            Launcher {
                id: launcher
                anchors.horizontalCenter: parent.horizontalCenter
                topY: barWindow.topY
            }

            ThemePicker {
                id: themePicker
                anchors.horizontalCenter: parent.horizontalCenter
                topY: barWindow.topY
            }

            WallpaperPicker {
                id: wallpaperPicker
                anchors.horizontalCenter: parent.horizontalCenter
                topY: barWindow.topY
            }

            PowerMenu {
                id: powerMenu
                anchors.horizontalCenter: parent.horizontalCenter
                topY: barWindow.topY
            }

            SettingsApp {
                id: settings
                anchors.horizontalCenter: parent.horizontalCenter
                topY: 76
            }
        }
    }

    // ---- notification toasts ------------------------------------------------
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-overlay"

            mask: Region { Region { item: notifWrap.visible ? notifWrap : null } }

            Item {
                id: notifWrap
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                width: stack.width
                height: stack.implicitHeight
                visible: stack.implicitHeight > 0

                NotificationStack { id: stack }
            }
        }
    }
}
