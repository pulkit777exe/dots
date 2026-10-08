import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.surfaces
import qs.modules

// Five window kinds, one per screen:
//   wallpaper   background layer, draws the active wallpaper
//   backdrop    top layer, dims and click-closes whatever popup is open
//   bar         overlay layer, holds the island and every bar popup
//   settings    top layer, the settings app as its own desktop window
//   overlay     overlay layer, notification toasts + the volume/brightness OSD
//
// The bar window sizes itself from what is actually on screen -- the
// island's own box, plus any visible popup -- so a panel can be any height
// and never gets clipped by the window it lives in. Settings does not take
// part: it lives in its own window, centred over the desktop.

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
            // -1: don't get pushed down by the bar's reserved strip -- a
            // full-screen surface must cover the full screen (otherwise the
            // top 40px fall through to hyprpaper and the wallpaper seams).
            exclusiveZone: -1
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
            exclusiveZone: -1
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-backdrop"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region { item: UiState.popupOpen ? backdropClickTarget : null }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.30)
                opacity: UiState.popupOpen ? 1 : 0
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
            focusable: UiState.popupOpen
            WlrLayershell.keyboardFocus: UiState.popupOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property var popups: [cc, themePicker, wallpaperPicker, powerMenu, launcher]
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
                Region { item: launcher.visible ? launcher : null }
            }

            HyprlandFocusGrab { active: UiState.popupOpen; windows: [barWindow] }

            Island {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                y: barWindow.topY
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
        }
    }

    // ---- settings window ---------------------------------------------------
    // The settings app gets a window of its own instead of hanging off the
    // bar: centred over the desktop, no backdrop dim, the island left alone
    // behind it. It is still plain UiState state, so Super+S, the IPC toggle
    // and Escape behave exactly as they did when it was a popup.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: settingsWindow
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-settings"

            focusable: UiState.settingsOpen
            WlrLayershell.keyboardFocus: UiState.settingsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            HyprlandFocusGrab { active: UiState.settingsOpen; windows: [settingsWindow] }

            // Only the panel takes pointer input; the desktop around a
            // window should stay clickable, like any other app.
            mask: Region { item: settings.visible ? settings : null }

            SettingsApp {
                id: settings
                anchors.horizontalCenter: parent.horizontalCenter
                // Vertically centred like a desktop window, but never
                // above the island strip so the bar stays visible.
                topY: Math.max(76, (settingsWindow.height - settings.height) / 2)
                maxHeight: settingsWindow.height - 92
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

            // Bottom-centre, deliberately outside the mask above: the OSD
            // is feedback only and must never intercept input.
            Osd {
                id: osd
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 56
            }
        }
    }
}
