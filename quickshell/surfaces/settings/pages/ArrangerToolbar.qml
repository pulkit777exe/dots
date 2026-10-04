import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// The "Layout" row: how many columns the grid has, the three whole-layout
// actions, and the one-line hint on the right.
//
// Tidy / Undo / Reset are declared as one model with a `run` closure each
// rather than as three near-identical rectangles, so that adding an action is
// one more line in the array instead of a new block of QML.
Item {
    id: root

    signal wantFocus()

    function takeFocus() { root.wantFocus(); }

    Layout.fillWidth: true
    implicitHeight: 30

    RowLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: Array.from(
                { length: ControlCenterLayout.maxColumns - ControlCenterLayout.minColumns + 1 },
                (_, i) => ControlCenterLayout.minColumns + i)

            delegate: Rectangle {
                id: colPill
                required property int modelData
                readonly property bool active: modelData === ControlCenterLayout.columns

                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: colPill.active ? Theme.colors.accent : Theme.colors.surface

                StyledText {
                    anchors.centerIn: parent
                    text: colPill.modelData
                    font.pixelSize: 12
                    font.weight: colPill.active ? Font.DemiBold : Font.Normal
                    color: colPill.active ? Theme.colors.accentText : Theme.withAlpha(Theme.colors.text, 0.7)
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        ControlCenterLayout.setColumns(colPill.modelData);
                        root.takeFocus();
                    }
                }
            }
        }

        Item { Layout.preferredWidth: 10 }

        Repeater {
            model: [
                { label: "Tidy",  enabled: true,
                  run: function () { ControlCenterLayout.tidy(); } },
                { label: "Undo",  enabled: ControlCenterLayout.undoDepth > 0,
                  run: function () { ControlCenterLayout.undo(); } },
                { label: "Reset", enabled: true,
                  run: function () { ControlCenterLayout.reset(); } }
            ]

            delegate: Rectangle {
                id: btn
                required property var modelData
                readonly property bool on: modelData.enabled

                Layout.preferredWidth: labelText.implicitWidth + 28
                Layout.preferredHeight: 30
                radius: 15
                color: btn.on
                    ? (btnHover.hovered ? Theme.colors.surfaceAlt : Theme.colors.surface)
                    : Theme.withAlpha(Theme.colors.text, 0.02)

                StyledText {
                    id: labelText
                    anchors.centerIn: parent
                    text: btn.modelData.label
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: btn.on ? Theme.withAlpha(Theme.colors.text, 0.8) : Theme.withAlpha(Theme.colors.text, 0.28)
                }

                HoverHandler { id: btnHover; enabled: btn.on; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: btn.on
                    onTapped: { btn.modelData.run(); root.takeFocus(); }
                }
            }
        }
    }

    StyledText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Drag to move · corner to resize · right-click for sizes"
        font.pixelSize: 11
        textColor: Theme.withAlpha(Theme.colors.text, 0.42)
    }
}
