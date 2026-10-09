import QtQuick
import "../services"

Surface {
    id: panel

    property bool open: false
    property real topY: 11

    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    y: open ? topY : topY - 22

    focus: open
    Keys.onEscapePressed: UiState.back()

    Behavior on opacity {
        NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !Config.reduceMotion
        NumberAnimation { duration: Config.movement(0.65); easing.type: Easing.OutCubic }
    }
}
