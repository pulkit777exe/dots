import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

PopupPanel {
    id: root

    open: UiState.authOpen
    width: 440
    implicitHeight: col.implicitHeight + 32
    cornerRadius: open ? Config.expandedRadius : pillRadius
    backgroundColor: Theme.colors.background

    function submit() {
        Auth.submit(pass.text);
        pass.text = "";
    }

    onOpenChanged: if (open) {
        pass.text = "";
        showPassword = false;
        Qt.callLater(() => pass.forceActiveFocus());
    }
    onActiveFocusChanged: if (activeFocus && open)
        Qt.callLater(() => pass.forceActiveFocus());

    property bool showPassword: false

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: Theme.accentFor("auth")

                Icon {
                    anchors.centerIn: parent
                    icon: "lock"
                    size: 15
                    iconColor: Theme.colors.accentText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Label {
                    text: "Authentication required"
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                }

                Label {
                    visible: Auth.user.length > 0
                    text: Auth.user
                    font.pixelSize: Theme.px(11)
                    color: Theme.withAlpha(Theme.colors.text, 0.48)
                }
            }
        }

        Label {
            visible: Auth.message.length > 0
            Layout.fillWidth: true
            text: Auth.message
            font.pixelSize: Theme.px(12)
            color: Theme.withAlpha(Theme.colors.text, 0.75)
            wrapMode: Text.WordWrap
        }

        Label {
            visible: Auth.isRetry
            Layout.fillWidth: true
            text: "Sorry, that didn't work — try again."
            font.pixelSize: Theme.px(11)
            color: Theme.colors.danger
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 10
            color: Theme.withAlpha(Theme.colors.text, 0.07)
            border.color: pass.activeFocus
                ? Theme.accentFor("auth")
                : Theme.withAlpha(Theme.colors.text, 0.12)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 6

                TextInput {
                    id: pass
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(14)
                    color: Theme.withAlpha(Theme.colors.text, 0.92)
                    selectionColor: Theme.withAlpha(Theme.colors.accent, 0.35)
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    clip: true

                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: (event) => { Auth.cancel(); event.accepted = true; }
                }

                IconButton {
                    icon: root.showPassword ? "visibility_off" : "visibility"
                    onClicked: root.showPassword = !root.showPassword;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            StyledButton {
                label: "Cancel"
                onClicked: Auth.cancel()
            }

            StyledButton {
                label: "Authenticate"
                filled: true
                accent: Theme.accentFor("auth")
                onClicked: root.submit()
            }
        }
    }
}
