import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../components"
import "../services"











Surface {
    id: root

    
    
    
    // Measured off the reference: five 90x80 tiles, 8 between them, and 14 of
    // panel around the row. The panel adds 12 of its own (see IslandPanel's
    // targetW/targetH), so this only has to cover the last 2 -- which is what
    // makes the visible inset read 14 rather than the 20 it used to.
    readonly property real tileWidth: 90
    readonly property real tileHeight: 81
    readonly property real tileSpacing: 8
    readonly property real containerPadding: 2

    
    
    
    
    
    
    implicitWidth: 5 * tileWidth + 4 * tileSpacing + 2 * containerPadding
    implicitHeight: tileHeight + 2 * containerPadding
    cornerRadius: 24

    
    
    
    backgroundColor: Theme.colors.background

    readonly property color accent: Theme.colors.accent
    readonly property color accentText: Theme.colors.accentText
    
    
    
    readonly property color tileInactiveBg: Theme.colors.surface
    readonly property color dangerColor: Theme.colors.danger

    signal actionTaken()

    
    property bool hyprlockAvailable: false
    property bool hyprshutdownAvailable: false

    Process {
        id: hyprlockProbe
        command: ["bash", "-c", "command -v hyprlock >/dev/null && echo yes || echo no"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => { if (line.trim() === "yes") root.hyprlockAvailable = true }
        }
    }
    Process {
        id: hyprshutdownProbe
        command: ["bash", "-c", "command -v hyprshutdown >/dev/null && echo yes || echo no"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => { if (line.trim() === "yes") root.hyprshutdownAvailable = true }
        }
    }
    Component.onCompleted: {
        hyprlockProbe.running = true;
        hyprshutdownProbe.running = true;
    }

    function lock() {
        if (root.hyprlockAvailable) {
            lockProc.command = ["hyprlock"];
            lockProc.running = true;
        } else {
            lockProc.command = ["loginctl", "lock-session"];
            lockProc.running = true;
        }
        root.actionTaken();
    }
    function suspend() {
        actionProc.command = ["systemctl", "suspend"];
        actionProc.running = true;
        root.actionTaken();
    }
    function logOut() {
        if (root.hyprshutdownAvailable) {
            actionProc.command = ["hyprshutdown"];
        } else {
            actionProc.command = ["hyprctl", "dispatch", "exit"];
        }
        actionProc.running = true;
        root.actionTaken();
    }
    function reboot() {
        if (root.hyprshutdownAvailable) {
            actionProc.command = ["hyprshutdown", "--post-cmd", "systemctl reboot"];
        } else {
            actionProc.command = ["systemctl", "reboot"];
        }
        actionProc.running = true;
        root.actionTaken();
    }
    function powerOff() {
        if (root.hyprshutdownAvailable) {
            actionProc.command = ["hyprshutdown", "--post-cmd", "systemctl poweroff"];
        } else {
            actionProc.command = ["systemctl", "poweroff"];
        }
        actionProc.running = true;
        root.actionTaken();
    }

    Process { id: lockProc }
    Process { id: actionProc }

    component PowerTile: Item {
        id: tile
        property string icon: ""
        property string label: ""
        property bool primary: false
        property bool needsConfirm: false
        signal activated()

        readonly property bool confirming: needsConfirm && confirmTimer.running
        readonly property bool isHovered: hoverHandler.hovered

        implicitWidth: root.tileWidth
        implicitHeight: root.tileHeight
        transformOrigin: Item.Center
        scale: tapHandler.pressed ? 0.94 : (isHovered ? 1.03 : 1.0)
        Behavior on scale { enabled: !MotionConfig.reduceMotion; SpringAnimation { spring: 5; damping: MotionConfig.springDamping; mass: 0.5 } }

        Timer { id: confirmTimer; interval: 3000 }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: tile.confirming ? root.dangerColor
                : (tile.primary ? root.accent 
                : (tile.isHovered ? Qt.lighter(root.tileInactiveBg, 1.25) : root.tileInactiveBg))
            Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: tile.confirming ? "warning" : tile.icon
                size: 22
                iconColor: (tile.primary || tile.confirming) ? root.accentText : Theme.withAlpha(Theme.colors.text, 0.9)
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: 12
                font.weight: tile.primary ? Font.DemiBold : Font.Medium
                text: tile.confirming ? "Confirm?" : tile.label
                textColor: (tile.primary || tile.confirming) ? root.accentText : Theme.withAlpha(Theme.colors.text, 0.88)
            }
        }

        HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: tapHandler
            onTapped: {
                if (!tile.needsConfirm) {
                    tile.activated();
                    return;
                }
                if (tile.confirming) {
                    confirmTimer.stop();
                    tile.activated();
                } else {
                    confirmTimer.restart();
                }
            }
        }
    }

    RowLayout {
        id: tileRow
        anchors.fill: parent
        anchors.margins: root.containerPadding
        spacing: root.tileSpacing

        PowerTile {
            icon: "lock"
            label: "Lock"
            onActivated: root.lock()
        }
        PowerTile {
            icon: "bedtime"
            label: "Suspend"
            onActivated: root.suspend()
        }
        PowerTile {
            icon: "logout"
            label: "Log Out"
            onActivated: root.logOut()
        }
        PowerTile {
            icon: "refresh"
            label: "Reboot"
            needsConfirm: true
            onActivated: root.reboot()
        }
        PowerTile {
            icon: "power_settings_new"
            label: "Power Off"
            primary: true
            needsConfirm: true
            onActivated: root.powerOff()
        }
    }
}
