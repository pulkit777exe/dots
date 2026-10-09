import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.surfaces
import qs.modules

ShellRoot {
    id: shellRoot

    property var keybinds: Keybinds

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
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

            readonly property var popups: [cc, themePicker, wallpaperPicker, powerMenu, launcher, clipboardPicker]
            readonly property bool isFullscreen: Compositor.activeWindowFullscreen && !UiState.anyOpen
            readonly property real topY: Config.notchMode ? 0 : Config.gapFromEdge

            implicitHeight: {
                let bottom = island.y + island.height;
                for (const p of barWindow.popups)
                    if (p.visible) bottom = Math.max(bottom, p.y + p.height);
                return bottom + 16;
            }

            exclusiveZone: (barWindow.isFullscreen && island.hidden)
                ? 0
                : (Config.barHeight + (Config.notchMode ? 0 : Config.gapFromEdge));

            mask: Region {
                Region { item: island.visible ? island : null }
                Region { item: cc.visible ? cc : null }
                Region { item: themePicker.visible ? themePicker : null }
                Region { item: wallpaperPicker.visible ? wallpaperPicker : null }
                Region { item: powerMenu.visible ? powerMenu : null }
                Region { item: launcher.visible ? launcher : null }
                Region { item: clipboardPicker.visible ? clipboardPicker : null }
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

            ClipboardPicker {
                id: clipboardPicker
                anchors.horizontalCenter: parent.horizontalCenter
                topY: barWindow.topY
            }
        }
    }

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

            mask: Region { item: settings.visible ? settings : null }

            SettingsApp {
                id: settings
                anchors.horizontalCenter: parent.horizontalCenter
                topY: Math.max(76, (settingsWindow.height - settings.height) / 2)
                maxHeight: settingsWindow.height - 92
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

            Osd {
                id: osd
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 56
            }
        }
    }
}
