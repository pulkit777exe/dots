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
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 28
            color: Qt.rgba(1, 1, 1, 0.06)
            Icon { anchors.centerIn: parent; icon: "notifications"; size: 22; iconColor: Theme.colors.accent }
        }
        ColumnLayout {
            spacing: 2
            StyledText { variant: "mediaTitle"; font.pixelSize: 17; text: "Notifications & DND" }
            StyledText {
                variant: "mediaSubtitle"
                text: "Toast timeouts, island morphs, sound alerts, and Do Not Disturb."
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Do Not Disturb (Peace Mode)" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: Notifications.dnd
            accentColor: Theme.colors.accent
            onToggled: Notifications.dnd = !Notifications.dnd
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Morph Island on Incoming Notification" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.notifIslandMorph
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setNotifIslandMorph(v)
        }
    }

    SettingsSliderRow {
        label: "Popup timeout"
        value: ConfigStore.notifPopupTimeoutMs
        from: 1000; to: 10000; suffix: " ms"
        onMoved: (v) => ConfigStore.setNotifPopupTimeoutMs(Math.round(v))
    }

    SettingsSliderRow {
        label: "Urgent timeout"
        value: ConfigStore.notifUrgentTimeoutMs
        from: 2000; to: 20000; suffix: " ms"
        onMoved: (v) => ConfigStore.setNotifUrgentTimeoutMs(Math.round(v))
    }

    SettingsSliderRow {
        label: "Width"
        value: ConfigStore.notifWidth
        from: 320; to: 640; suffix: " px"
        onMoved: (v) => ConfigStore.setNotifWidth(Math.round(v))
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Show body text" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.notifShowBodyText
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setNotifShowBodyText(v)
        }
    }

    SettingsSliderRow {
        label: "History height"
        value: ConfigStore.notifHistoryHeight
        from: 100; to: 400; suffix: " px"
        onMoved: (v) => ConfigStore.setNotifHistoryHeight(Math.round(v))
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Play Audio Tone on Normal & Critical Alerts" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.notifSoundEnabled
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setNotifSoundEnabled(v)
        }
    }

    // ── Volume / Brightness OSD ──────────────────────────────────
    StyledText {
        text: "VOLUME / BRIGHTNESS OSD"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1
        textColor: Qt.rgba(1, 1, 1, 0.4)
    }

    SettingsSliderRow {
        label: "On-screen time"
        value: ConfigStore.osdOnScreenTimeMs
        from: 500; to: 4000; suffix: " ms"
        onMoved: (v) => ConfigStore.setOsdOnScreenTimeMs(Math.round(v))
    }

    SettingsSliderRow {
        label: "Level bar thickness"
        value: ConfigStore.osdLevelBarThickness
        from: 3; to: 14; suffix: " px"
        onMoved: (v) => ConfigStore.setOsdLevelBarThickness(Math.round(v))
    }

    // Quick Action button
    Surface {
        Layout.fillWidth: true
        implicitHeight: 52
        cornerRadius: 14
        backgroundColor: Theme.colors.surface

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: 13
                text: "Active notifications in stack: " + Notifications.active.length
            }

            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 90
                radius: 8
                color: clearBtnHover.hovered ? Qt.rgba(1, 0.3, 0.3, 0.2) : Qt.rgba(1, 0.3, 0.3, 0.1)
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                StyledText {
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    textColor: Theme.colors.danger
                    text: "Clear all"
                }

                HoverHandler { id: clearBtnHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Notifications.clearAll() }
            }
        }
    }
}
