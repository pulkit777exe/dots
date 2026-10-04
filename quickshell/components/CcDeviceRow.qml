import QtQuick
import QtQuick.Layouts
import "../services"


Rectangle {
    id: devRow

    CcTokens { id: cc }

    property string label: ""
    property string icon: "speaker"
    property bool selected: false
    signal picked()


    Layout.preferredHeight: 40
    radius: 12
    color: devHover.hovered ? cc.bgItemHover : cc.bgItem
    border.color: cc.borderColor
    border.width: 1

    HoverHandler { id: devHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: devRow.picked() }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
        spacing: 10


        Rectangle {
            Layout.preferredWidth: 29
            Layout.preferredHeight: 29
            radius: width / 2
            color: devRow.selected ? Theme.colors.accent : cc.bgBadgeDim
            Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

            Icon {
                anchors.centerIn: parent
                icon: devRow.icon
                size: 14
                iconColor: devRow.selected ? Theme.colors.accentText : cc.textStrong
            }
        }

        StyledText {
            text: devRow.label
            font.pixelSize: 14
            color: cc.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Icon {
            visible: devRow.selected
            icon: "check"
            size: 14
            iconColor: Theme.colors.accent
        }
    }
}
