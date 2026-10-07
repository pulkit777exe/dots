import QtQuick
import "../services"





Item {
    id: root

    property string text: ""
    property string variant: "filled"   
    property color accentColor: Theme.colors.accent
    property color filledTextColor: Theme.colors.accentText
    property color ghostTextColor: Theme.withAlpha(Theme.colors.text, 0.85)
    property bool enabled: true

    signal clicked()

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 36
    opacity: enabled ? 1 : 0.4
    scale: mouseArea.pressed ? 0.96 : 1.0
    Behavior on opacity { OpacityAnimator { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
    Behavior on scale {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: {
            if (root.variant === "filled") {
                return mouseArea.pressed ? Qt.darker(root.accentColor, 1.12) : root.accentColor
            }
            if (root.variant === "ghost" || root.variant === "secondary") {
                if (mouseArea.pressed) return Theme.withAlpha(Theme.colors.text, 0.18)
                if (mouseArea.containsMouse) return Theme.withAlpha(Theme.colors.text, 0.14)
                return Theme.withAlpha(Theme.colors.text, 0.08)
            }
            return mouseArea.containsMouse ? Theme.withAlpha(Theme.colors.text, 0.08) : "transparent"
        }
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        variant: "mediaTitle"
        font.pixelSize: 13
        text: root.text
        textColor: root.variant === "filled" ? root.filledTextColor : root.ghostTextColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
