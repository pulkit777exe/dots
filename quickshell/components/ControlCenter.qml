import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"
import "ui"
import "panels"

/**
 * Image 2: the expanded Control Center.
 * Toggle grid (2 rows: WiFi+Audio, BT+Peace+NightLight) + sliders + media scrubber
 * + persistent notification list. Sub-panels pushed via IslandState.
 */
Rectangle {
    id: root
    width: 360
    implicitHeight: col.implicitHeight + 24
    radius: 24
    color: Theme.colors.surface
    border.width: 1
    border.color: Qt.lighter(Theme.colors.surface, 1.3)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: IslandState.onExpandedHoverEntered()
        onExited: IslandState.onExpandedHoverExited()
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // -- Header: back arrow + panel name when a panel is pushed,
        // otherwise the Control Center title + settings/power shortcuts.
        // Settings and Power were previously unreachable from this view --
        // nothing called pushPanel("settings") or pushPanel("power")
        // anywhere, even though the Loader below always knew how to render
        // them once pushed. --
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                visible: IslandState.currentPanel !== null
                text: Config.iconBack
                color: Theme.colors.text
                font.family: Config.iconFontFamily
                font.pixelSize: Theme.fontSize + 4
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: IslandState.popPanel() }
            }
            Text {
                text: IslandState.currentPanel !== null
                    ? (IslandState.currentPanel ?? "")
                    : "Control Center"
                color: Theme.colors.text
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                visible: IslandState.currentPanel === null
                text: Config.iconSettings
                color: Theme.colors.textMuted
                font.family: Config.iconFontFamily
                font.pixelSize: Theme.fontSize + 2
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: IslandState.pushPanel("settings") }
            }
            Text {
                visible: IslandState.currentPanel === null
                text: Config.iconPower
                color: Theme.colors.textMuted
                font.family: Config.iconFontFamily
                font.pixelSize: Theme.fontSize + 2
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: IslandState.pushPanel("power") }
            }
        }

        // -- Sub-panel view --
        Loader {
            Layout.fillWidth: true
            active: IslandState.currentPanel !== null
            visible: active
            sourceComponent: {
                switch (IslandState.currentPanel) {
                    case "wifi": return wifiPanelComp
                    case "bluetooth": return bluetoothPanelComp
                    case "audio": return audioPanelComp
                    case "settings": return settingsComp
                    case "theme": return themePickerComp
                    case "wallpaper": return wallpaperPickerComp
                    case "power": return powerMenuComp
                    default: return null
                }
            }
        }

        // -- Default view: toggle grid + sliders + media + notifications --
        ColumnLayout {
            visible: IslandState.currentPanel === null
            Layout.fillWidth: true
            spacing: 10

            // Battery status header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Config.batteryIcon(UPowerService.percentage, UPowerService.charging)
                    color: UPowerService.low ? Theme.colors.danger : Theme.colors.accent
                    font.family: Config.iconFontFamily
                    font.pixelSize: Theme.fontSize + 2
                }

                // Battery fill bar
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 14

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.colors.surfaceHover

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            radius: 2
                            width: Math.max(0, (parent.width - 4) * (UPowerService.percentage / 100.0))
                            color: UPowerService.low ? Theme.colors.danger
                                 : UPowerService.percentage <= 20 ? Theme.colors.warning
                                 : Theme.colors.success

                            Behavior on width {
                                NumberAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    // Battery nub
                    Rectangle {
                        width: 2
                        height: 6
                        radius: 1
                        color: Theme.colors.surfaceHover
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: UPowerService.percentage + "%"
                    color: UPowerService.low ? Theme.colors.danger : Theme.colors.text
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: true
                    visible: UPowerService.available
                }
            }

            // Row 1: WiFi + Audio (2 items, ~50% each)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ToggleRow {
                    Layout.fillWidth: true
                    label: "Wi-Fi"
                    sublabel: NetworkService.activeSsid || "Off"
                    icon: Config.iconWifi
                    active: NetworkService.wifiEnabled
                    onTap: IslandState.pushPanel("wifi")
                }
                ToggleRow {
                    Layout.fillWidth: true
                    label: "Audio"
                    sublabel: AudioService.muted ? "Muted" : (AudioService.activeOutputName || (AudioService.volume + "%"))
                    icon: Config.iconVolHigh
                    active: !AudioService.muted
                    onTap: IslandState.pushPanel("audio")
                }
            }

            // Row 2: Bluetooth + Peace + Night Light (3 items)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ToggleRow {
                    Layout.fillWidth: true
                    label: "Bluetooth"
                    sublabel: BluetoothService.enabled ? "On" : "Off"
                    icon: Config.iconBtOn
                    active: BluetoothService.enabled
                    onTap: IslandState.pushPanel("bluetooth")
                }
                ToggleRow {
                    Layout.fillWidth: true
                    label: "Peace"
                    sublabel: PeaceService.dndEnabled ? "On" : "Off"
                    icon: Config.iconPeace
                    active: PeaceService.dndEnabled
                    onTap: PeaceService.toggle()
                }
                ToggleRow {
                    Layout.fillWidth: true
                    label: "Night Light"
                    sublabel: NightLightService.enabled ? "On" : "Off"
                    icon: Config.iconNightLight
                    active: NightLightService.enabled
                    onTap: NightLightService.toggle()
                }
            }

            // Volume slider (no label)
            Slider01 {
                Layout.fillWidth: true
                value: AudioService.volume / 100
                onMoved: (v) => AudioService.setVolume(Math.round(v * 100))
            }

            // Brightness slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: Config.iconBright
                    color: Theme.colors.accent
                    font.family: Config.iconFontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
                Slider01 {
                    Layout.fillWidth: true
                    value: BrightnessService.brightness / 100
                    onMoved: (v) => BrightnessService.setBrightness(Math.round(v * 100))
                }
            }

            // Media card
            MediaCard {
                Layout.fillWidth: true
                visible: MprisService.playbackStatus !== "Stopped"
            }

            // Notifications header
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Notifications"; color: Theme.colors.text; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true }
                Text {
                    text: "Clear all"
                    color: Theme.colors.accent
                    font.pixelSize: Theme.fontSize - 2
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: NotificationService.clearAll() }
                }
            }

            // Notification list
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(240, contentHeight)
                model: NotificationService.items
                spacing: 6
                clip: true
                delegate: NotificationRow { width: ListView.view.width; entry: modelData }
            }
        }
    }

    Component { id: wifiPanelComp; WifiPanel {} }
    Component { id: bluetoothPanelComp; BluetoothPanel {} }
    Component { id: audioPanelComp; AudioPanel {} }
    Component { id: settingsComp; Settings {} }
    Component { id: themePickerComp; ThemePicker {} }
    Component { id: wallpaperPickerComp; WallpaperPicker {} }
    Component { id: powerMenuComp; PowerMenu {} }
}
