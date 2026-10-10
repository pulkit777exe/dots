import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["power", "battery", "charging",
        "profile", "performance", "balanced", "saver", "game mode",
        "lock", "suspend", "sleep", "lid"]

    SettingsHeader {
        icon: "power_settings_new"
        title: "Power"
        subtitle: "Battery, performance profile, and session actions."
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: Battery.charging ? Theme.accentFor("settings")
                    : Theme.withAlpha(Theme.colors.text, 0.12)

                Icon {
                    anchors.centerIn: parent
                    icon: Battery.charging ? "battery_charging_full" : "battery_std"
                    size: 15
                    iconColor: Battery.charging ? Theme.colors.accentText
                        : Theme.withAlpha(Theme.colors.text, 0.85)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: Battery.available ? Battery.percentage + "%" : "No battery"
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.Medium
                    color: Theme.colors.text
                }
                Label {
                    text: Battery.charging ? "Charging" : "On battery"
                    font.pixelSize: Theme.px(11)
                    color: Theme.withAlpha(Theme.colors.text, 0.48)
                }
            }
        }
    }

    SettingsCard {
        visible: PowerProfile.available

        SettingsLabelRow { label: "Performance profile" }

        Repeater {
            model: ["power-saver", "balanced", "performance"]

            Rectangle {
                required property string modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.topMargin: index > 0 ? 5 : 0
                radius: 12
                color: rowArea.containsMouse ? Theme.cc.itemHover : Theme.cc.item
                border.color: PowerProfile.active === modelData
                    ? Theme.accentFor("settings") : Theme.cc.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Config.hover() } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Label {
                        Layout.fillWidth: true
                        text: modelData === "power-saver" ? "Power saver"
                            : (modelData === "balanced" ? "Balanced" : "Performance")
                        font.pixelSize: Theme.px(13)
                        color: Theme.colors.text
                    }
                    Icon {
                        visible: PowerProfile.active === modelData
                        icon: "check"
                        size: 14
                        iconColor: Theme.accentFor("settings")
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProfile.setProfile(modelData)
                }
            }
        }
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledButton {
                Layout.fillWidth: true
                label: "Lock"
                accent: Theme.accentFor("settings")
                onClicked: Power.lock()
            }
            StyledButton {
                Layout.fillWidth: true
                label: "Suspend"
                accent: Theme.accentFor("settings")
                onClicked: Power.suspend()
            }
        }
    }
}
