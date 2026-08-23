import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"
import "../ui"

/** Image 7: Wi-Fi list with connected network checked + signal %. */
ColumnLayout {
    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: Config.iconWifi
            color: Theme.colors.text
            font.pixelSize: Theme.fontSize
            font.family: Config.iconFontFamily
        }
        Text {
            text: "Wi-Fi"
            color: Theme.colors.text
            font.pixelSize: Theme.fontSize - 1
            Layout.fillWidth: true
        }
        ToggleSwitch {
            checked: NetworkService.wifiEnabled
            onToggled: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(220, contentHeight)
        model: NetworkService.networks
        spacing: 4
        clip: true
        delegate: Rectangle {
            width: ListView.view.width
            height: 44
            radius: 10
            color: modelData.connected ? Theme.colors.accent : Theme.colors.surfaceHover

            MouseArea {
                anchors.fill: parent
                onClicked: NetworkService.connectTo(modelData.ssid)
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text {
                    text: modelData.ssid
                    color: modelData.connected ? Theme.colors.bg : Theme.colors.text
                    font.pixelSize: Theme.fontSize - 1
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    visible: modelData.connected
                    text: "\u2713 " + modelData.signal + "%"
                    color: Theme.colors.bg
                    font.pixelSize: Theme.fontSize - 3
                }
                Text {
                    visible: !modelData.connected
                    text: modelData.signal + "%"
                    color: Theme.colors.textMuted
                    font.pixelSize: Theme.fontSize - 3
                }
            }
        }
    }
}
