import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "settings"
        title: "System"
        subtitle: "Theme, battery, power profile, and session actions."
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 10

            Icon { icon: "palette"; size: 18; iconColor: Theme.withAlpha(Theme.colors.text, 0.7) }
            Label {
                Layout.fillWidth: true
                text: "Theme"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
            }
            Label {
                text: Theme.displayName
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.5)
                elide: Text.ElideRight
                Layout.maximumWidth: 260
            }
        }

        SettingsDivider {}

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 10

            Icon {
                icon: Battery.charging ? "battery_charging_full" : "battery_std"
                size: 18
                iconColor: Theme.withAlpha(Theme.colors.text, 0.7)
            }
            Label {
                Layout.fillWidth: true
                text: "Battery"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
            }
            Label {
                text: Battery.available
                    ? Battery.percentage + "%" + (Battery.charging ? " — Charging" : "")
                    : "No battery"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.5)
            }
        }

        SettingsDivider { visible: PowerProfile.available }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: PowerProfile.available
            spacing: 10

            Icon { icon: "speed"; size: 18; iconColor: Theme.withAlpha(Theme.colors.text, 0.7) }
            Label {
                Layout.fillWidth: true
                text: "Power profile"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
            }
            Label {
                text: PowerProfile.active
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.5)
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
                onClicked: Power.lock()
            }
            StyledButton {
                Layout.fillWidth: true
                label: "Suspend"
                onClicked: Power.suspend()
            }
            StyledButton {
                Layout.fillWidth: true
                label: "Power menu"
                filled: true
                onClicked: UiState.togglePowerMenu()
            }
        }
    }
}
