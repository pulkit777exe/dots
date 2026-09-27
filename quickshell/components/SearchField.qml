import QtQuick
import QtQuick.Layouts
import "../services"

// SearchField
// Icon + text input row. No background of its own — it's meant to sit
// inside a Surface (the launcher, control center, etc.) which supplies
// the panel behind it.
Item {
    id: root

    property alias text: input.text
    property string placeholderText: "Search..."
    property int iconSize: 18
    property color textColor: Qt.rgba(1, 1, 1, 0.92)
    property color placeholderColor: Qt.rgba(1, 1, 1, 0.35)

    signal accepted()
    signal navigateLeft()
    signal navigateRight()
    signal navigateUp()
    signal navigateDown()
    // when true, arrow keys trigger navigate signals instead of moving cursor
    property bool externalNavigation: false

    implicitHeight: 40

    readonly property bool hasFocus: input.activeFocus

    function focusInput() {
        input.forceActiveFocus()
        // Qt docs: forceActiveFocus is async if window not active yet — HyprlandFocusGrab
        // makes this succeed only after barWindow gains Exclusive focus; Island timers retry.
        if (!input.activeFocus) Qt.callLater(() => input.forceActiveFocus())
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Icon {
            icon: "search"
            size: root.iconSize
            iconColor: input.activeFocus ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(1, 1, 1, 0.4)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                variant: "body"
                text: root.placeholderText
                textColor: root.placeholderColor
                opacity: input.text.length === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.hover(); easing.type: Easing.OutCubic } }
            }

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: root.textColor
                font.pixelSize: 14
                clip: true
                onAccepted: root.accepted()

                Keys.onDownPressed: (event) => {
                    root.navigateDown()
                    event.accepted = true
                }
                Keys.onUpPressed: (event) => {
                    root.navigateUp()
                    event.accepted = true
                }
                Keys.onLeftPressed: (event) => {
                    if (root.externalNavigation || (input.cursorPosition === 0 && input.selectionStart === input.selectionEnd)) {
                        root.navigateLeft()
                        event.accepted = true
                    }
                }
                Keys.onRightPressed: (event) => {
                    if (root.externalNavigation || (input.cursorPosition === input.text.length && input.selectionStart === input.selectionEnd)) {
                        root.navigateRight()
                        event.accepted = true
                    }
                }
                Keys.onEscapePressed: (event) => {
                    UiState.closeAll()
                    event.accepted = true
                }
            }
        }
    }
}
