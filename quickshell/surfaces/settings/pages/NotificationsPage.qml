import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "notifications"
        title: "Notifications"
        subtitle: "How long popups stay up and how much they show."
    }

    SettingsCard {
        SettingsToggleRow {
            label: "Do not disturb"
            checked: Config.dnd
            onToggled: (v) => Config.set("dnd", v)
        }
        SettingsDivider {}
        SettingsToggleRow {
            label: "Show body text"
            checked: Config.notifShowBodyText
            onToggled: (v) => Config.set("notifShowBodyText", v)
        }
    }

    SettingsCard {
        SettingsSliderRow {
            label: "Popup timeout"
            value: Config.notifPopupTimeoutMs
            from: 500; to: 10000; suffix: " ms"
            onMoved: (v) => Config.set("notifPopupTimeoutMs", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Urgent timeout"
            value: Config.notifUrgentTimeoutMs
            from: 1000; to: 20000; suffix: " ms"
            onMoved: (v) => Config.set("notifUrgentTimeoutMs", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "History height"
            value: Config.notifHistoryHeight
            from: 50; to: 600; suffix: " px"
            onMoved: (v) => Config.set("notifHistoryHeight", Math.round(v))
        }
    }
}
