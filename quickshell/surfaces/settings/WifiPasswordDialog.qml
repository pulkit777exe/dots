import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Surface {
    id: root

    width: 380
    cornerRadius: 18
    backgroundColor: Theme.panelFill

    property color accent: Theme.colors.accent
    property string ssid: ""
    property string errorText: ""
    property bool connecting: false
    property bool requestToken: false

    signal submitted(string password)
    signal cancelled()

    function open(forSsid, error) {
        ssid = forSsid;
        errorText = error || "";
        passwordField.text = "";
        requestToken = !requestToken;
    }

    implicitHeight: column.implicitHeight + 32

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 22
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon { icon: "wifi_lock"; size: 18; iconColor: Qt.rgba(1, 1, 1, 0.85) }

            StyledText {
                Layout.fillWidth: true
                variant: "mediaTitle"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                text: "Wi-Fi Password"
            }
        }

        StyledText {
            Layout.fillWidth: true
            variant: "mediaArtist"
            font.pixelSize: 12
            elide: Text.ElideRight
            text: "Enter the password for \u201c" + root.ssid + "\u201d"
        }

        Rectangle {
            id: passwordBox
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: 40
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: passwordField.activeFocus ? 1 : 0
            border.color: root.accent

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 40
                verticalAlignment: TextInput.AlignVCenter
                echoMode: revealButton.revealed ? TextInput.Normal : TextInput.Password
                color: Qt.rgba(1, 1, 1, 0.9)
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                activeFocusOnTab: true
                enabled: !root.connecting

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "mediaSubtitle"
                    text: "Password"
                    visible: passwordField.text.length === 0 && !passwordField.activeFocus
                    color: Qt.rgba(1, 1, 1, 0.35)
                }

                onAccepted: if (text.length > 0 && !root.connecting) root.submitted(text)

                // Same robust-focus retry as AuthDialog.qml — see file
                // header for why this specific pattern, not a simpler one.
                Timer {
                    id: _focusRetry
                    interval: 80
                    repeat: false
                    onTriggered: if (root.visible && !passwordField.activeFocus) passwordField.forceActiveFocus()
                }
                Component.onCompleted: if (root.visible) forceActiveFocus()
                onVisibleChanged: if (visible && root.visible) forceActiveFocus()
            }

            IconButton {
                id: revealButton
                property bool revealed: false
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 4
                icon: revealed ? "visibility_off" : "visibility"
                size: 30
                iconSize: 15
                onClicked: revealed = !revealed
            }
        }

        Connections {
            target: root
            function onRequestTokenChanged() {
                Qt.callLater(() => {
                    passwordField.forceActiveFocus()
                    if (!passwordField.activeFocus) _focusRetry.restart()
                })
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.errorText.length > 0
            variant: "mediaSubtitle"
            font.pixelSize: 12
            color: Theme.colors.danger
            wrapMode: Text.WordWrap
            text: root.errorText
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8

            Item { Layout.fillWidth: true }

            StyledButton {
                text: "Cancel"
                variant: "ghost"
                enabled: !root.connecting
                onClicked: root.cancelled()
            }

            StyledButton {
                text: root.connecting ? "Connecting\u2026" : "Connect"
                variant: "filled"
                accentColor: root.accent
                enabled: !root.connecting && passwordField.text.length > 0
                onClicked: root.submitted(passwordField.text)
            }
        }
    }
}
