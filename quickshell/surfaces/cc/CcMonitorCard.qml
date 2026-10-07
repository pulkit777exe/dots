import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

// One monitor: identity row, brightness slider, scale pills, resolution.

Rectangle {
    id: card

    property var monitor: null     // an entry of Brightness.monitorList

    radius: 15
    color: Theme.cc.item
    implicitHeight: col.implicitHeight + 20

    readonly property string name: monitor ? monitor.name : ""
    readonly property real brightness: monitor
        ? Brightness.monitorBrightness(monitor.name) / 100 : 0
    readonly property real monScale: monitor && monitor.scale > 0 ? monitor.scale : 1

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 10 }
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: card.monitor && card.monitor.focused
                    ? Theme.colors.accent : Theme.withAlpha(Theme.colors.text, 0.20)
                Behavior on color { ColorAnimation { duration: Config.hover() } }

                Icon {
                    anchors.centerIn: parent
                    icon: "monitor"
                    size: 15
                    iconColor: card.monitor && card.monitor.focused
                        ? Theme.colors.accentText : Theme.withAlpha(Theme.colors.text, 0.85)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: card.name
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                }
                Label {
                    text: card.monitor
                        ? card.monitor.width + "×" + card.monitor.height
                          + (card.monitor.hz > 0 ? "  ·  " + Math.round(card.monitor.hz) + " Hz" : "")
                        : ""
                    font.pixelSize: Theme.px(11)
                    color: Theme.withAlpha(Theme.colors.text, 0.48)
                }
            }

            Label {
                visible: card.monitor && card.monitor.focused
                text: "focused"
                font.pixelSize: Theme.px(11)
                color: Theme.colors.accent
            }
        }

        CcDeviceSlider {
            Layout.fillWidth: true
            icon: "wb_sunny"
            trackColor: Theme.cc.trackCard
            value: card.brightness
            onMoved: f => Brightness.setMonitorBrightness(card.name, f * 100)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: [1.0, 1.25, 1.5, 1.75, 2.0]

                Rectangle {
                    required property real modelData
                    readonly property bool selected:
                        Math.abs(card.monScale - modelData) < 0.05

                    height: 28
                    width: scaleLabel.implicitWidth + 20
                    radius: height / 2
                    color: selected ? Theme.colors.accent
                        : (scaleArea.containsMouse ? Theme.cc.itemHover
                           : Theme.withAlpha(Theme.colors.text, 0.12))
                    Behavior on color { ColorAnimation { duration: Config.hover() } }

                    Label {
                        id: scaleLabel
                        anchors.centerIn: parent
                        text: Number(modelData).toFixed(2).replace(/0$/, "") + "x"
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Medium
                        color: selected ? Theme.colors.accentText
                            : Theme.withAlpha(Theme.colors.text, 0.70)
                    }
                    MouseArea {
                        id: scaleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Brightness.setMonitorScale(card.name, modelData)
                    }
                }
            }
        }
    }
}
