import QtQuick
import QtQuick.Layouts
import "../services"

// Thin overlay scroll rail for a Flickable. Hides itself when the content
// fits, fades in while scrolling. Used by the control-center pages and the
// notification list so long content stays inside a fixed-size box.
Item {
    id: root

    property Flickable flickable: null
    property color accent: Theme.colors.accent

    readonly property bool needed: !!flickable && flickable.contentHeight > flickable.height + 1
    readonly property real maxOffset: needed ? flickable.contentHeight - flickable.height : 0
    readonly property real thumbHeight: needed
        ? Math.max(20, height * flickable.height / flickable.contentHeight) : 0

    Layout.preferredWidth: 3
    Layout.fillHeight: true
    visible: needed
    opacity: flickable && flickable.movingVertically ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: Config.hover() } }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.withAlpha(Theme.colors.text, 0.08)
    }

    Rectangle {
        width: parent.width
        height: root.thumbHeight
        radius: width / 2
        color: root.accent
        y: root.maxOffset > 0
            ? (root.height - height) * Math.max(0, Math.min(1, root.flickable.contentY / root.maxOffset))
            : 0
        Behavior on y {
            enabled: !root.flickable || !root.flickable.movingVertically
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }
}
