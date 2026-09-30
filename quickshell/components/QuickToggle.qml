import QtQuick
import "../services"













Item {
    id: root

    property string icon: ""
    property bool active: false
    property bool momentary: false
    property color accentColor: Theme.colors.accent
    property color accentTextColor: Theme.colors.accentText

    signal clicked()

    width: 44
    height: 44

    readonly property bool filled: active && !momentary

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        
        color: root.filled ? root.accentColor
            : (tapHandler.pressed ? Qt.lighter(Theme.surfaceRaised, 1.3) : (hoverHandler.hovered ? Theme.colors.surfaceAlt : Theme.colors.surface))
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
    }

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        size: 18
        iconColor: root.filled ? root.accentTextColor : Qt.rgba(1, 1, 1, 0.88)
        Behavior on iconColor { ColorAnimation { duration: MotionConfig.hover() } }
    }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tapHandler; onTapped: root.clicked() }
}
