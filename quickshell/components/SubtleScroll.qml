import QtQuick
import "../services"





























Item {
    id: ind

    
    
    
    property Flickable flickable

    
    property int inset: 3

    readonly property bool needed:
        flickable !== null && flickable.contentHeight > flickable.height + 1
    readonly property real track: Math.max(1, height - inset * 2)
    
    
    readonly property real barSize: Math.max(20, track *
        (flickable ? flickable.height / Math.max(1, flickable.contentHeight) : 1))
    readonly property real travel:
        flickable ? Math.max(0, flickable.contentHeight - flickable.height) : 0
    readonly property real pos: travel > 0
        ? Math.max(0, Math.min(1, flickable.contentY / travel))
        : 0

    width: 3
    visible: needed
    z: 40

    Rectangle {
        id: bar
        width: 3
        height: ind.barSize
        radius: 1.5
        y: ind.inset + (ind.track - height) * ind.pos
        color: ind.containsMouse ? Theme.colors.accent : Theme.withAlpha(Theme.colors.text, 0.5)
        opacity: 0.18

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    states: State {
        name: "lit"
        when: ind.containsMouse || (ind.flickable && ind.flickable.moving)
        PropertyChanges { target: bar; opacity: 0.55 }
    }

    HoverHandler { id: hover; cursorShape: Qt.ArrowCursor }

    readonly property bool containsMouse: hover.hovered
}
