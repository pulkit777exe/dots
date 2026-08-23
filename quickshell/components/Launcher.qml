import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Image 5: app launcher, top-level (Alt+Space), independent of the Control
 * Center panel stack. Reads .desktop files via a helper script rather than
 * parsing freedesktop entries in QML -- keeps this file focused on search/
 * selection UI, not desktop-entry parsing edge cases.
 */
Rectangle {
    id: root
    width: 480
    implicitHeight: col.implicitHeight + 24
    radius: 20
    color: Theme.colors.surface
    border.width: 1
    border.color: Qt.lighter(Theme.colors.surface, 1.3)

    property var apps: []          // [{ name, comment, exec, icon }]
    property string query: ""
    readonly property var filtered: query.length === 0 ? apps
        : apps.filter(a => a.name.toLowerCase().includes(query.toLowerCase()))

    Component.onCompleted: textInput.forceActiveFocus()

    function launch(exec) {
        launchProcess.command = ["sh", "-c", exec.replace(/%[fFuU]/g, "")]
        launchProcess.running = true
        IslandState.close()
    }

    Process { id: launchProcess }

    // NOTE: listing .desktop entries properly needs an XDG-compliant parser
    // (multiple search dirs, localized Name[]=, NoDisplay=true filtering).
    // `list-apps.sh` below is a placeholder single-pass version -- fine to
    // ship, but flag as a known simplification, not a hidden gap.
    Process {
        id: listProcess
        running: true
        command: [Quickshell.shellDir + "/scripts/list-apps.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const parts = line.split("\t")
                if (parts.length < 3) return
                root.apps = root.apps.concat([{ name: parts[0], comment: parts[1], exec: parts[2], icon: parts[3] || "" }])
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text { text: Config.iconSearch; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize; font.family: Config.iconFontFamily }
            Item {
                Layout.fillWidth: true
                TextInput {
                    id: textInput
                    anchors.fill: parent
                    color: Theme.colors.text
                    font.pixelSize: Theme.fontSize + 2
                    font.family: Theme.fontFamily
                    focus: true
                    clip: true
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: IslandState.close()
                    Keys.onReturnPressed: if (root.filtered.length > 0) root.launch(root.filtered[0].exec)
                }
                Text {
                    anchors.fill: parent
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search..."
                    color: Theme.colors.textMuted
                    font.pixelSize: Theme.fontSize + 2
                    font.family: Theme.fontFamily
                    visible: textInput.text.length === 0
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(320, contentHeight)
            model: root.filtered
            clip: true
            spacing: 2
            delegate: Rectangle {
                id: appRow
                width: ListView.view.width
                height: 48
                radius: 10
                color: appMouseArea.containsMouse ? Theme.colors.surfaceHover : "transparent"

                property bool hasIcon: modelData.icon && modelData.icon.length > 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: appRow.hasIcon ? "transparent" : Theme.colors.accent
                        visible: true
                        Text {
                            anchors.centerIn: parent
                            visible: !appRow.hasIcon
                            text: modelData.name.charAt(0).toUpperCase()
                            color: Theme.colors.bg
                            font.bold: true
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                        }
                    }
                    Text { text: modelData.name; color: Theme.colors.text; font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; Layout.fillWidth: true }
                    Text { text: modelData.comment; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 4; font.family: Theme.fontFamily; font.italic: true; elide: Text.ElideRight }
                }
                MouseArea { id: appMouseArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.launch(modelData.exec) }
            }
        }
    }
}
