import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

Surface {
    id: root

    width: 520
    implicitHeight: column.implicitHeight + 28

    cornerRadius: 22

    // Everything color-related comes from the active theme.
    backgroundColor: Theme.colors.surface

    property color accent: Theme.colors.accent

    readonly property var _p: Auth.pending

    readonly property string dialogTitle: "Authentication Required"

    readonly property string message:
        _p ? _p.message : ""

    readonly property string actionId:
        _p ? _p.actionId : ""

    readonly property string errorText:
        _p ? _p.errorText : ""

    readonly property bool responseHidden:
        _p ? !_p.responseVisible : true

    signal authenticateRequested(string password)
    signal cancelled()

    function clearPassword() {
        passwordField.text = ""
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        // ========================================================
        // TITLE
        // ========================================================

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                icon: "lock"
                size: 17
                iconColor: Theme.colors.accent
            }

            StyledText {
                Layout.fillWidth: true

                variant: "mediaTitle"

                text: root.dialogTitle

                font.pixelSize: 17
                font.weight: Font.DemiBold

                color: Theme.colors.text

                elide: Text.ElideRight
            }
        }

        // ========================================================
        // MESSAGE
        // ========================================================

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 5

            visible: root.message.length > 0

            variant: "body"

            text: root.message

            font.pixelSize: 13
            font.weight: Font.Normal

            color: Theme.colors.textMuted

            wrapMode: Text.WordWrap
        }

        // ========================================================
        // ACTION ID
        // ========================================================

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 4

            visible: root.actionId.length > 0

            variant: "mediaArtist"

            text: root.actionId

            font.pixelSize: 10
            font.weight: Font.Normal

            color: Theme.colors.textMuted

            elide: Text.ElideRight
        }

        // ========================================================
        // PASSWORD
        // ========================================================

        Rectangle {
            id: passwordBox

            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.preferredHeight: 42

            radius: 12

            color: Theme.colors.surfaceAlt

            border.width:
                passwordField.activeFocus ? 1 : 0

            border.color: Theme.colors.accent

            TextInput {
                id: passwordField

                anchors.fill: parent

                anchors.leftMargin: 12
                anchors.rightMargin: 12

                verticalAlignment: TextInput.AlignVCenter

                echoMode:
                    root.responseHidden
                        ? TextInput.Password
                        : TextInput.Normal

                color: Theme.colors.text

                font.pixelSize: 13
                font.family: "SF Pro Display"

                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnTab: true

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    visible:
                        passwordField.text.length === 0

                    variant: "mediaSubtitle"

                    text:
                        root._p &&
                        root._p.inputPrompt
                            ? root._p.inputPrompt
                            : "Password:"

                    font.pixelSize: 13
                    color: Theme.colors.textMuted
                }

                onAccepted:
                    root.authenticateRequested(text)

                Component.onCompleted: {
                    if (Auth.pending)
                        forceActiveFocus()
                }

                onVisibleChanged: {
                    if (visible && Auth.pending)
                        forceActiveFocus()
                }

                Connections {
                    target: Auth

                    function onRequestBegan() {
                        passwordField.text = ""

                        Qt.callLater(function() {
                            passwordField.forceActiveFocus()
                        })
                    }
                }
            }
        }

        // ========================================================
        // ERROR
        // ========================================================

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 5

            visible: root.errorText.length > 0

            variant: "mediaSubtitle"

            text: root.errorText

            font.pixelSize: 11

            color: Theme.colors.danger

            wrapMode: Text.WordWrap
        }

        // ========================================================
        // BUTTONS
        // ========================================================

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8

            spacing: 7

            Item {
                Layout.fillWidth: true
            }

            // ----------------------------------------------------
            // CANCEL
            // ----------------------------------------------------

            Rectangle {
                id: cancelButton

                Layout.preferredWidth: 62
                Layout.preferredHeight: 32

                radius: 16

                color:
                    cancelMouse.containsMouse
                        ? Theme.colors.surfaceHover
                        : Theme.colors.surfaceAlt

                Behavior on color {
                    ColorAnimation {
                        duration: MotionConfig.hover()
                    }
                }

                StyledText {
                    anchors.centerIn: parent

                    text: "Cancel"

                    font.pixelSize: 12
                    font.weight: Font.Medium

                    color: Theme.colors.textMuted
                }

                MouseArea {
                    id: cancelMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onClicked:
                        root.cancelled()
                }
            }

            // ----------------------------------------------------
            // AUTHENTICATE
            // ----------------------------------------------------

            Rectangle {
                id: authenticateButton

                Layout.preferredWidth: 96
                Layout.preferredHeight: 32

                radius: 16

                color:
                    authenticateMouse.pressed
                        ? Theme.colors.accentAlt
                        : Theme.colors.accent

                Behavior on color {
                    ColorAnimation {
                        duration: MotionConfig.hover()
                    }
                }

                StyledText {
                    anchors.centerIn: parent

                    text: "Authenticate"

                    font.pixelSize: 12
                    font.weight: Font.DemiBold

                    color: Theme.colors.accentText
                }

                MouseArea {
                    id: authenticateMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onClicked:
                        root.authenticateRequested(
                            passwordField.text
                        )
                }
            }
        }
    }
}