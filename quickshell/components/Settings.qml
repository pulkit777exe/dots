import QtQuick
import QtQuick.Layouts
import "../core"
import "ui"

/** Image 11: bar height / font size sliders, then nav rows into theme and
 *  wallpaper. Sliders write through Theme.setBarHeight/setFontSize, which
 *  shell out to island-set-metric.sh -- deliberately never touches
 *  hyprlock's color file, see ARCHITECTURE.md section 4. */
ColumnLayout {
    Layout.fillWidth: true
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Bar height"; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 2; font.family: Theme.fontFamily; Layout.preferredWidth: 90 }
        Slider01 {
            Layout.fillWidth: true
            value: (Theme.barHeight - 28) / (56 - 28)
            onMoved: (v) => Theme.setBarHeight(Math.round(28 + v * (56 - 28)))
        }
        Text { text: Theme.barHeight + " px"; color: Theme.colors.text; font.pixelSize: Theme.fontSize - 2; font.family: Theme.fontFamily }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Font size"; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 2; font.family: Theme.fontFamily; Layout.preferredWidth: 90 }
        Slider01 {
            Layout.fillWidth: true
            value: (Theme.fontSize - 11) / (20 - 11)
            onMoved: (v) => Theme.setFontSize(Math.round(11 + v * (20 - 11)))
        }
        Text { text: Theme.fontSize + " px"; color: Theme.colors.text; font.pixelSize: Theme.fontSize - 2; font.family: Theme.fontFamily }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.colors.surfaceHover }

    SettingsNavRow { label: "Theme"; value: Theme.activeName; onTap: IslandState.pushPanel("theme") }
    SettingsNavRow { label: "Wallpaper"; value: "Choose..."; onTap: IslandState.pushPanel("wallpaper") }

    component SettingsNavRow: RowLayout {
        property string label: ""
        property string value: ""
        signal tap()
        Layout.fillWidth: true
        Text { text: label; color: Theme.colors.text; font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; Layout.fillWidth: true }
        Text { text: value + "  " + Config.iconChevron; color: Theme.colors.accent; font.pixelSize: Theme.fontSize - 2; font.family: Config.iconFontFamily
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: parent.parent.tap() } }
    }
}
