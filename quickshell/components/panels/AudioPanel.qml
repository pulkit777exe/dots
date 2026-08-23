import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"
import "../ui"

/** Image 8: output/input device pickers with volume sliders. */
ColumnLayout {
    Layout.fillWidth: true
    spacing: 12

    Text { text: "Output device"; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 3 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: AudioService.outputs
            delegate: Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 10
                color: modelData.active ? Theme.colors.accent : Theme.colors.surfaceHover

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioService.setDevice(modelData.id)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    Text {
                        text: modelData.name
                        color: modelData.active ? Theme.colors.bg : Theme.colors.text
                        font.pixelSize: Theme.fontSize - 2
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.active
                        text: Config.iconSuccess
                        color: modelData.active ? Theme.colors.bg : Theme.colors.text
                        font.pixelSize: Theme.fontSize
                        font.family: Config.iconFontFamily
                    }
                }
            }
        }
        Text {
            visible: AudioService.outputs.length === 0
            text: "No output devices found"
            color: Theme.colors.textMuted
            font.pixelSize: Theme.fontSize - 4
            font.italic: true
        }
    }

    Text { text: "Volume"; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 3 }
    Slider01 {
        Layout.fillWidth: true
        value: AudioService.volume / 100
        onMoved: (v) => AudioService.setVolume(Math.round(v * 100))
    }

    Text { text: "Input device"; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 3 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: AudioService.inputs
            delegate: Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 10
                color: modelData.active ? Theme.colors.accent : Theme.colors.surfaceHover

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioService.setDevice(modelData.id)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    Text {
                        text: modelData.name
                        color: modelData.active ? Theme.colors.bg : Theme.colors.text
                        font.pixelSize: Theme.fontSize - 2
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.active
                        text: Config.iconSuccess
                        color: modelData.active ? Theme.colors.bg : Theme.colors.text
                        font.pixelSize: Theme.fontSize
                        font.family: Config.iconFontFamily
                    }
                }
            }
        }
    }

    Text { text: "Input volume"; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 3 }
    Slider01 {
        Layout.fillWidth: true
        value: AudioService.inputMuted ? 0 : AudioService.inputVolume / 100
        onMoved: (v) => AudioService.setInputVolume(Math.round(v * 100))
    }
}
