import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

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
        SettingsLabelRow { label: "Charge limit" }

        Label {
            Layout.fillWidth: true
            text: "Stop charging at the limit to slow battery wear. 100% means no limit; some firmware forgets it on reboot."
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
            wrapMode: Text.WordWrap
        }

        SettingsSliderRow {
            value: ChargeLimit.limit
            from: 50
            to: 100
            suffix: "%"
            onMoved: (v) => ChargeLimit.setLimit(v)
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

        SettingsSliderRow {
            label: "Lock screen"
            value: Config.lockTimeoutSec
            from: 0
            to: 1800
            textOverride: Idle.formatTimeout(Config.lockTimeoutSec)
            onMoved: (v) => { Config.set("lockTimeoutSec", Math.round(v)); Idle.apply(); }
        }

        SettingsSliderRow {
            label: "Display off"
            value: Config.displayTimeoutSec
            from: 0
            to: 1800
            textOverride: Idle.formatTimeout(Config.displayTimeoutSec)
            onMoved: (v) => { Config.set("displayTimeoutSec", Math.round(v)); Idle.apply(); }
        }

        SettingsSliderRow {
            label: "Suspend"
            value: Config.suspendTimeoutSec
            from: 0
            to: 1800
            textOverride: Idle.formatTimeout(Config.suspendTimeoutSec)
            onMoved: (v) => { Config.set("suspendTimeoutSec", Math.round(v)); Idle.apply(); }
        }

        SettingsToggleRow {
            label: "Different timers while charging"
            checked: Config.idleSeparateCharging
            onToggled: (v) => { Config.set("idleSeparateCharging", v); Idle.apply(); }
        }

        SettingsSliderRow {
            visible: Config.idleSeparateCharging
            label: "Lock screen (charging)"
            value: Config.cLockTimeoutSec
            from: 0
            to: 1800
            textOverride: Idle.formatTimeout(Config.cLockTimeoutSec)
            onMoved: (v) => { Config.set("cLockTimeoutSec", Math.round(v)); Idle.apply(); }
        }

        SettingsSliderRow {
            visible: Config.idleSeparateCharging
            label: "Display off (charging)"
            value: Config.cDisplayTimeoutSec
            from: 0
            to: 1800
            textOverride: Idle.formatTimeout(Config.cDisplayTimeoutSec)
            onMoved: (v) => { Config.set("cDisplayTimeoutSec", Math.round(v)); Idle.apply(); }
        }

        SettingsSliderRow {
            visible: Config.idleSeparateCharging
            label: "Suspend (charging)"
            value: Config.cSuspendTimeoutSec
            from: 0
            to: 1800
            textOverride: Idle.formatTimeout(Config.cSuspendTimeoutSec)
            onMoved: (v) => { Config.set("cSuspendTimeoutSec", Math.round(v)); Idle.apply(); }
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
