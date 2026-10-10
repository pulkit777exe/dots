import QtQuick
import "../services"

Surface {
    id: panel

    property bool open: false
    property real topY: 11
    readonly property real pillRadius: Math.min(Config.collapsedRadius, Config.barHeight / 2)

    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    y: topY
    transformOrigin: Item.Top
    scale: open ? 1 : 0.6

    focus: open
    Keys.onEscapePressed: UiState.back()

    Behavior on opacity {
        NumberAnimation { duration: open ? Config.fade(0.6) : Config.fade(1.5); easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: open ? 5.5 : 4.0; damping: Config.springDamping; mass: 0.5 }
    }
    Behavior on cornerRadius {
        enabled: !Config.reduceMotion
        NumberAnimation { duration: Config.movement(); easing.type: Easing.OutQuint }
    }
}
