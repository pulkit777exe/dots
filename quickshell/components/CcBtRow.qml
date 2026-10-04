import QtQuick
import QtQuick.Layouts
import "../services"


Rectangle {
    id: cbr

    CcTokens { id: cc }

    property var device: ({})
    signal connect()
    signal disconnect()
    signal pair()

    Layout.preferredHeight: 46
    radius: 12
    color: cbrHover.hovered ? cc.bgItemHover : cc.bgItem
    border.color: cbr.device.connected ? Theme.colors.accent : cc.borderColor
    border.width: 1
    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

    HoverHandler { id: cbrHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        onTapped: {
            if (cbr.device.connected) cbr.disconnect()
            else if (cbr.device.paired) cbr.connect()
            else cbr.pair()
        }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: width / 2
            color: cbr.device.connected ? Theme.colors.accent : cc.bgPill
            Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

            Icon {
                anchors.centerIn: parent


                icon: cbr.device.paired ? "headphones" : "bluetooth"
                size: 15
                iconColor: cbr.device.connected ? Theme.colors.accentText : cc.textStrong
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                text: cbr.device.name || cbr.device.mac
                font.pixelSize: 12; color: cc.textPrimary
                elide: Text.ElideRight; Layout.fillWidth: true
            }
            StyledText {
                text: cbr.device.connected ? "Connected" : (cbr.device.paired ? "Saved" : "Not paired")
                font.pixelSize: 11; color: cc.textDim
            }
        }


        StyledText {
            text: cbr.device.connected ? "Disconnect" : (cbr.device.paired ? "Connect" : "Pair")
            font.pixelSize: 11
            color: Theme.colors.accent
        }
    }
}
