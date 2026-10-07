import QtQuick
import "../services"

// The frame every popup shares: the island's panel, re-purposed as a
// floating surface. Owns the open/closed presentation (fade + slide from
// under the bar), keyboard focus, and the Escape contract: back one level
// in a drill, close otherwise.
//
// A surface sets `open` to its UiState mode and `topY` where it differs
// from the default (only the settings app does).

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
