import QtQuick
import QtQuick.Layouts
import "../../core"

/**
 * iOS/macOS-style toggle switch.
 * Pill track with a sliding circular knob.
 * Used in WifiPanel, BluetoothPanel headers.
 */
Rectangle {
    id: root
    property bool checked: false
    signal toggled()

    implicitWidth: Config.toggleWidth
    implicitHeight: Config.toggleHeight
    radius: height / 2
    color: checked ? Theme.colors.accent : Theme.colors.surfaceHover

    Behavior on color { ColorAnimation { duration: Config.animNormal } }

    Rectangle {
        id: knob
        width: root.height - 6
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: Theme.colors.bg

        Behavior on x {
            NumberAnimation { duration: Config.animNormal; easing.type: Easing.InOutQuad }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // NOTE: only emit `toggled` -- never assign root.checked here.
        // `checked` is meant to be bound by the caller (e.g.
        // `checked: NetworkService.wifiEnabled`); assigning it imperatively
        // from inside would permanently break that binding after the first
        // click, leaving the knob stuck showing whatever it was clicked to
        // rather than the real service state.
        onClicked: root.toggled()
    }
}
