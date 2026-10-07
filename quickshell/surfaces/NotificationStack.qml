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
                implicitHeight: row.implicitHeight + 24

                cornerRadius: 15
                backgroundColor: Theme.cc.card
                borderColor: entry.urgent ? Theme.colors.accent : Theme.cc.border

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
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 37
                        Layout.preferredHeight: 37
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: Theme.cc.item

                        Icon {
                            anchors.centerIn: parent
                            icon: card.entry.appIcon || "notifications"
                            size: 18
                            iconColor: Theme.colors.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Label {
                            Layout.fillWidth: true
                            text: card.entry.summary || card.entry.appName
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: Config.notifShowBodyText && card.entry.body !== ""
                            text: card.entry.body
                            font.pixelSize: Theme.px(11)
                            color: Theme.withAlpha(Theme.colors.text, 0.55)
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
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
