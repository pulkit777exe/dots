import QtQuick
import QtQuick.Layouts
import "../services"


Rectangle {
    id: devSlider

    CcTokens { id: cc }

    property string icon: "volume_up"
    property real value: 0


    property bool onCard: false
    signal moved(real fraction)


    Layout.preferredHeight: 26
    radius: 12
    color: "transparent"
    border.width: 0

    Item {
        id: devTrack
        anchors.left: parent.left
        anchors.right: pct.left
        anchors.rightMargin: 17
        anchors.verticalCenter: parent.verticalCenter
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: devSlider.onCard ? cc.bgSliderTrackCard : cc.bgSliderTrack

            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, devSlider.value / 100)))
                radius: parent.radius
                color: Theme.colors.accent
                Behavior on width {
                    enabled: !devMouse.pressed && !MotionConfig.reduceMotion
                    SpringAnimation { spring: 3.6; damping: MotionConfig.springDamping; mass: 0.9 }
                }
            }

            Icon {
                anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                icon: devSlider.icon
                size: 14
                iconColor: cc.onAccent
            }
        }

        MouseArea {
            id: devMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function set(mx) { devSlider.moved(Math.max(0, Math.min(1, mx / width))); }
            onPressed: (e) => set(e.x)
            onPositionChanged: (e) => { if (pressed) set(e.x); }
        }
    }

    StyledText {
        id: pct
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(devSlider.value) + "%"
        font.pixelSize: 12
        color: cc.textMedium
        horizontalAlignment: Text.AlignRight
    }
}
