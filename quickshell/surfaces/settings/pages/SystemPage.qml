import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 20

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Rectangle {
            Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 28
            color: Qt.rgba(1,1,1,0.06)
            Icon { anchors.centerIn: parent; icon: "settings"; size: 22; iconColor: Theme.colors.accent }
        }
        ColumnLayout {
            spacing: 2
            StyledText { variant: "mediaTitle"; font.pixelSize: 17; text: "System" }
            StyledText { variant: "mediaSubtitle"; text: "Power modes, battery and device profile." }
        }
    }

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
            color: Qt.rgba(1,1,1,0.5)
            text: PowerProfile.available ? "Active: " + PowerProfile.active : "power-profiles-daemon not available"
        }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.08) }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Icon { icon: Battery.charging ? "battery_charging_full" : "battery_std"; size: 18; iconColor: Battery.low && !Battery.charging ? Theme.colors.danger : Theme.colors.text }
            StyledText { Layout.fillWidth: true; variant: "mediaTitle"; font.pixelSize: 13; text: Battery.available ? Battery.percentage + "%" + (Battery.charging ? " — Charging" : " — " + Battery.formattedTimeRemaining() + " left") : "No battery" }
        }
        StyledText {
            variant: "mediaSubtitle"
            color: Qt.rgba(1,1,1,0.5)
            text: DeviceProfile.lowSpec ? "Low-spec mode: " + DeviceProfile.cpuCount + " cores, " + Math.round(DeviceProfile.memKB/1024) + " MB — shadows/cava reduced" : "Device: " + DeviceProfile.cpuCount + " cores, " + Math.round(DeviceProfile.memKB/1024) + " MB"
        }
    }
}
