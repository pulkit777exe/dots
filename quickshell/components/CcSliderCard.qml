import QtQuick
import QtQuick.Layouts
import "../services"


Rectangle {
    id: sc

    CcTokens { id: cc }

    // Where `originInRoot()` maps to. The panel, not this component's
    // own parent: the drill page's frame is between them.
    property Item panel

    height: 52; radius: 14
    color: cc.bgCard
    border.color: cc.borderColor
    border.width: 1

    property string cardLabel: ""
    property string sliderIcon: ""
    property real sliderValue: 0.5
    property bool chevronVisible: false
    signal sliderMoved(real fraction)
    signal sliderScrolled(int delta)
    signal chevronClicked()

    function originInRoot() {
        return mapToItem(panel, width / 2, height / 2);
    }

    ColumnLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 7; bottomMargin: 7 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: sc.cardLabel; font.pixelSize: 13; font.weight: Font.DemiBold; color: cc.textPrimary }
            Item { Layout.fillWidth: true }
            Icon {
                visible: sc.chevronVisible
                icon: "chevron_right"; size: 15; iconColor: cc.textSub
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: sc.chevronClicked() }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 23

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: cc.bgSliderTrack
                clip: true

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, sc.sliderValue)))
                    radius: parent.radius
                    color: Theme.colors.accent
                    Behavior on width {
                        enabled: !sliderMouse.pressed && !MotionConfig.reduceMotion
                        SpringAnimation { spring: 3.6; damping: MotionConfig.springDamping; mass: 0.9 }
                    }
                }

                Icon {
                    anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                    icon: sc.sliderIcon; size: 14; iconColor: cc.onAccent
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function set(mx) {
                    sc.sliderMoved(Math.max(0, Math.min(1, mx / width)))
                }
                onPressed: (e) => set(e.x)
                onPositionChanged: (e) => { if (pressed) set(e.x) }
                onWheel: (e) => sc.sliderScrolled(e.angleDelta.y > 0 ? 1 : -1)
            }
        }
    }
}
