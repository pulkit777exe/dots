import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// The power pane: what the machine can do about power, and what it is doing now.
//
// Two sections, and they are different kinds of thing. "Power Mode" is a
// control -- four power-profile buttons the user presses, plus the battery and
// device summary, none of which needs re-reading. "Suspend and lid behavior" is
// a readout of what logind answered, and it polls PowerManager for as long as
// the pane is on screen; that section, its three fallback-property sets and its
// watch/poll pairing are SettingsLidBehavior, which is where the seam is.
//
// The seam is drawn at "does this need to know the answer", not at a line
// count. Anything that reads logind goes in the child; anything the user
// changes goes here.

ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "settings"
        title: "System"
        subtitle: "Power modes, battery and device profile."
    }

    SettingsCard {
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Power Mode" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: PowerProfile.profiles
                    StyledButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData
                        variant: PowerProfile.active === modelData ? "primary" : "ghost"
                        onClicked: PowerProfile.setProfile(modelData)
                    }
                }
            }

            StyledText {
                variant: "mediaSubtitle"
                color: Theme.withAlpha(Theme.colors.text, 0.5)
                text: PowerProfile.available ? "Active: " + PowerProfile.active : "power-profiles-daemon not available"
            }
        }

        SettingsDivider {}

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Icon {
                    icon: Battery.charging ? "battery_charging_full" : "battery_std"
                    size: 18
                    iconColor: Battery.low && !Battery.charging ? Theme.colors.danger : Theme.colors.text
                }
                StyledText {
                    Layout.fillWidth: true
                    variant: "mediaTitle"
                    font.pixelSize: 13
                    text: Battery.available
                        ? Battery.percentage + "%" + (Battery.charging ? " — Charging" : " — " + Battery.formattedTimeRemaining() + " left")
                        : "No battery"
                }
            }

            StyledText {
                variant: "mediaSubtitle"
                color: Theme.withAlpha(Theme.colors.text, 0.5)
                text: DeviceProfile.lowSpec
                    ? "Low-spec mode: " + DeviceProfile.cpuCount + " cores, " + Math.round(DeviceProfile.memKB / 1024) + " MB — shadows/cava reduced"
                    : "Device: " + DeviceProfile.cpuCount + " cores, " + Math.round(DeviceProfile.memKB / 1024) + " MB"
            }
        }
    }

    // paneVisible, not `visible`. PagePanel keeps every page alive and shows one
    // at a time by fading opacity, so this section is alive and laid out even
    // when another page is on screen; binding it to visibility instead would
    // make the pane lose this section's height whenever you navigated away.
    // SettingsLidBehavior owns the reason in full.
    SettingsLidBehavior {
        Layout.fillWidth: true
        paneVisible: root.visible
    }
}