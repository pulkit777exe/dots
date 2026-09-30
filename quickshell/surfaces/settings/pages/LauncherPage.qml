import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"








ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "search"
        title: "Launcher"
        subtitle: "Size of the app launcher and its result rows."
    }

    SettingsCard {
        SettingsSliderRow {
            label: "Width"
            value: ConfigStore.launcherWidth
            from: 380; to: 800; suffix: " px"
            onMoved: (v) => ConfigStore.setLauncherWidth(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Row height"
            value: ConfigStore.launcherRowHeight
            from: 36; to: 72; suffix: " px"
            onMoved: (v) => ConfigStore.setLauncherRowHeight(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Rows before scrolling"
            value: ConfigStore.launcherRowsBeforeScrolling
            from: 3; to: 12; suffix: ""
            onMoved: (v) => ConfigStore.setLauncherRowsBeforeScrolling(Math.round(v))
        }
    }
}
