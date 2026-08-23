import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"
import "../ui"

/** Image 6: paired device list, each with a "Connect" action. */
ColumnLayout {
    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: Config.iconBtOn
            color: Theme.colors.text
            font.pixelSize: Theme.fontSize
            font.family: Config.iconFontFamily
        }
        Text {
            text: "Bluetooth"
            color: Theme.colors.text
            font.pixelSize: Theme.fontSize - 1
            Layout.fillWidth: true
        }
        ToggleSwitch {
            checked: BluetoothService.enabled
            onToggled: BluetoothService.setEnabled(!BluetoothService.enabled)
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(220, contentHeight)
        model: BluetoothService.devices
        spacing: 4
        clip: true
        delegate: Rectangle {
            width: ListView.view.width
            height: 44
            radius: 10
            color: Theme.colors.surfaceHover

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text {
                    text: modelData.name
                    color: Theme.colors.text
                    font.pixelSize: Theme.fontSize - 1
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.connected ? "Connected" : "Connect"
                    color: Theme.colors.accent
                    font.pixelSize: Theme.fontSize - 3
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: if (!modelData.connected) BluetoothService.connectTo(modelData.mac)
                    }
                }
            }
        }
    }
}
