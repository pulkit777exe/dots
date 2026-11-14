import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["startup", "autostart", "login", "launch",
        "commands", "session", "boot", "exec"]

    function add() {
        const command = commandField.text.trim();
        if (command.length === 0) return;
        const list = Config.autostart.slice();
        if (!list.includes(command)) list.push(command);
        Config.set("autostart", list);
        commandField.text = "";
        HyprSettings.apply();
    }

    function remove(index) {
        const list = Config.autostart.slice();
        list.splice(index, 1);
        Config.set("autostart", list);
        HyprSettings.apply();
    }

    SettingsHeader {
        icon: "rocket_launch"
        title: "Autostart"
        subtitle: "Commands launched when the Hyprland session starts."
    }

    SettingsCard {
        SettingsLabelRow { label: "Startup commands" }

        Repeater {
            model: Config.autostart

            Rectangle {
                id: row
                required property string modelData
                required property int index

                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.preferredHeight: 46
                radius: 12
                color: Theme.cc.item
                border.color: Theme.cc.border
                border.width: 1

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                    spacing: 10

                    Icon {
                        icon: "terminal"
                        size: 16
                        iconColor: Theme.withAlpha(Theme.colors.text, 0.55)
                    }

                    Label {
                        Layout.fillWidth: true
                        text: row.modelData
                        font.family: "monospace"
                        font.pixelSize: Theme.px(12)
                        color: Theme.colors.text
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "delete"
                        iconColor: Theme.withAlpha(Theme.colors.warning, 0.85)
                        onClicked: root.remove(row.index)
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: Config.autostart.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "No startup commands"
            font.pixelSize: Theme.px(12)
            color: Theme.withAlpha(Theme.colors.text, 0.4)
        }
    }

    SettingsCard {
        SettingsLabelRow { label: "Add a command" }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: 38
            radius: 10
            color: Theme.withAlpha(Theme.colors.text, 0.07)
            border.color: commandField.activeFocus ? Theme.accentFor("settings")
                                                  : Theme.withAlpha(Theme.colors.text, 0.12)
            border.width: 1

            TextField {
                id: commandField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                textSize: 13
                onAccepted: root.add()
                Keys.onReturnPressed: root.add()
                Keys.onEnterPressed: root.add()
            }

            Label {
                anchors.fill: parent
                anchors.leftMargin: 12
                verticalAlignment: Text.AlignVCenter
                visible: commandField.text.length === 0
                text: "e.g. nm-applet --indicator"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.35)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: "Runs as your user on every Hyprland start or reload."
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
                wrapMode: Text.WordWrap
            }

            StyledButton {
                label: "Add"
                filled: true
                accent: Theme.accentFor("settings")
                onClicked: root.add()
            }
        }
    }
}
