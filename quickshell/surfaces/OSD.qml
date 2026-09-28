import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// OSD
// Transient volume/brightness readout for the island's CENTRE NOTCH.
//
// This used to be a standalone top-centre overlay window in its own layer.
// That was wrong twice over: it sat on a different layer from the bar, so the
// bar's clock drew over it, and it could not be occluded by, or occlude, the
// rest of the island the way the reference shows. In
// 2026-09-20_22-28-44.png the OSD is the centre notch itself, morphed from
// the clock pill into a 275x43 black bar -- there is no clock visible behind
// it, and the album-art and status circles either side sit at the same height.
//
// So this is now content embedded in Island.qml's centerNotchWrap, sized and
// shaped by the notch's own Surface, the same way Calendar/SettingsApp/
// Launcher are. The host passes shadow/borderWidth/backgroundColor overrides.
//
// Purely event-driven: Volume.osdRequested / Brightness.osdRequested push
// into UiState, and UiState's timer hides it again. Nothing polls.
Surface {
    id: root

    // Reference size, used when the host does not size us. The host sets
    // anchors.fill: parent and drives the notch to 275 x 43.
    implicitWidth: 275
    implicitHeight: 43

    // Transparent: the notch's own Surface is the black pill, and the
    // reference OSD is (0,0,0) -- not the ariadne teal that
    // Theme.colors.background would give.
    backgroundColor: "transparent"
    borderWidth: 0

    readonly property string kind: UiState.osdKind
    readonly property real level: UiState.osdLevel
    readonly property bool muted: UiState.osdMuted

    visible: UiState.osdVisible
    opacity: UiState.osdVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

    // Reference internal layout, from the same capture: pill x 174..448,
    // icon x 187..198, track x 214..394, "58%" x 424..444. So 13px from the
    // left edge to the icon, 16 between icon and track, and 30 between the
    // track and the text.
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
            // The reference's speaker glyph measures 12px across.
            size: 12
            iconColor: Qt.rgba(1, 1, 1, 0.95)
        }

        // Sleek thin track bar matching reference images 2 & 3
        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: ConfigStore.osdLevelBarThickness
            radius: ConfigStore.osdLevelBarThickness / 2
            // The reference's unfilled track is (31,29,29), not a white
            // overlay — a 15% white on black composites to about (38,38,38).
            color: "#1f1d1d"
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
            // 30px between the track and the label, on top of the 16 spacing.
            Layout.leftMargin: 14
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
    // `Cannot assign [undefined] to double`.
    //
    // These push into UiState rather than local state, because the notch
    // geometry in Island.qml has to know the OSD is open in order to morph.
    Connections {
        target: Volume
        function onOsdRequested(percent) { UiState.showOsd("volume", percent, Volume.muted) }
    }
    Connections {
        target: Brightness
        function onOsdRequested(percent) { UiState.showOsd("brightness", percent, false) }
    }
}
