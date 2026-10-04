import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"








Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property string suffix: ""
    property int decimals: 0

    signal moved(real value)

    
    
    
    
    implicitHeight: 61
    Layout.fillWidth: true

    readonly property real fraction: (value - from) / (to - from)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                variant: "mediaTitle"
                font.pixelSize: 13
                text: root.label
                
                
                
                textColor: Theme.withAlpha(Theme.colors.text, 0.9)
            }
            Item { Layout.fillWidth: true }
            StyledText {
                
                
                
                font.pixelSize: 13
                text: root.value.toFixed(root.decimals) + root.suffix
                textColor: Theme.withAlpha(Theme.colors.text, 0.5)
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
                
                
                color: Theme.colors.surfaceAlt
            }

            Rectangle {
                id: fill
                anchors.verticalCenter: parent.verticalCenter
                width: track.width * root.fraction
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
                
                
                width: 14; height: 14
                radius: 7
                color: Theme.colors.text
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
