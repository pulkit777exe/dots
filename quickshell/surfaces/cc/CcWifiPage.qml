import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"


// CcWifiPage.qml -- the control centre's Wi-Fi page.
//
// Extracted from ControlCenter.qml. The geometry, the slide-in and the
// fade are CcDrillPage's; what is left is this page's own content.
// `back()` goes to ControlCenter, which owns `view` -- a page does not
// know the name of the view it came from.

CcDrillPage {
    id: root

    property real inset: 10

    signal back()

    // Both of these used to reach into ControlCenter. The page does
    // not own the wifi state -- Wifi does -- nor the password flow,
    // so it asks for it instead.
    property string activeMeta: ""
    signal connectRequested(string ssid, bool secured)


    CcTokens { id: cc }


    contentHeight: wifiFlickContent.implicitHeight


    ColumnLayout {
        id: wifiFlickContent
        width: root.width
        spacing: 0
        Item { Layout.preferredHeight: 12 }

        CcSubPageHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            toggleVisible: true
            toggleOn: Wifi.enabled
            onBack: root.back()
            onToggled: Wifi.toggle()
        }

        Item { Layout.preferredHeight: 12 }

        Item { Layout.preferredHeight: 14 }


        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 13
            color: cc.bgItem
            border.color: Theme.colors.accent
            border.width: 1
            visible: Wifi.connected

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: width / 2
                    color: Theme.colors.accent

                    Icon {
                        anchors.centerIn: parent
                        icon: "wifi"
                        size: 20
                        iconColor: Theme.colors.accentText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: Wifi.ssid
                        font.pixelSize: 13; font.weight: Font.DemiBold; color: cc.textPrimary
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    StyledText {
                        text: root.activeMeta
                        font.pixelSize: 11; color: cc.textDim
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }


                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: wifiDisconnectLabel.implicitWidth + 24
                    radius: height / 2
                    color: "transparent"
                    border.color: cc.borderColor
                    border.width: 1
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { Wifi.disconnect() } }

                    StyledText {
                        id: wifiDisconnectLabel
                        anchors.centerIn: parent
                        text: "Disconnect"
                        font.pixelSize: 11
                        color: Theme.colors.accent
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 14 }


        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText { text: "Networks"; font.pixelSize: 11; color: cc.textDim }
            Item { Layout.fillWidth: true }
            RowLayout {
                spacing: 6
                visible: Wifi.scanning
                Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: Theme.colors.accent }
                StyledText { text: "Scanning"; font.pixelSize: 11; color: cc.textDim }
            }
        }

        Item { Layout.preferredHeight: 6 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {


                model: Wifi.networks.filter(n => !n.active)
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 48
                    radius: 12
                    color: wifiRowHover.hovered ? cc.bgItemHover : cc.bgItem
                    border.color: cc.bgPill
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                    HoverHandler { id: wifiRowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.connectRequested(modelData.ssid, modelData.secured) }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        Icon { icon: "wifi"; size: 16; iconColor: cc.textStrong }
                        StyledText { Layout.fillWidth: true; text: modelData.ssid; font.pixelSize: 13; color: cc.textPrimary; elide: Text.ElideRight }
                        StyledText { text: modelData.strength + "%"; font.pixelSize: 11; color: cc.textSub }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 6 }
    }
}
