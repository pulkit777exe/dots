import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// The "Add a control" row: one chip per entry in ControlCenterLayout.palette,
// each labelled with the size a click will add it at.
//
// The list is not written out here. The catalogue is the single source of
// truth for which controls exist, what they are called, and what sizes they
// support, so a chip appears when a catalogue entry does and the page never
// has to learn a control's name.
Flow {
    id: root

    signal wantFocus()

    function takeFocus() { root.wantFocus(); }

    Layout.fillWidth: true
    spacing: 8

    Repeater {
        model: ControlCenterLayout.palette

        delegate: Rectangle {
            id: chip
            required property var modelData
            width: chipRow.implicitWidth + 26
            height: 30
            radius: 15
            color: chipHover.hovered ? Theme.colors.surfaceAlt : Theme.colors.surface

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 9

                Icon {
                    icon: chip.modelData.icon
                    size: 14
                    iconColor: Theme.withAlpha(Theme.colors.text, 0.7)
                }
                StyledText {
                    text: chip.modelData.label
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.withAlpha(Theme.colors.text, 0.82)
                }
                StyledText {
                    text: chip.modelData.size[0] + "×" + chip.modelData.size[1]
                    font.pixelSize: 11
                    textColor: Theme.withAlpha(Theme.colors.text, 0.4)
                }
            }

            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    ControlCenterLayout.add(chip.modelData.type);
                    root.takeFocus();
                }
            }
        }
    }
}
