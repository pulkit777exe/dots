import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    property bool chargeEditing: false

    readonly property var searchKeys: ["power", "battery", "charging",
        "profile", "performance", "balanced", "saver", "game mode",
        "lock", "suspend", "sleep", "lid", "charge limit", "threshold",
        "battery health", "wear", "idle", "screen timeout", "lock screen",
        "dim", "display off", "never", "while charging", "on ac"]

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
                    font.weight: Font.DemiBold
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
        SettingsLabelRow { label: "Charge limit" }

        Label {
            Layout.fillWidth: true
            text: "Stop charging at the limit to slow battery wear. 100% means no limit; some firmware forgets it on reboot."
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
            wrapMode: Text.WordWrap
        }

        // Locked value: tap the pencil to edit.
        RowLayout {
            visible: !root.chargeEditing
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: ChargeLimit.limit + "%"
                font.pixelSize: Theme.px(20)
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }

            Label {
                Layout.fillWidth: true
                text: ChargeLimit.limit >= 100 ? "no limit" : "charging stops here"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }

            IconButton {
                icon: "edit"
                onClicked: {
                    chargeField.text = String(ChargeLimit.limit);
                    root.chargeEditing = true;
                    Qt.callLater(() => { chargeField.forceActiveFocus(); chargeField.selectAll(); });
                }
            }
        }

        // Edit mode: plain numeric input, Enter/✓ commits, Esc reverts.
        RowLayout {
            visible: root.chargeEditing
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 10
                color: Theme.withAlpha(Theme.colors.text, 0.07)
                border.color: chargeField.activeFocus
                    ? Theme.accentFor("settings")
                    : Theme.withAlpha(Theme.colors.text, 0.12)
                border.width: 1

                TextInput {
                    id: chargeField
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(14)
                    color: Theme.withAlpha(Theme.colors.text, 0.92)
                    selectionColor: Theme.withAlpha(Theme.colors.accent, 0.35)
                    validator: IntValidator { bottom: 40; top: 100 }
                    inputMethodHints: Qt.ImhDigitsOnly
                    clip: true

                    function commit() {
                        if (text.length > 0)
                            ChargeLimit.setLimit(parseInt(text, 10));
                        root.chargeEditing = false;
                    }

                    Keys.onReturnPressed: commit()
                    Keys.onEnterPressed: commit()
                    Keys.onEscapePressed: (event) => { root.chargeEditing = false; event.accepted = true; }
                }
            }

            Label {
                text: "%"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.5)
            }

            IconButton {
                icon: "check"
                iconSize: 18
                iconColor: Theme.accentFor("settings")
                onClicked: chargeField.commit()
            }

            IconButton {
                icon: "close"
                iconSize: 18
                onClicked: root.chargeEditing = false;
            }
        }

        Label {
            visible: !ChargeLimit.available
            Layout.fillWidth: true
            text: "Not supported on this battery — no charge-control node."
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
            wrapMode: Text.WordWrap
        }

        Label {
            visible: ChargeLimit.error.length > 0
            Layout.fillWidth: true
            text: ChargeLimit.error
            font.pixelSize: Theme.px(11)
            color: Theme.colors.warning
            wrapMode: Text.WordWrap
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
        SettingsLabelRow { label: "Screen idle" }

        Label {
            Layout.fillWidth: true
            text: "Lock, blank and suspend after inactivity. Off means never."
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: [
                { key: "lockTimeoutSec", label: "Lock screen" },
                { key: "displayTimeoutSec", label: "Display off" },
                { key: "suspendTimeoutSec", label: "Suspend" },
            ]

            delegate: SettingsSliderRow {
                required property var modelData
                label: modelData.label
                value: Config[modelData.key]
                from: 0
                to: 1800
                textOverride: Idle.formatTimeout(Config[modelData.key])
                onMoved: (v) => { Config.set(modelData.key, Math.round(v)); Idle.apply(); }
            }
        }

        SettingsToggleRow {
            label: "Different timers while charging"
            checked: Config.idleSeparateCharging
            onToggled: (v) => { Config.set("idleSeparateCharging", v); Idle.apply(); }
        }

        Repeater {
            model: [
                { key: "cLockTimeoutSec", label: "Lock screen (charging)" },
                { key: "cDisplayTimeoutSec", label: "Display off (charging)" },
                { key: "cSuspendTimeoutSec", label: "Suspend (charging)" },
            ]

            delegate: SettingsSliderRow {
                required property var modelData
                visible: Config.idleSeparateCharging
                label: modelData.label
                value: Config[modelData.key]
                from: 0
                to: 1800
                textOverride: Idle.formatTimeout(Config[modelData.key])
                onMoved: (v) => { Config.set(modelData.key, Math.round(v)); Idle.apply(); }
            }
        }

        Label {
            visible: Config.idleSeparateCharging
            Layout.fillWidth: true
            text: Battery.charging ? "On the charging timers now — unplug to switch back."
                : "On battery timers now — plug in to switch."
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        SessionActions {}
    }
}
