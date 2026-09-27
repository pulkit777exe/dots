import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// OSD
// Transient on-screen display for volume/brightness changes. Purely
// event-driven: Volume.osdRequested / Brightness.osdRequested fire it,
// a Timer hides it again after `visibleDuration` — nothing polls this,
// and nothing needs to poll it to know when to show it.
Surface {
    id: root

    property int visibleDuration: ConfigStore.osdOnScreenTimeMs
    width: 250
    height: 44
    cornerRadius: 22
    backgroundColor: Theme.withAlpha(Theme.colors.background, 0.96)

    property string kind: "volume"     // "volume" | "brightness"
    property real level: 0
    property bool muted: false

    opacity: 0
    scale: 0.94
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

    function _present(newKind, newLevel, newMuted) {
        kind = newKind;
        level = typeof newLevel === "number" ? newLevel : 0;
        muted = newMuted ?? false;
        opacity = 1;
        scale = 1;
        hideTimer.restart();
    }

    function showVolume(level, muted) { _present("volume", level, muted) }
    function showBrightness(level) { _present("brightness", level, false) }

    Timer {
        id: hideTimer
        interval: root.visibleDuration
        onTriggered: { root.opacity = 0; root.scale = 0.94 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14

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
            size: 18
            iconColor: Qt.rgba(1, 1, 1, 0.95)
        }

        // Sleek thin track bar matching reference images 2 & 3
        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: ConfigStore.osdLevelBarThickness
            radius: ConfigStore.osdLevelBarThickness / 2
            color: Qt.rgba(1, 1, 1, 0.15)
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
            textColor: Qt.rgba(1, 1, 1, 0.85)
            text: Math.round(root.muted ? 0 : root.level) + "%"
        }
    }

    // Wire directly to the services that can trigger an OSD.
    // Both services emit `osdRequested(int percent)` rather than the
    // built-in property-change signal: Volume's level property is named
    // `volumePercent` (so the auto-signal is onVolumePercentChanged, not
    // onLevelChanged), and Brightness's `levelChanged` auto-signal
    // carries no payload — using either as the handler slot would
    // receive `undefined` and then trigger
    // `Cannot assign [undefined] to double` at line 33.
    Connections {
        target: Volume
        function onOsdRequested(percent) { root.showVolume(percent, Volume.muted) }
    }
    Connections {
        target: Brightness
        function onOsdRequested(percent) { root.showBrightness(percent) }
    }
}
