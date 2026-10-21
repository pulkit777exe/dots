import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["network", "wifi", "wi-fi", "wireless",
        "internet", "ssid", "password", "connect", "disconnect", "signal"]

    property string pendingSsid: ""

    SettingsHeader {
        icon: "wifi"
        title: "Network"
        subtitle: "Wi-Fi networks and connection."
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: "Wi-Fi"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
            }
            Toggle {
                checked: Wifi.enabled
                accent: Theme.accentFor("settings")
                onToggled: Wifi.toggle()
            }
        }

        SettingsDivider { visible: Wifi.connected }

        RowLayout {
            Layout.fillWidth: true
            visible: Wifi.connected
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: Wifi.ssid + " · " + Wifi.strength + "%"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
                elide: Text.ElideRight
            }
            StyledButton {
                label: "Disconnect"
                onClicked: Wifi.disconnect()
            }
        }
    }

    SettingsCard {
        visible: Wifi.enabled

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: "Networks"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }
            StyledButton {
                label: Wifi.busy ? "Scanning…" : "Scan"
                onClicked: Wifi.scan()
            }
        }

        Item { Layout.preferredHeight: 6; Layout.fillWidth: true }

        component NetRow: ColumnLayout {
            id: net

            required property var modelData

            property bool expanded: root.pendingSsid !== "" && root.pendingSsid === modelData.ssid
            property bool connected: !!modelData.active

            spacing: 0
            Layout.fillWidth: true

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 12
                color: netArea.containsMouse ? Theme.cc.itemHover : Theme.cc.item
                border.color: net.connected ? Theme.accentFor("settings") : Theme.cc.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Config.hover() } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Icon {
                        icon: modelData.signal >= 75 ? "wifi"
                            : (modelData.signal >= 40 ? "wifi_2_bar" : "wifi_1_bar")
                        size: 16
                        iconColor: Theme.withAlpha(Theme.colors.text, 0.70)
                    }
                    Label {
                        Layout.fillWidth: true
                        text: modelData.ssid
                        font.pixelSize: Theme.px(13)
                        color: Theme.colors.text
                        elide: Text.ElideRight
                    }
                    Icon {
                        visible: modelData.secured
                        icon: "lock"
                        size: 13
                        iconColor: Theme.withAlpha(Theme.colors.text, 0.42)
                    }
                    Label {
                        text: modelData.signal + "%"
                        font.pixelSize: Theme.px(11)
                        color: Theme.withAlpha(Theme.colors.text, 0.55)
                    }
                }

                MouseArea {
                    id: netArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (net.connected) return;
                        if (modelData.secured)
                            root.pendingSsid = net.expanded ? "" : modelData.ssid;
                        else
                            Wifi.connect(modelData.ssid, "");
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: net.expanded ? 52 : 0
                Layout.topMargin: net.expanded ? 6 : 0
                visible: net.expanded
                clip: true
                radius: 12
                color: Theme.cc.item
                border.color: Theme.cc.border
                border.width: 1

                Behavior on Layout.preferredHeight {
                    enabled: !Config.reduceMotion
                    NumberAnimation { duration: Config.movement(0.35); easing.type: Easing.OutQuint }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30

                        TextInput {
                            id: pwInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            color: Theme.colors.text
                            echoMode: TextInput.Password
                            onAccepted: joinBtn.clicked()
                        }
                        Label {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: pwInput.text.length === 0
                            text: "Password"
                            font.pixelSize: Theme.px(13)
                            color: Theme.withAlpha(Theme.colors.text, 0.35)
                        }
                    }
                    StyledButton {
                        id: joinBtn
                        label: "Join"
                        accent: Theme.accentFor("settings")
                        onClicked: {
                            Wifi.connect(net.modelData.ssid, pwInput.text);
                            root.pendingSsid = "";
                        }
                    }
                }
            }
        }

        Repeater {
            model: Wifi.networks

            NetRow {}
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: Wifi.networks.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "No networks found"
            font.pixelSize: Theme.px(12)
            color: Theme.withAlpha(Theme.colors.text, 0.4)
        }
    }
}
