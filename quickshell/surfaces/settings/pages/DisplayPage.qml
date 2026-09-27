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
            Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 28
            color: Qt.rgba(1,1,1,0.06)
            Icon { anchors.centerIn: parent; icon: "brightness_high"; size: 22; iconColor: Theme.colors.accent }
        }
        ColumnLayout {
            spacing: 2
            StyledText { variant: "mediaTitle"; font.pixelSize: 17; text: "Display" }
            StyledText { variant: "mediaSubtitle"; text: "Brightness, night light and color temperature." }
        }
    }

    SettingsSliderRow {
        label: "Brightness"
        value: Brightness.level
        from: 1; to: 100; suffix: " %"
        enabled: Brightness.available || Brightness.monitors.length > 0
        onMoved: (v) => Brightness.setBrightness(v)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        StyledText { Layout.fillWidth: true; variant: "mediaTitle"; font.pixelSize: 13; text: "Night Light" }
        Toggle {
            checked: NightLight.enabled
            accentColor: Theme.colors.accent
            onToggled: (v) => NightLight.setEnabled(v)
        }
    }
    SettingsSliderRow {
        label: "Night temperature"
        value: NightLight.nightTemperature
        from: 1000; to: 6500; suffix: " K"
        enabled: NightLight.enabled
        onMoved: (v) => NightLight.setTemperature(v)
    }
    StyledText {
        Layout.fillWidth: true
        variant: "mediaSubtitle"
        color: Qt.rgba(1,1,1,0.5)
        wrapMode: Text.WordWrap
        text: NightLight.available ? "Uses hyprsunset (Wayland). No daemon → toggle does nothing, as noted in NightLight.qml." : "hyprsunset not found — install for Night Light to work."
    }
}
