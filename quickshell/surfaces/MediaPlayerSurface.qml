import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../components"
import "../services"

Item {
    id: root

    implicitWidth: 440
    implicitHeight: 160

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Solid.radiusPanel
        color: Solid.bgSurface
        border.color: Solid.borderSubtle
        border.width: 1
        clip: true

        // Subtle album art background glow (low opacity so it doesn't wash out solid background)
        Image {
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            opacity: 0.08
            visible: Media.artUrl.length > 0
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // ── Left: Album Art, rounded via native clip (no
            // Qt5Compat dependency — see ARCHITECTURE.md: it isn't
            // installed on the target machine and already crashed
            // once; Surface.qml's shadow was rewritten to avoid it,
            // this follows the same rule) ─────────────────────────
            Item {
                Layout.preferredWidth: 124
                Layout.preferredHeight: 124
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: artClip
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                    clip: true
                    visible: Media.artUrl.length > 0

                    Image {
                        id: artRawImg
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }
                }

                // Fallback icon placeholder if no album art
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Solid.bgItem
                    border.color: Solid.borderSubtle
                    border.width: 1
                    visible: Media.artUrl.length === 0

                    Icon {
                        anchors.centerIn: parent
                        icon: "music_note"
                        size: 40
                        iconColor: Solid.muted(1)
                    }
                }

                // Thin border overlay around artwork
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                }
            }

            // ── Right: Track Metadata + Interactive Controls ──────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                // Track Title
                StyledText {
                    Layout.fillWidth: true
                    text: Media.title || "No media playing"
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    color: Solid.fg(1)
                    elide: Text.ElideRight
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: Media.artist || "Unknown artist"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.colors.accent
                    elide: Text.ElideRight
                }

                // Album / Identity badge
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: Media.identity.length > 0 || Media.album.length > 0

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: idLabel.implicitWidth + 12
                        radius: 5
                        color: Solid.bgItem
                        visible: Media.identity.length > 0
                        StyledText {
                            id: idLabel
                            anchors.centerIn: parent
                            text: Media.identity
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Solid.muted(1)
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Media.album
                        font.pixelSize: 11
                        color: Solid.muted(1)
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                Item { Layout.preferredHeight: 6 }

                // ── Interactive Scrubbable Progress Bar ───────────────
                Item {
                    id: progressContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14

                    Rectangle {
                        id: progressTrack
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: progressHover.hovered || scrubMouse.pressed ? 6 : 4
                        radius: height / 2
                        color: Solid.bgSliderTrack
                        clip: true
                        Behavior on height { NumberAnimation { duration: MotionConfig.hover() } }

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: Math.max(0, parent.width * Media.progress)
                            radius: parent.radius
                            color: Theme.colors.accent
                        }
                    }

                    HoverHandler { id: progressHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        id: scrubMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function seekToX(xPos) {
                            const frac = Math.max(0, Math.min(1, xPos / width));
                            Media.seek(frac);
                        }
                        onPressed: (e) => seekToX(e.x)
                        onPositionChanged: (e) => { if (pressed) seekToX(e.x) }
                    }
                }

                // ── Timestamps (Real-time) ────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: -2

                    StyledText {
                        text: Media.formatTime(Media.position)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Solid.muted(1)
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: Media.formatTime(Media.length)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Solid.muted(1)
                    }
                }

                // ── Transport Playback Controls ───────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    spacing: 16

                    IconButton {
                        icon: "skip_previous"
                        size: 32
                        iconSize: 18
                        iconColor: Solid.fg(0.8)
                        enabled: Media.hasPlayer
                        onClicked: Media.previous()
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 19
                        color: Theme.colors.accent

                        scale: playTap.pressed ? 0.93 : 1.0
                        Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

                        Icon {
                            anchors.centerIn: parent
                            icon: Media.playing ? "pause" : "play_arrow"
                            size: 20
                            iconColor: Theme.colors.accentText
                        }

                        HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: playTap; onTapped: Media.togglePlay() }
                    }

                    IconButton {
                        icon: "skip_next"
                        size: 32
                        iconSize: 18
                        iconColor: Solid.fg(0.8)
                        enabled: Media.hasPlayer
                        onClicked: Media.next()
                    }
                }
            }
        }
    }
}
