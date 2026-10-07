import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

// Wi-Fi drill page: the connected network, then every other AP in range.

Item {
    id: page

    signal back()

    readonly property real contentHeight: col.implicitHeight + 26   // 12 top, 14 bottom
    implicitHeight: contentHeight

    ColumnLayout {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 12
        spacing: 0

        CcHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            toggleVisible: true
            toggleOn: Wifi.enabled
            onBack: page.back()
            onToggled: Wifi.toggle()
        }

        Item { Layout.preferredHeight: 14; Layout.fillWidth: true }

        Rectangle {                          // connected card
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 13
            color: Theme.cc.item
            border.color: Theme.colors.accent
            border.width: 1
            visible: Wifi.connected

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: width / 2
                    color: Theme.colors.accent

                    Icon {
                        anchors.centerIn: parent
                        icon: Wifi.iconName
                        size: 20
                        iconColor: Theme.colors.accentText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        Layout.fillWidth: true
                        text: Wifi.ssid
                        font.pixelSize: Theme.px(13)
                        font.weight: Font.DemiBold
                        color: Theme.colors.text
                        elide: Text.ElideRight
                    }
                    Label {
                        text: "Connected · " + Wifi.strength + "% signal"
                        font.pixelSize: Theme.px(11)
                        color: Theme.withAlpha(Theme.colors.text, 0.48)
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: disconnectLabel.implicitWidth + 24
                    radius: height / 2
                    color: "transparent"
                    border.color: Theme.cc.border
                    border.width: 1

                    Label {
                        id: disconnectLabel
                        anchors.centerIn: parent
                        text: "Disconnect"
                        font.pixelSize: Theme.px(11)
                        color: Theme.colors.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wifi.disconnect()
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 14; Layout.fillWidth: true; visible: Wifi.connected }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                text: "Networks"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
                Layout.fillWidth: true
            }
            RowLayout {
                spacing: 6
                visible: Wifi.busy
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.colors.accent
                }
                Label { text: "Scanning"; font.pixelSize: Theme.px(11); color: Theme.withAlpha(Theme.colors.text, 0.48) }
            }
        }

        Item { Layout.preferredHeight: 6; Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Wifi.networks.filter(n => !n.active)

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 48
                    radius: 12
                    color: netArea.containsMouse ? Theme.cc.itemHover : Theme.cc.item
                    border.color: Theme.cc.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Config.hover() } }

                    // Secured networks go through the same call: nmcli uses a
                    // saved password when it has one.
                    MouseArea {
                        id: netArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wifi.connect(modelData.ssid, "")
                    }

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
                }
            }
        }
    }
}
