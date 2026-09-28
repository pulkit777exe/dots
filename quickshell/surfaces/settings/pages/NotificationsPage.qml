import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// NotificationsPage
// The reference splits the page in two: popup geometry and body text above,
// OSD timing below, separated by a section caption.
//
// Dropped to match it, all still real and still applied:
//   Do Not Disturb, Morph Island on Incoming Notification, Play Audio Tone,
//   and the "Clear all" card. Notifications.dnd and ConfigStore's sound flag
//   are unchanged -- they just have no row here.
ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "notifications"
        title: "Notifications"
        subtitle: "How long popups stay up and how much they show."
    }

    SettingsCard {
        SettingsSliderRow {
            label: "Popup timeout"
            value: ConfigStore.notifPopupTimeoutMs
            from: 1000; to: 10000; suffix: " ms"
            onMoved: (v) => ConfigStore.setNotifPopupTimeoutMs(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Urgent timeout"
            value: ConfigStore.notifUrgentTimeoutMs
            from: 2000; to: 20000; suffix: " ms"
            onMoved: (v) => ConfigStore.setNotifUrgentTimeoutMs(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Width"
            value: ConfigStore.notifWidth
            from: 320; to: 640; suffix: " px"
            onMoved: (v) => ConfigStore.setNotifWidth(Math.round(v))
        }

        SettingsDivider {}

        SettingsToggleRow {
            label: "Show body text"
            checked: ConfigStore.notifShowBodyText
            onToggled: (v) => ConfigStore.setNotifShowBodyText(v)
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "History height"
            value: ConfigStore.notifHistoryHeight
            from: 100; to: 400; suffix: " px"
            onMoved: (v) => ConfigStore.setNotifHistoryHeight(Math.round(v))
        }
    }

    SettingsSectionLabel {
        label: "Volume / Brightness OSD"
        upperCase: true
    }

    SettingsCard {
        SettingsSliderRow {
            label: "On-screen time"
            value: ConfigStore.osdOnScreenTimeMs
            from: 500; to: 4000; suffix: " ms"
            onMoved: (v) => ConfigStore.setOsdOnScreenTimeMs(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Level bar thickness"
            value: ConfigStore.osdLevelBarThickness
            from: 3; to: 14; suffix: " px"
            onMoved: (v) => ConfigStore.setOsdLevelBarThickness(Math.round(v))
        }
    }
}
