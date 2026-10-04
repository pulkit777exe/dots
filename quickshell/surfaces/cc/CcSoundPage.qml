import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"
import Quickshell.Services.Pipewire


// CcSoundPage.qml -- the control centre's Sound page.
//
// Extracted from ControlCenter.qml. The geometry, the slide-in and the
// fade are CcDrillPage's; what is left is this page's own content.
// `back()` goes to ControlCenter, which owns `view` -- a page does not
// know the name of the view it came from.

CcDrillPage {
    id: root

    property real inset: 22

    signal back()


    CcTokens { id: cc }


    contentHeight: soundFlickContent.implicitHeight


    Rectangle {
        anchors.fill: parent
        radius: 24
        color: cc.bgSurface
    }

    ColumnLayout {
        id: soundFlickContent
        width: root.width
        spacing: 0
        Item { Layout.preferredHeight: 12 }


        CcSubPageHeader {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            title: "Sound"
            onBack: root.back()
        }

        Item { Layout.preferredHeight: 8 }


        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            text: "Output"
            font.pixelSize: 11
            color: cc.textDim
        }
        Item { Layout.preferredHeight: 6 }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            spacing: 5

            Repeater {
                model: Volume.sinks
                delegate: CcDeviceRow {
                    required property var modelData
                    Layout.fillWidth: true
                    label: Volume.displayName(modelData)
                    icon: "speaker"
                    selected: Volume.isDefaultSink(modelData)
                    onPicked: Volume.setDefaultSink(modelData)
                }
            }
        }

        Item { Layout.preferredHeight: 8 }


        CcDeviceSlider {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            icon: Volume.muted ? "volume_off" : "volume_up"
            value: Volume.muted ? 0 : Volume.volumePercent
            onMoved: (f) => Volume.setVolume(f * 100)
        }

        Item { Layout.preferredHeight: 12 }


        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            text: "Input"
            font.pixelSize: 11
            color: cc.textDim
        }
        Item { Layout.preferredHeight: 6 }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            spacing: 5

            Repeater {
                model: Volume.sources
                delegate: CcDeviceRow {
                    required property var modelData
                    Layout.fillWidth: true
                    label: Volume.displayName(modelData)
                    icon: "mic"
                    selected: Volume.isDefaultSource(modelData)
                    onPicked: Volume.setDefaultSource(modelData)
                }
            }
        }

        Item { Layout.preferredHeight: 8 }


        CcDeviceSlider {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            icon: Volume.micMuted ? "mic_off" : "mic"
            value: Volume.micMuted ? 0 : Volume.micVolumePercent
            onMoved: (f) => Volume.setMicVolume(f * 100)
        }

        Item { Layout.preferredHeight: 12 }


        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            text: "Apps"
            font.pixelSize: 11
            color: cc.textDim
            visible: Volume.streams.length > 0
        }
        Item { Layout.preferredHeight: 6; visible: Volume.streams.length > 0 }


        Repeater {
            model: Volume.streams
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                Layout.preferredHeight: streamCol.implicitHeight + 16
                Layout.topMargin: 5
                radius: 13
                color: cc.bgItem
                border.color: cc.borderColor
                border.width: 1

                ColumnLayout {
                    id: streamCol
                    anchors { fill: parent; margins: 8 }
                    spacing: 6

                    StyledText {
                        text: Volume.displayName(modelData)
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: cc.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }


                    CcDeviceSlider {
                        Layout.fillWidth: true
                        onCard: true
                        icon: "volume_up"
                        value: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
                        onMoved: (f) => {
                            if (!modelData.audio) return;
                            modelData.audio.muted = false;
                            modelData.audio.volume = Math.max(0, Math.min(1, f));
                        }
                    }
                }
            }
        }


        StyledText {
            Layout.fillWidth: true
            visible: Volume.sinks.length === 0 && Volume.sources.length === 0
            text: Pipewire.ready ? "No audio devices found" : "Waiting for PipeWire…"
            font.pixelSize: 12
            color: cc.textDim
            horizontalAlignment: Text.AlignHCenter
        }

        Item { Layout.preferredHeight: 4 }
    }
}
