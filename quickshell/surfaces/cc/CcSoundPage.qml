import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

CcPage {
    id: page
    sideMargin: 15

    CcHeader {
        Layout.fillWidth: true
        title: "Sound"
        onBack: page.back()
    }

    Item { Layout.preferredHeight: 8; Layout.fillWidth: true }

    Label {
        text: "Output"
        font.pixelSize: Theme.px(11)
        color: Theme.withAlpha(Theme.colors.text, 0.48)
    }
    Item { Layout.preferredHeight: 6; Layout.fillWidth: true }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: Volume.sinks
            CcDeviceRow {
                required property var modelData
                Layout.fillWidth: true
                label: Volume.displayName(modelData)
                icon: "speaker"
                selected: Volume.isDefaultSink(modelData)
                onPicked: Volume.setDefaultSink(modelData)
            }
        }
    }

    Item { Layout.preferredHeight: 8; Layout.fillWidth: true }

    CcDeviceSlider {
        Layout.fillWidth: true
        icon: Volume.muted ? "volume_off" : "volume_up"
        value: Volume.muted ? 0 : Volume.volume
        onMoved: f => Volume.setVolume(f * 100)
    }

    Item { Layout.preferredHeight: 12; Layout.fillWidth: true }

    Label {
        text: "Input"
        font.pixelSize: Theme.px(11)
        color: Theme.withAlpha(Theme.colors.text, 0.48)
    }
    Item { Layout.preferredHeight: 6; Layout.fillWidth: true }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: Volume.sources
            CcDeviceRow {
                required property var modelData
                Layout.fillWidth: true
                label: Volume.displayName(modelData)
                icon: "mic"
                selected: Volume.isDefaultSource(modelData)
                onPicked: Volume.setDefaultSource(modelData)
            }
        }
    }

    Item { Layout.preferredHeight: 8; Layout.fillWidth: true }

    CcDeviceSlider {
        Layout.fillWidth: true
        icon: Volume.micMuted ? "mic_off" : "mic"
        value: Volume.micMuted ? 0 : Volume.micVolume
        onMoved: f => Volume.setMicVolume(f * 100)
    }

    Item {
        Layout.preferredHeight: 12
        Layout.fillWidth: true
        visible: Volume.streams.length > 0
    }

    Label {
        visible: Volume.streams.length > 0
        text: "Apps"
        font.pixelSize: Theme.px(11)
        color: Theme.withAlpha(Theme.colors.text, 0.48)
    }
    Item { Layout.preferredHeight: 6; Layout.fillWidth: true; visible: Volume.streams.length > 0 }

    Repeater {
        model: Volume.streams
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: 5
            Layout.preferredHeight: streamCol.implicitHeight + 16
            radius: 13
            color: Theme.cc.item
            border.color: Theme.cc.border
            border.width: 1

            ColumnLayout {
                id: streamCol
                anchors { fill: parent; margins: 8 }
                spacing: 6

                Label {
                    Layout.fillWidth: true
                    text: Volume.displayName(modelData)
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.Medium
                    color: Theme.colors.text
                    elide: Text.ElideRight
                }

                CcDeviceSlider {
                    Layout.fillWidth: true
                    trackColor: Theme.cc.trackCard
                    icon: "volume_up"
                    value: modelData.audio ? modelData.audio.volume : 0
                    onMoved: f => {
                        if (!modelData.audio) return;
                        modelData.audio.muted = false;
                        modelData.audio.volume = Math.max(0, Math.min(1, f));
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: Volume.sinks.length === 0 && Volume.sources.length === 0
        text: "No audio devices found"
        font.pixelSize: Theme.px(12)
        color: Theme.withAlpha(Theme.colors.text, 0.48)
        horizontalAlignment: Text.AlignHCenter
    }

    Item { Layout.preferredHeight: 4; Layout.fillWidth: true }
}
