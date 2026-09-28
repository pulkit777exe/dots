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

    // 61, not 56. Measured off 2026-09-20_22-30-18: consecutive slider-row
    // label centres sit 62px apart and a divider takes 1 of those, so the row
    // is 61. Not a guess -- 8 slider rows x 61 + 3 toggle rows x 44 + 10
    // dividers = 630, which is exactly the reference card's height.
    implicitHeight: 61
    Layout.fillWidth: true

    readonly property real _fraction: (value - from) / (to - from)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                variant: "mediaTitle"
                font.pixelSize: 13
                text: root.label
                // Warm off-white -- (239,232,221) in the reference. The
                // mediaTitle variant's own rgba(1,1,1,0.95) is neutral and
                // reads a touch cold against it.
                textColor: Qt.rgba(1, 0.97, 0.925, 0.95)
            }
            Item { Layout.fillWidth: true }
            StyledText {
                // Same size as the label, not the mediaSubtitle 11 this used
                // to be: the reference's "33 px" stands 12px tall against the
                // label's 13. Muted to ~(149,145,139).
                font.pixelSize: 13
                text: root.value.toFixed(root.decimals) + root.suffix
                textColor: Qt.rgba(1, 0.98, 0.95, 0.55)
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
                // (44,40,37) over the card's (16,14,12) -- a warm white at
                // ~11%, the same value Toggle's off-track uses.
                color: Qt.rgba(1, 0.93, 0.88, 0.11)
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
                // 14px, the reference's knob diameter (2026-09-20_22-30-18
                // measures x 787..800), in the same cream as Toggle's.
                width: 14; height: 14
                radius: 7
                color: "#F6E2CB"
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
