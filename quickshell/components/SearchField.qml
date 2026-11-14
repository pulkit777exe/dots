import QtQuick
import QtQuick.Layouts
import "../services"

Rectangle {
    id: root

    property string placeholderText: ""
    property bool externalNavigation: false
    property bool placeholderWhenFocused: false
    property alias text: input.text
    readonly property bool inputFocused: input.activeFocus

    property int fieldHeight: 40

    signal accepted()
    signal navigateLeft()
    signal navigateRight()
    signal navigateUp()
    signal navigateDown()

    function forceInputFocus() { input.forceActiveFocus(); }

    implicitHeight: fieldHeight
    color: "transparent"

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Icon {
            icon: "search"
            size: 18
            Layout.alignment: Qt.AlignVCenter
            iconColor: root.inputFocused
                ? Theme.withAlpha(Theme.colors.text, 0.65)
                : Theme.withAlpha(Theme.colors.text, 0.4)
            Behavior on iconColor { ColorAnimation { duration: Config.hover() } }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextField {
                id: input
                anchors.fill: parent

                Keys.onReturnPressed: root.accepted()
                Keys.onEnterPressed: root.accepted()
                Keys.onEscapePressed: (event) => { UiState.closeAll(); event.accepted = true; }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Left && root.externalNavigation) {
                        root.navigateLeft(); event.accepted = true;
                    } else if (event.key === Qt.Key_Right && root.externalNavigation) {
                        root.navigateRight(); event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.navigateUp(); event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        root.navigateDown(); event.accepted = true;
                    }
                }
            }

            Label {
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                text: root.placeholderText
                font.pixelSize: Theme.px(12)
                color: Theme.withAlpha(Theme.colors.text, 0.35)
                visible: input.text.length === 0
                    && (!input.activeFocus || root.placeholderWhenFocused)
            }
        }
    }
}
