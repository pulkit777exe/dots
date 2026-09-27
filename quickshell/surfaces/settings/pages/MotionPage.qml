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
    spacing: 20

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 28
            color: Qt.rgba(1, 1, 1, 0.06)
            Icon { anchors.centerIn: parent; icon: "mobile_vibrate"; size: 22; iconColor: Theme.colors.accent }
        }
        ColumnLayout {
            spacing: 2
            StyledText { variant: "mediaTitle"; font.pixelSize: 17; text: "Motion" }
            StyledText { variant: "mediaSubtitle"; text: "How fast the shell animates, or whether it animates at all." }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Reduce motion" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: MotionConfig.reduceMotion
            accentColor: Theme.colors.accent
            onToggled: (v) => MotionConfig.setReduceMotion(v)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 16
        enabled: !MotionConfig.reduceMotion
        opacity: MotionConfig.reduceMotion ? 0.4 : 1

        SettingsSliderRow {
            label: "Movement (size / position)"
            value: MotionConfig.movementMs
            from: 100; to: 800; suffix: " ms"
            onMoved: (v) => MotionConfig.setMovementMs(v)
        }
        SettingsSliderRow {
            label: "Fades & colour"
            value: MotionConfig.fadeMs
            from: 50; to: 500; suffix: " ms"
            onMoved: (v) => MotionConfig.setFadeMs(v)
        }
        SettingsSliderRow {
            label: "Hover response"
            value: MotionConfig.hoverMs
            from: 50; to: 400; suffix: " ms"
            onMoved: (v) => MotionConfig.setHoverMs(v)
        }
        SettingsSliderRow {
            label: "Bounce"
            value: MotionConfig.bouncePercent
            from: 0; to: 100; suffix: " %"
            onMoved: (v) => MotionConfig.setBouncePercent(v)
        }
    }
}
