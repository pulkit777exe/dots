import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["motion", "animation", "animate",
        "reduce", "speed", "movement", "fade", "hover", "bounce", "spring"]

    SettingsHeader {
        icon: "sensors"
        title: "Motion"
        subtitle: "How fast the shell animates, or whether it animates at all."
    }

    SettingsCard {
        SettingsToggleRow {
            label: "Reduce motion"
            checked: Config.reduceMotion
            onToggled: (v) => Config.set("reduceMotion", v)
        }
    }

    SettingsCard {
        enabled: !Config.reduceMotion
        opacity: Config.reduceMotion ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: Config.fade() } }

        SettingsSliderRow {
            label: "Movement (size / position)"
            value: Config.movementMs
            from: 100; to: 800; suffix: " ms"
            onMoved: (v) => Config.set("movementMs", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Fades & colour"
            value: Config.fadeMs
            from: 50; to: 500; suffix: " ms"
            onMoved: (v) => Config.set("fadeMs", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Hover response"
            value: Config.hoverMs
            from: 50; to: 400; suffix: " ms"
            onMoved: (v) => Config.set("hoverMs", Math.round(v))
        }
        SettingsDivider {}
        SettingsSliderRow {
            label: "Bounce"
            value: Config.bouncePercent
            from: 0; to: 100; suffix: " %"
            onMoved: (v) => Config.set("bouncePercent", Math.round(v))
        }
    }
}
