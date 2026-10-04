import QtQuick
import "../services"

Item {
    id: root

    property string icon: "play_arrow"
    property int size: 28
    property int iconSize: 14
    property color iconColor: Theme.withAlpha(Theme.colors.text, 0.92)
    property color hoverColor: Theme.withAlpha(Theme.colors.text, 0.12)
    property color pressedColor: Theme.withAlpha(Theme.colors.text, 0.2)
    property bool primary: false
    property bool enabled: true

    signal clicked()

    width: size
    height: size
    opacity: enabled ? 1 : 0.35
    Behavior on opacity { OpacityAnimator { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: {
            if (root.primary) {
                if (mouseArea.pressed) return Qt.darker(Theme.colors.accent, 1.1)
                if (mouseArea.containsMouse) return Qt.lighter(Theme.colors.accent, 1.08)
                return Theme.colors.accent
            }
            return mouseArea.pressed
                ? root.pressedColor
                : (mouseArea.containsMouse ? root.hoverColor : "transparent")
        }

        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
    }

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        iconColor: root.primary ? Theme.colors.accentText : root.iconColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
