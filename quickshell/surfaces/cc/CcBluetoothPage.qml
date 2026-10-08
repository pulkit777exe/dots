import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

// Bluetooth drill page: connected, saved, then nearby devices.

CcPage {
    id: page

    CcHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        toggleVisible: true
        toggleOn: Bluetooth.enabled
        onBack: page.back()
        onToggled: { Bluetooth.toggle(); Bluetooth.scan(); }
    }

    Item { Layout.preferredHeight: 14; Layout.fillWidth: true }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: Bluetooth.devices.some(d => d.connected)

        Label {
            text: "Connected"
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
        }
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

    Item {
        Layout.preferredHeight: 12
        Layout.fillWidth: true
        visible: Bluetooth.devices.some(d => d.connected)
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: Bluetooth.devices.some(d => d.paired && !d.connected)

        Label {
            text: "Saved"
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
        }
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

    Item {
        Layout.preferredHeight: 12
        Layout.fillWidth: true
        visible: Bluetooth.devices.some(d => d.paired && !d.connected)
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: Bluetooth.enabled

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: "Nearby"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }
            RowLayout {
                spacing: 6
                visible: Bluetooth.scanning
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.accentFor("control-center")
                }
                Label { text: "Scanning"; font.pixelSize: Theme.px(11); color: Theme.withAlpha(Theme.colors.text, 0.55) }
            }
        }

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
            visible: Bluetooth.nearbyDevices.length === 0 && !Bluetooth.scanning
            text: "No devices found"
            font.pixelSize: Theme.px(12)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Item { Layout.preferredHeight: 4; Layout.fillWidth: true }
}
