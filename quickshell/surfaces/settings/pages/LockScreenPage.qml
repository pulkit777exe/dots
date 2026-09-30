import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../components"
import "../../../services"
ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "lock"
        title: "Lock Screen & Security"
        subtitle: "Session locking, idle timers, media widgets, and authentication."
    }

    SettingsSliderRow {
        label: "Idle Sleep Timeout"
        value: ConfigStore.lockscreenTimeoutMins
        from: 1; to: 60; suffix: " mins"
        onMoved: (v) => ConfigStore.setLockscreenTimeoutMins(Math.round(v))
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Show Media Controls on Lock Screen" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.lockscreenShowMedia
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setLockscreenShowMedia(v)
        }
    }

    
    Surface {
        Layout.fillWidth: true
        implicitHeight: 64
        cornerRadius: 14
        backgroundColor: Theme.colors.surface

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Icon { icon: "shield"; size: 22; iconColor: Theme.colors.accent }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText { font.pixelSize: 13; font.weight: Font.DemiBold; text: "Lock Session Now" }
                StyledText { font.pixelSize: 11; textColor: Qt.rgba(1,1,1,0.6); text: "Triggers hyprlock / system session lock" }
            }

            Rectangle {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 90
                radius: 17
                color: lockBtnHover.hovered ? Qt.lighter(Theme.colors.accent, 1.15) : Theme.colors.accent
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                StyledText {
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    textColor: Theme.colors.accentText
                    text: "Lock"
                }

                HoverHandler { id: lockBtnHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Quickshell.execDetached(["hyprlock"]) }
            }
        }
    }
}
