import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// SettingsToggleRow
// "Label .................... [toggle]" — the settings app's boolean row.
// Sits inside a SettingsCard and is separated from its neighbours by a
// SettingsDivider, so it carries no background or margin of its own.
Item {
    id: root

    property string label: ""
    property bool checked: false

    signal toggled(bool value)

    // 44, not 52. Measured off 2026-09-20_22-30-18 alongside the 61px slider
    // row: 8 x 61 + 3 x 44 + 10 dividers = 630, the reference card's exact
    // height. See SettingsSliderRow for the same arithmetic.
    implicitHeight: 44
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: 13
            // Warm off-white, (239,232,221) in the reference.
            color: Qt.rgba(1, 0.97, 0.925, 0.95)
            elide: Text.ElideRight
        }

        Toggle {
            checked: root.checked
            accentColor: Theme.colors.accent
            onToggled: (v) => root.toggled(v)
        }
    }
}
