import QtQuick
import QtQuick.Layouts
import "../services"


RowLayout {
    id: sph

    CcTokens { id: cc }

    property string title: ""
    property string icon: ""
    property bool toggleVisible: false
    property bool toggleOn: false
    signal back()
    signal toggled()

    spacing: 12


    Rectangle {
        id: backBtn
        Layout.preferredWidth: 23; Layout.preferredHeight: 23; radius: width / 2
        color: backHover.hovered ? cc.bgItemHover : cc.bgItem
        border.color: cc.borderColor
        border.width: 1
        HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sph.back() }
        Icon {
            anchors.centerIn: parent
            icon: "chevron_left"
            size: 14
            iconColor: cc.textIcon
        }
    }

    StyledText {
        text: sph.title
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: cc.textPrimary
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    Toggle {
        visible: sph.toggleVisible
        checked: sph.toggleOn
        onToggled: sph.toggled()
    }
}
