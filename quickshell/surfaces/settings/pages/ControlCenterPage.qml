import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"
ColumnLayout {
    id: root
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 28
            color: Qt.rgba(1, 1, 1, 0.06)
            Icon { anchors.centerIn: parent; icon: "tune"; size: 22; iconColor: Theme.colors.accent }
        }
        ColumnLayout {
            spacing: 2
            StyledText { variant: "mediaTitle"; font.pixelSize: 17; text: "Control Center" }
            StyledText {
                variant: "mediaSubtitle"
                text: "Status pills, slider behaviors, quick actions, and connectivity."
            }
        }
    }

    // Connectivity Status Cards
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Surface {
            Layout.fillWidth: true
            implicitHeight: 70
            cornerRadius: 14
            backgroundColor: Theme.colors.surface

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Icon { icon: "wifi"; size: 22; iconColor: Wifi.connected ? Theme.colors.accent : Qt.rgba(1,1,1,0.4) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText { font.pixelSize: 13; font.weight: Font.DemiBold; text: "Wi-Fi" }
                    StyledText { font.pixelSize: 11; textColor: Qt.rgba(1,1,1,0.6); text: Wifi.connected ? (Wifi.ssid || "Connected") : "Disconnected" }
                }
            }
        }

        Surface {
            Layout.fillWidth: true
            implicitHeight: 70
            cornerRadius: 14
            backgroundColor: Theme.colors.surface

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Icon { icon: "bluetooth"; size: 22; iconColor: Bluetooth.enabled ? Theme.colors.accent : Qt.rgba(1,1,1,0.4) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText { font.pixelSize: 13; font.weight: Font.DemiBold; text: "Bluetooth" }
                    StyledText { font.pixelSize: 11; textColor: Qt.rgba(1,1,1,0.6); text: Bluetooth.enabled ? (Bluetooth.connectedDevices.length > 0 ? Bluetooth.connectedDevices[0].name : "On") : "Off" }
                }
            }
        }
    }

    // Quick Toggles
    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Idle Keep-Awake Inhibitor" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: IdleInhibit.active
            accentColor: Theme.colors.accent
            onToggled: IdleInhibit.toggle()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Night Light Screen Warmth" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: NightLight.enabled
            accentColor: Theme.colors.accent
            onToggled: NightLight.toggle()
        }
    }
}
