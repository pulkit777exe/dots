import QtQuick
import "../services"


Rectangle {
    id: iconBtn

    CcTokens { id: cc }

    // Where `originInRoot()` maps to. The panel, not this component's
    // own parent: the drill page's frame is between them.
    property Item panel


    width: 60; height: 60; radius: width / 2
    property string icon: ""
    property bool active: false
    signal clicked()

    color: active
        ? cc.bgCardActive
        : (iconBtnHover.hovered ? cc.bgCardHover : cc.bgCard)
    border.color: cc.borderColor
    border.width: 1
    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

    scale: iconBtnTap.pressed ? 0.95 : 1.0
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

    HoverHandler { id: iconBtnHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: iconBtnTap; onTapped: iconBtn.clicked() }

    Icon {
        anchors.centerIn: parent
        icon: iconBtn.icon
        size: 19
        iconColor: iconBtn.active ? Theme.colors.accent : cc.textIcon
    }
}
