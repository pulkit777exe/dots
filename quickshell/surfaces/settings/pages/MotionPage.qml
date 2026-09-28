import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// MotionPage
// Live MotionConfig sliders. Honest scope note (also in MotionConfig.qml
// itself): these currently drive Bar.qml, Slider.qml, and ListRow.qml's
// animations specifically — not literally every animation in the app.
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

        // Grouped in one ColumnLayout so the whole group dims together when
        // Reduce motion is on, rather than each row fading independently.
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
