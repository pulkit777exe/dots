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
            label: "Width"
            value: Config.notifWidth
            from: 320; to: 720; suffix: " px"
            onMoved: (v) => Config.set("notifWidth", Math.round(v))
        }
        SettingsDivider {}
        SettingsToggleRow {
            label: "Show body text"
            checked: Config.notifShowBodyText
            onToggled: (v) => Config.set("notifShowBodyText", v)
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "History height"
            value: Config.notifHistoryHeight
            from: 50; to: 600; suffix: " px"
            onMoved: (v) => Config.set("notifHistoryHeight", Math.round(v))
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: "VOLUME / BRIGHTNESS OSD"
        font.pixelSize: Theme.px(10)
        font.weight: Font.DemiBold
        font.letterSpacing: 1
        color: Theme.withAlpha(Theme.colors.text, 0.45)
    }

    SettingsCard {
        SettingsSliderRow {
            label: "On-screen time"
            value: Config.osdTimeoutMs
            from: 500; to: 5000; suffix: " ms"
            onMoved: (v) => Config.set("osdTimeoutMs", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Level bar thickness"
            value: Config.osdBarThickness
            from: 2; to: 16; suffix: " px"
            onMoved: (v) => Config.set("osdBarThickness", Math.round(v))
        }
    }
}
