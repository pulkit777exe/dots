import QtQuick
import QtQuick.Layouts
import "../services"


Rectangle {
    id: pill

    CcTokens { id: cc }

    // Where `originInRoot()` maps to. The panel, not this component's
    // own parent: the drill page's frame is between them.
    property Item panel


    height: 57
    radius: 16
    property bool active: false
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    signal clicked()


    function originInRoot() {
        return mapToItem(panel, width / 2, height / 2);
    }


    color: pillHover.hovered ? cc.bgCardHover : cc.bgCard
    border.color: cc.borderColor
    border.width: 1
    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

    scale: pillTap.pressed ? 0.97 : 1.0
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

    HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: pillTap; onTapped: pill.clicked() }

    RowLayout {
        anchors { fill: parent; leftMargin: 9; rightMargin: 11 }
        spacing: 9


        Rectangle {
            Layout.preferredWidth: 41
            Layout.preferredHeight: 41
            radius: width / 2
            color: pill.active ? Theme.colors.accent : cc.bgPill
            Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

            Icon {
                anchors.centerIn: parent
                icon: pill.icon
                size: 20
                iconColor: pill.active ? Theme.colors.accentText : cc.textIcon
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                text: pill.label
                font.pixelSize: 13; font.weight: Font.DemiBold; color: cc.textPrimary
                elide: Text.ElideRight; Layout.fillWidth: true
            }
            StyledText {
                text: pill.sublabel
                font.pixelSize: 11; color: cc.textSub
                elide: Text.ElideRight; Layout.fillWidth: true
                visible: text.length > 0
            }
        }
    }
}
