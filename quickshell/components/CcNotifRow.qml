import QtQuick
import QtQuick.Layouts
import "../services"


Rectangle {
    id: nr

    CcTokens { id: cc }

    height: 64; radius: 12
    property var notif: ({})
    signal dismissed()

    color: cc.bgItem
    border.color: cc.borderColor
    border.width: 1

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
            color: cc.bgCardActive
            StyledText {
                anchors.centerIn: parent
                text: (nr.notif.appName || "?").charAt(0).toUpperCase()
                font.pixelSize: 14; font.weight: Font.Bold; color: Theme.colors.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText { text: nr.notif.appName || ""; font.pixelSize: 10; color: cc.textDim }
            StyledText { text: nr.notif.summary || ""; font.pixelSize: 13; font.weight: Font.DemiBold; color: cc.textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }
            StyledText { text: nr.notif.body || ""; font.pixelSize: 11; color: cc.textSub; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 1 }
        }

        Item {
            Layout.preferredWidth: 26; Layout.preferredHeight: 26
            HoverHandler { id: xHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: nr.dismissed() }
            Icon { anchors.centerIn: parent; icon: "close"; size: 14; iconColor: cc.textDim }
        }
    }
}
