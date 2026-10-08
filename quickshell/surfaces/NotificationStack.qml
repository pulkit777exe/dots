import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// Live toasts: one card each, expired by the service, dismissed on the cross.

Item {
    id: root

    width: Config.notifWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            model: Notifications.toasts

            delegate: Surface {
                id: card

                required property var modelData

                readonly property var resolved: Notifications.entryFor(modelData.key)
                readonly property bool live: resolved !== null
                readonly property var entry: resolved
                    || ({ appName: "", appIcon: "", summary: "", body: "", urgent: false })

                Layout.fillWidth: true
                visible: live
                implicitHeight: row.implicitHeight + 16

                cornerRadius: 15
                backgroundColor: Theme.colors.background
                borderColor: entry.urgent ? Theme.accentFor("notifications") : Theme.cc.border

                // Slide in from the right, under a fade.
                opacity: 0
                transform: Translate { id: slide; x: 28 }

                ParallelAnimation {
                    id: appear
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 1
                        duration: Config.fade()
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: slide
                        property: "x"
                        to: 0
                        duration: Config.movement(0.7)
                        easing.type: Easing.OutCubic
                    }
                }
                Component.onCompleted: {
                    if (Config.reduceMotion) {
                        card.opacity = 1;
                        slide.x = 0;
                    } else {
                        appear.start();
                    }
                }

                HoverHandler { id: hover }

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: Theme.cc.item

                        // The app's icon when it has one, its initial when
                        // it does not -- notify-send and friends ship none.
                        Icon {
                            anchors.centerIn: parent
                            visible: card.entry.appIcon !== ""
                            icon: card.entry.appIcon
                            size: 16
                            iconColor: Theme.accentFor("notifications")
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: card.entry.appIcon === ""
                            text: (card.entry.appName || card.entry.summary || "?").charAt(0).toUpperCase()
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                            color: Theme.accentFor("notifications")
                        }
                    }

                    NotificationText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        sender: card.entry.appName
                        summary: card.entry.summary || card.entry.appName
                        body: card.entry.body
                    }

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        opacity: hover.hovered ? 1 : 0
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: Config.fade() } }

                        Icon {
                            anchors.centerIn: parent
                            icon: "close"
                            size: 15
                            iconColor: Theme.withAlpha(Theme.colors.text, 0.55)
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Notifications.dismiss(card.modelData.key) }
                    }
                }
            }
        }
    }
}
