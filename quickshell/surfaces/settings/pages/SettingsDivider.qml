import QtQuick
import QtQuick.Layouts

// SettingsDivider
// The hairline rule between two rows inside a SettingsCard. An Item with a
// fixed 1px height rather than a bare Rectangle, because a Rectangle with no
// implicit size collapses to zero inside a ColumnLayout.
//
// (39,37,35) over the card's (16,14,12) -- measured off 2026-09-20_22-30-18,
// where every row in every card is separated by one. That is white at ~9%.
//
// QtQuick.Layouts is needed for the Layout attached properties below.
Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: 1

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(1, 1, 1, 0.09)
    }
}
