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
        radius: 24
        color: "#141414"
        border.color: "#282828"
        border.width: 1
        clip: true

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        Image {
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            opacity: 0.34
            visible: Media.artUrl.length > 0
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.28)
            visible: Media.artUrl.length > 0
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            
            
            
            
            
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

                
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: "#202020"
                    border.color: "#2c2c2c"
                    border.width: 1
                    visible: Media.artUrl.length === 0

                    Icon {
                        anchors.centerIn: parent
                        icon: "music_note"
                        size: 40
                        iconColor: "#666666"
                    }
                }

                
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                }
            }

            
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                
                StyledText {
                    Layout.fillWidth: true
                    text: Media.title || "No media playing"
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                }

                
                
                
                
                
                
                
                
                StyledText {
                    Layout.fillWidth: true
                    text: Media.artist || "Unknown artist"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 0.93, 0.88, 0.62)
                    elide: Text.ElideRight
                }

                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: Media.identity.length > 0 || Media.album.length > 0

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: idLabel.implicitWidth + 12
                        radius: 5
                        color: "#222222"
                        visible: Media.identity.length > 0
                        StyledText {
                            id: idLabel
                            anchors.centerIn: parent
                            text: Media.identity
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "#888888"
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Media.album
                        font.pixelSize: 11
                        color: "#666666"
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                Item { Layout.preferredHeight: 6 }

                
                Item {
                    id: progressContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14

                    Rectangle {
                        id: progressTrack
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: progressHover.hovered || scrubMouse.pressed ? 6 : 4
                        radius: height / 2
                        color: "#2c2c2c"
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

                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: -2

                    StyledText {
                        text: Media.formatTime(Media.position)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#888888"
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: Media.formatTime(Media.length)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#888888"
                    }
                }

                
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    spacing: 16

                    IconButton {
                        icon: "skip_previous"
                        size: 32
                        iconSize: 18
                        iconColor: "#CCCCCC"
                        enabled: Media.hasPlayer
                        onClicked: Media.previous()
                    }

                    
                    
                    
                    
                    
                    
                    
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 19
                        color: Qt.rgba(1, 1, 1, 0.09)

                        scale: playTap.pressed ? 0.93 : 1.0
                        Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

                        Icon {
                            anchors.centerIn: parent
                            icon: Media.playing ? "pause" : "play_arrow"
                            size: 20
                            iconColor: "#F5F1D7"
                        }

                        HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: playTap; onTapped: Media.togglePlay() }
                    }

                    IconButton {
                        icon: "skip_next"
                        size: 32
                        iconSize: 18
                        iconColor: "#CCCCCC"
                        enabled: Media.hasPlayer
                        onClicked: Media.next()
                    }
                }
            }
        }
    }
}
