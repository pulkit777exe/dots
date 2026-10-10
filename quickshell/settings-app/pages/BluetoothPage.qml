import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"
import "../../surfaces/cc"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["bluetooth", "bt", "pair", "pairing",
        "connect", "disconnect", "device", "headphones", "audio", "nearby", "saved"]

    SettingsHeader {
        icon: "bluetooth"
        title: "Bluetooth"
        subtitle: "Radios, paired gear, and nearby devices."
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: "Bluetooth"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
            }
            Toggle {
                checked: Bluetooth.enabled
                accent: Theme.accentFor("settings")
                onToggled: { Bluetooth.toggle(); Bluetooth.scan(); }
            }
        }

        SettingsDivider { visible: Bluetooth.devices.some(d => d.connected) }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Bluetooth.devices.some(d => d.connected)

            SettingsLabelRow { label: "Connected" }
            Repeater {
                model: Bluetooth.devices.filter(d => d.connected)
                CcBtRow {
                    required property var modelData
                    Layout.fillWidth: true
                    device: modelData
                    onAction: modelData.connected
                        ? Bluetooth.disconnectDevice(modelData.mac)
                        : Bluetooth.connectDevice(modelData.mac)
                }
            }
        }

        SettingsDivider { visible: Bluetooth.devices.some(d => d.paired && !d.connected) }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Bluetooth.devices.some(d => d.paired && !d.connected)

            SettingsLabelRow { label: "Saved" }
            Repeater {
                model: Bluetooth.devices.filter(d => d.paired && !d.connected)
                CcBtRow {
                    required property var modelData
                    Layout.fillWidth: true
                    device: modelData
                    onAction: Bluetooth.connectDevice(modelData.mac)
                }
            }
        }
    }

    SettingsCard {
        visible: Bluetooth.enabled

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: "Nearby"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }
            StyledButton {
                label: Bluetooth.scanning ? "Scanning…" : "Scan"
                onClicked: Bluetooth.scan()
            }
        }

        Item { Layout.preferredHeight: 6; Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Bluetooth.nearbyDevices
                CcBtRow {
                    required property var modelData
                    Layout.fillWidth: true
                    device: modelData
                    onAction: Bluetooth.pair(modelData.mac)
                }
            }

            Label {
                Layout.fillWidth: true
                visible: Bluetooth.nearbyDevices.length === 0 && !Bluetooth.scanning
                horizontalAlignment: Text.AlignHCenter
                text: "No devices found"
                font.pixelSize: Theme.px(12)
                color: Theme.withAlpha(Theme.colors.text, 0.4)
            }
        }
    }
}
