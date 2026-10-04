import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "music_note"
        title: "Media & Playback"
        subtitle: "Player controls, background visualizer, and mini-pill behaviors."
    }

    
    Surface {
        Layout.fillWidth: true
        implicitHeight: 90
        cornerRadius: 16
        backgroundColor: Theme.colors.surface

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Item {
                Layout.preferredWidth: 62
                Layout.preferredHeight: 62

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Theme.colors.surface
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: Media.artUrl.length > 0
                    }
                    Icon {
                        anchors.centerIn: parent
                        icon: "music_note"
                        size: 26
                        iconColor: Theme.withAlpha(Theme.colors.text, 0.4)
                        visible: Media.artUrl.length === 0
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: Media.title || "No track active"
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    textColor: Theme.withAlpha(Theme.colors.text, 0.6)
                    text: Media.artist ? (Media.artist + (Media.album ? " • " + Media.album : "")) : "Connect a player like Spotify or browser"
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 8
                IconButton {
                    icon: "skip_previous"
                    size: 34
                    iconSize: 18
                    enabled: Media.canGoPrevious
                    onClicked: Media.previous()
                }
                IconButton {
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 38
                    iconSize: 22
                    primary: true
                    onClicked: Media.togglePlay()
                }
                IconButton {
                    icon: "skip_next"
                    size: 34
                    iconSize: 18
                    enabled: Media.canGoNext
                    onClicked: Media.next()
                }
            }
        }
    }

    
    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Show mini-pill when on other workspaces" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.mediaShowMiniPill
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setMediaShowMiniPill(v)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Track change notification toast" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.mediaShowToast
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setMediaShowToast(v)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Auto-pause playback on session lock" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.mediaAutoPauseOnLock
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setMediaAutoPauseOnLock(v)
        }
    }
}
