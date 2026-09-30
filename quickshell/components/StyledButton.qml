import QtQuick
import "../services"





Item {
    id: root

    property string text: ""
    property string variant: "filled"   
    property color accentColor: Theme.colors.accent
    property color filledTextColor: Theme.colors.accentText
    property color ghostTextColor: Qt.rgba(1, 1, 1, 0.85)
    property bool enabled: true

    signal clicked()

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 36
    opacity: enabled ? 1 : 0.4
    Behavior on opacity { OpacityAnimator { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: {
            if (root.variant === "filled") {
                return mouseArea.pressed ? Qt.darker(root.accentColor, 1.12) : root.accentColor
            }
            if (root.variant === "ghost" || root.variant === "secondary") {
                if (mouseArea.pressed) return Qt.rgba(1, 1, 1, 0.18)
                if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.14)
                return Qt.rgba(1, 1, 1, 0.08)
            }
            return mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
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
