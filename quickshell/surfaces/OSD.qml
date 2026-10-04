import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"


















Surface {
    id: root

    
    
    implicitWidth: 275
    implicitHeight: 43

    
    
    
    backgroundColor: "transparent"
    borderWidth: 0

    readonly property string kind: UiState.osdKind
    readonly property real level: UiState.osdLevel
    readonly property bool muted: UiState.osdMuted

    visible: UiState.osdVisible
    opacity: UiState.osdVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

    
    
    
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 10
        spacing: 16

        Icon {
            icon: {
                if (root.kind === "brightness") {
                    if (root.level <= 0) return "brightness_disabled"
                    if (root.level < 40) return "brightness_low"
                    if (root.level < 75) return "brightness_medium"
                    return "brightness_high"
                }
                if (root.muted || root.level <= 0) return "volume_off"
                if (root.level < 50) return "volume_down"
                return "volume_up"
            }
            
            size: 12
            iconColor: Theme.colors.text
        }

        
        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: ConfigStore.osdLevelBarThickness
            radius: ConfigStore.osdLevelBarThickness / 2
            
            
            color: Theme.colors.surface
            clip: true

            Rectangle {
                id: fill
                width: track.width * Math.max(0, Math.min(1, (root.muted ? 0 : root.level) / 100))
                height: parent.height
                radius: ConfigStore.osdLevelBarThickness / 2
                color: Theme.colors.accent

                Behavior on width {
                    SpringAnimation { spring: 3.8; damping: MotionConfig.springDamping; mass: 0.8 }
                }
            }
        }

        StyledText {
            variant: "body"
            font.pixelSize: 13
            font.weight: Font.Medium
            
            Layout.leftMargin: 14
            textColor: Theme.withAlpha(Theme.colors.text, 0.85)
            text: Math.round(root.muted ? 0 : root.level) + "%"
        }
    }

    
    
    
    
    
    
    
    
    
    
    
    Connections {
        target: Volume
        function onOsdRequested(percent) { UiState.showOsd("volume", percent, Volume.muted) }
    }
    Connections {
        target: Brightness
        function onOsdRequested(percent) { UiState.showOsd("brightness", percent, false) }
    }
}
