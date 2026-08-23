import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../core"

/** Image 12: flat power row, no further nesting. Each action shells out to
 *  a real system command -- loginctl/systemctl are used over raw `poweroff`
 *  etc. since they respect session/inhibitor locks properly. */
RowLayout {
    Layout.fillWidth: true
    spacing: 8

    component PowerButton: Rectangle {
        property string label: ""
        property string icon: ""
        property color tint: Theme.colors.surfaceHover
        signal tap()
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: 14
        color: tint
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            Text { text: icon; color: Theme.colors.text; font.pixelSize: Theme.fontSize + 4; font.family: Config.iconFontFamily; Layout.alignment: Qt.AlignHCenter }
            Text { text: label; color: Theme.colors.text; font.pixelSize: Theme.fontSize - 4; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignHCenter }
        }
        MouseArea { anchors.fill: parent; onClicked: parent.tap() }
    }

    PowerButton {
        label: "Lock"; icon: Config.iconLock; tint: Theme.colors.success
        onTap: { lockProcess.running = true; IslandState.onLock() }
    }
    PowerButton { label: "Suspend"; icon: Config.iconSuspend; onTap: suspendProcess.running = true }
    PowerButton { label: "Log Out"; icon: Config.iconLogout; onTap: logoutProcess.running = true }
    PowerButton { label: "Reboot"; icon: Config.iconReboot; onTap: rebootProcess.running = true }
    PowerButton { label: "Power Off"; icon: Config.iconPower; tint: Theme.colors.danger; onTap: poweroffProcess.running = true }

    Process { id: lockProcess; command: ["hyprlock"] }
    Process { id: suspendProcess; command: ["systemctl", "suspend"] }
    Process { id: logoutProcess; command: ["loginctl", "terminate-session", "self"] }
    Process { id: rebootProcess; command: ["systemctl", "reboot"] }
    Process { id: poweroffProcess; command: ["systemctl", "poweroff"] }
}
