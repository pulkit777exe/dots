import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"





Surface {
    id: root

    width: 550
    cornerRadius: 20
    backgroundColor: Theme.panelFill
    shadow: false

    property color accent: Theme.colors.accent
    property color accentText: Theme.colors.accentText

    property var outputDevices: [
        "Raptor Lake-P/U/H cAVS HDMI / DisplayPort 3 Output",
        "Raptor Lake-P/U/H cAVS HDMI / DisplayPort 2 Output",
        "Raptor Lake-P/U/H cAVS HDMI / DisplayPort 1 Output",
        "Raptor Lake-P/U/H cAVS Headphones",
        "Blue Microphones Analog Stereo"
    ]
    property int selectedOutput: 2
    property real outputVolume: 51

    property var inputDevices: [
        "Raptor Lake-P/U/H cAVS Stereo Microphone",
        "Raptor Lake-P/U/H cAVS Digital Microphone",
        "Blue Microphones Analog Stereo"
    ]
    property int selectedInput: 2
    property real inputVolume: 62

    signal backRequested()
    signal outputSelected(int index)
    signal inputSelected(int index)
    signal outputVolumeMoved(real value)
    signal inputVolumeMoved(real value)

    implicitHeight: column.implicitHeight + 32

    component DeviceRow: Item {
        id: row
        property string label: ""
        property bool selected: false
        signal clicked()

        implicitHeight: 44

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: row.selected ? root.accent : (hoverHandler.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05))
            Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                variant: "mediaSubtitle"
                font.pixelSize: 13
                elide: Text.ElideRight
                text: row.label
                textColor: row.selected ? root.accentText : Qt.rgba(1, 1, 1, 0.85)
            }

            Icon {
                visible: row.selected
                icon: "check"
                size: 14
                iconColor: root.accentText
            }
        }

        HoverHandler { id: hoverHandler; enabled: !row.selected; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.clicked() }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            spacing: 12

            IconButton {
                icon: "arrow_back"
                size: 34
                iconSize: 16
                onClicked: root.backRequested()
            }

            StyledText {
                variant: "mediaTitle"
                font.pixelSize: 18
                text: "Audio"
            }
        }

        StyledText {
            variant: "mediaArtist"
            font.capitalization: Font.MixedCase
            font.letterSpacing: 0
            text: "Output device"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.outputDevices
                DeviceRow {
                    Layout.fillWidth: true
                    label: modelData
                    selected: index === root.selectedOutput
                    onClicked: { root.selectedOutput = index; root.outputSelected(index) }
                }
            }

            Slider {
                Layout.fillWidth: true
                Layout.topMargin: 4
                icon: root.outputVolume === 0 ? "volume_off"
                    : (root.outputVolume < 50 ? "volume_down" : "volume_up")
                accentColor: root.accent
                value: root.outputVolume
                
                onMoved: (v) => root.outputVolumeMoved(v)
            }
        }

        StyledText {
            Layout.topMargin: 4
            variant: "mediaArtist"
            font.capitalization: Font.MixedCase
            font.letterSpacing: 0
            text: "Input device"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.inputDevices
                DeviceRow {
                    Layout.fillWidth: true
                    label: modelData
                    selected: index === root.selectedInput
                    onClicked: { root.selectedInput = index; root.inputSelected(index) }
                }
            }

            Slider {
                Layout.fillWidth: true
                Layout.topMargin: 4
                icon: root.inputVolume === 0 ? "mic_off" : "mic"
                accentColor: root.accent
                value: root.inputVolume
                onMoved: (v) => root.inputVolumeMoved(v)
            }
        }
    }
}
