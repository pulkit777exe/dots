import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../core"
import "../../services"
import "."

/** Media player card inside Control Center (Image 2), with audio output label,
 *  scrubber + prev/play/next. */
ColumnLayout {
    id: root
    spacing: 6

    // Audio output device label
    Text {
        visible: AudioService.activeOutputName !== ""
        text: AudioService.activeOutputName
        color: Theme.colors.textMuted
        font.pixelSize: Theme.fontSize - 4
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    // Track info + controls
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            width: 40; height: 40; radius: 8
            color: Theme.colors.surfaceHover
            Image { anchors.fill: parent; source: MprisService.artUrl; fillMode: Image.PreserveAspectCrop; visible: MprisService.artUrl !== "" }
        }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Text { text: MprisService.title; color: Theme.colors.text; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: MprisService.artist; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        RowLayout {
            spacing: 4
            Text {
                text: Config.iconPrev
                color: Theme.colors.text
                font.family: Config.iconFontFamily
                font.pixelSize: Theme.fontSize + 2
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: MprisService.previous() }
            }
            Rectangle {
                width: 28; height: 28; radius: 14; color: Theme.colors.accent
                Text {
                    anchors.centerIn: parent
                    text: MprisService.playbackStatus === "Playing" ? Config.iconPause : Config.iconPlay
                    color: Theme.colors.bg
                    font.family: Config.iconFontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
                MouseArea { anchors.fill: parent; onClicked: MprisService.togglePlay() }
            }
            Text {
                text: Config.iconNext
                color: Theme.colors.text
                font.family: Config.iconFontFamily
                font.pixelSize: Theme.fontSize + 2
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: MprisService.next() }
            }
        }
    }

    // Progress bar / scrubber
    Slider01 {
        Layout.fillWidth: true
        visible: MprisService.lengthSec > 0
        value: MprisService.lengthSec > 0 ? MprisService.positionSec / MprisService.lengthSec : 0
        onMoved: (v) => {
            // Seek: playerctl position <seconds>
            const pos = Math.round(v * MprisService.lengthSec)
            seekProcess.command = ["playerctl", "position", String(pos)]
            seekProcess.running = true
        }
    }

    property Process seekProcess: Process {}
}

