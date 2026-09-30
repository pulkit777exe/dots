import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"





ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "mobile_vibrate"
        title: "Motion"
        subtitle: "How fast the shell animates, or whether it animates at all."
    }

    SettingsCard {
        SettingsToggleRow {
            label: "Reduce motion"
            checked: MotionConfig.reduceMotion
            onToggled: (v) => MotionConfig.setReduceMotion(v)
        }

        SettingsDivider {}

        
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            enabled: !MotionConfig.reduceMotion
            opacity: MotionConfig.reduceMotion ? 0.4 : 1

            SettingsSliderRow {
                label: "Movement (size / position)"
                value: MotionConfig.movementMs
                from: 100; to: 800; suffix: " ms"
                onMoved: (v) => MotionConfig.setMovementMs(v)
            }

            SettingsDivider {}

            SettingsSliderRow {
                label: "Fades & colour"
                value: MotionConfig.fadeMs
                from: 50; to: 500; suffix: " ms"
                onMoved: (v) => MotionConfig.setFadeMs(v)
            }

            SettingsDivider {}

            SettingsSliderRow {
                label: "Hover response"
                value: MotionConfig.hoverMs
                from: 50; to: 400; suffix: " ms"
                onMoved: (v) => MotionConfig.setHoverMs(v)
            }

            SettingsDivider {}

            SettingsSliderRow {
                label: "Bounce"
                value: MotionConfig.bouncePercent
                from: 0; to: 100; suffix: " %"
                onMoved: (v) => MotionConfig.setBouncePercent(v)
            }
        }
    }
}
