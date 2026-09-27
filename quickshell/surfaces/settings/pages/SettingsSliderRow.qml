import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// SettingsSliderRow
// "Label ......... value unit" header row + a thin track-with-thumb
// slider below it, full width. This is the Settings app's own slider
// style — visually distinct from components/Slider.qml's pill-with-
// icon style (which is built for Control Center's compact OSD-style
// rows) — so it lives here, scoped to the settings pages that actually
// use it, rather than in components/.
Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property string suffix: ""
    property int decimals: 0

    signal moved(real value)

    implicitHeight: 56
    Layout.fillWidth: true

    readonly property real _fraction: (value - from) / (to - from)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: root.label }
            Item { Layout.fillWidth: true }
            StyledText {
                variant: "mediaSubtitle"
                text: root.value.toFixed(root.decimals) + root.suffix
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 20

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            Rectangle {
                id: fill
                anchors.verticalCenter: parent.verticalCenter
                width: track.width * root._fraction
                height: 4
                radius: 2
                color: Theme.colors.accent
                Behavior on width {
                    enabled: !dragArea.pressed && !MotionConfig.reduceMotion
                    SpringAnimation { spring: 3.4; damping: MotionConfig.springDamping; mass: 0.9 }
                }
            }

            Rectangle {
                id: thumb
                width: 16; height: 16
                radius: 8
                color: "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                scale: dragArea.pressed ? 1.15 : 1.0
                Behavior on scale { enabled: !MotionConfig.reduceMotion; SpringAnimation { spring: 6; damping: MotionConfig.springDamping; mass: 0.4 } }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.margins: -6

                function updateFromX(x) {
                    const f = Math.max(0, Math.min(1, x / width));
                    root.value = root.from + f * (root.to - root.from);
                    root.moved(root.value);
                }
                onPressed: (mouse) => updateFromX(mouse.x)
                onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
            }
        }
    }
}
