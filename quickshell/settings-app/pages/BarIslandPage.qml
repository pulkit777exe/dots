import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["bar", "island", "notch", "height",
        "width", "gap", "radius", "status", "now playing", "card", "tray"]

    SettingsHeader {
        icon: "crop_landscape"
        title: "Bar & Island"
        subtitle: "Shape and size of the notch, the island, and the bar."
    }

    SettingsCard {
        SettingsToggleRow {
            label: "Notch mode"
            checked: Config.notchMode
            onToggled: (v) => Config.set("notchMode", v)
        }
        SettingsDivider {}
        SettingsToggleRow {
            label: "Status indicators (signal and battery)"
            checked: Config.statusEnabled
            onToggled: (v) => Config.set("statusEnabled", v)
        }
        SettingsDivider {}
        SettingsToggleRow {
            label: "Now-playing card"
            checked: Config.cardEnabled
            onToggled: (v) => Config.set("cardEnabled", v)
        }
        SettingsDivider {}
        SettingsToggleRow {
            label: "System tray icons"
            checked: Config.trayEnabled
            onToggled: (v) => Config.set("trayEnabled", v)
        }
    }

    SettingsCard {
        SettingsSliderRow {
            label: "Bar height"
            value: Config.barHeight
            from: 24; to: 56; suffix: " px"
            onMoved: (v) => Config.set("barHeight", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Minimum island width"
            value: Config.collapsedWidth
            from: 60; to: 240; suffix: " px"
            onMoved: (v) => Config.set("collapsedWidth", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Gap from screen edge"
            value: Config.gapFromEdge
            from: 0; to: 40; suffix: " px"
            onMoved: (v) => Config.set("gapFromEdge", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Corner radius"
            value: Config.collapsedRadius
            from: 0; to: 40; suffix: " px"
            onMoved: (v) => Config.set("collapsedRadius", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Corner radius (expanded)"
            value: Config.expandedRadius
            from: 12; to: 40; suffix: " px"
            onMoved: (v) => Config.set("expandedRadius", Math.round(v))
        }
    }
}
