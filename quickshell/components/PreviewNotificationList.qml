import QtQuick
import QtQuick.Layouts
import "../services"

// The arranger's stand-in for the notifications control: the card chrome, a
// "Clear all" affordance that is not wired up, and up to two real entries
// read straight from Notifications.active. With nothing to show it still
// renders one placeholder row, so the card keeps its height in an empty
// shell instead of collapsing to a header.
Item {
    id: root

    readonly property var shown: Notifications.active.slice(0, 2)
    implicitHeight: 40 + Math.max(1, shown.length) * 64

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Theme.withAlpha(Theme.colors.text, 0.055)
    }

    StyledText {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.topMargin: 13
        text: "Notifications"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Theme.colors.text
    }

    StyledText {
        anchors.top: head.top
        anchors.right: parent.right
        anchors.rightMargin: 16
        text: "Clear all"
        font.pixelSize: 12
        textColor: Theme.withAlpha(Theme.colors.text, 0.55)
    }

    Column {
        anchors.top: head.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Repeater {
            model: root.shown.length ? root.shown : [null]

            delegate: Rectangle {
                id: notifRow
                required property var modelData

                readonly property string sender: modelData
                    ? (modelData.appName || modelData.app || "notify-send") : "notify-send"
                readonly property string summary: modelData
                    ? (modelData.summary || modelData.title || "") : "All caught up"
                readonly property string body: modelData ? (modelData.body || "") : ""

                width: parent.width
                height: 56
                radius: 12
                color: Theme.withAlpha(Theme.colors.text, 0.035)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: Qt.alpha(Theme.colors.accent, 0.18)
                        StyledText {
                            anchors.centerIn: parent
                            text: notifRow.sender.slice(0, 1).toUpperCase()
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.colors.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: notifRow.sender
                            font.pixelSize: 10
                            textColor: Theme.withAlpha(Theme.colors.text, 0.5)
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: notifRow.summary
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: notifRow.body
                            font.pixelSize: 11
                            textColor: Theme.withAlpha(Theme.colors.text, 0.55)
                            elide: Text.ElideRight
                        }
                    }

                    Icon {
                        icon: "close"
                        size: 14
                        iconColor: Theme.withAlpha(Theme.colors.text, 0.4)
                    }
                }
            }
        }
    }
}
