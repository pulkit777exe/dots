import QtQuick
import "../components"
import "../services"

// The right dot: battery ring and wifi at rest, control centre when expanded.
//
// One region of the bar. It is the mirror of IslandLeftDot.qml but not a
// copy of it: this one sizes itself from its expanded content's height
// rather than a kept number, and its panel expands to the RIGHT of the
// centre panel, so the clamp below keeps a wide panel on the screen instead
// of pushing it off the right edge.
//
// Like the left dot, it does not look the centre panel up: Island passes
// centerX and centerWidth in, because both dots hang off the centre panel's
// edges and that is the one number they have to be told rather than read.
Item {
    id: root

    // Resolved per-monitor bar geometry -- see IslandMetrics.qml.
    property var metrics

    // The bar window's width, which is what the expanded panel clamps itself
    // against. NOT this item's own width: this item resizes to the panel, so
    // reading `width` here would make the clamp read its own output and pin
    // the expanded panel to the screen edge.
    property real availableWidth: 0

    // The centre panel's x and width. The dot rests just past the panel's
    // right edge, so both are needed: the panel is not a fixed width, and an
    // OSD widens it to 275 in the middle of a keypress.
    property real centerX: 0
    property real centerWidth: 0

    // Whether the centre panel is currently showing an OSD, which resizes it
    // and would otherwise drag this dot sideways. Its x spring is switched off
    // for the duration so the dot jumps instead of sliding across the bar.
    property bool centerIsOsd: false

    y: metrics.topOffset

    // Global, not per-monitor: a half-and-half bar reads as a bug, so this
    // is deliberately not overridable per screen (see BarConfigMonitors).
    visible: BarConfig.statusCircleEnabled

    readonly property bool isExpanded: UiState.controlCenterOpen
    property real targetW: isExpanded ? 514 : metrics.barHeight

    // Height comes from the control centre's own implicitHeight, not a kept
    // number: the panel has a sound view, a display view and a bluetooth view
    // and they are not the same height, so a single stored value would have
    // to be re-checked every time a view gained a row. panelHeight inside
    // ControlCenter.qml already derives it from the active page's content.
    property real targetH: isExpanded ? controlCenterContent.implicitHeight : metrics.barHeight

    width: targetW
    height: targetH

    readonly property real collapsedX: centerX + centerWidth + metrics.dotSpacing

    // The dot's resting centre. Declared for the same reason it always was:
    // it is the anchor a drag would use, and nothing reads it yet.
    readonly property real collapsedCentre: collapsedX + metrics.barHeight / 2

    // Expanded, the panel's left edge stays pinned where the dot's left edge
    // was, so it appears to unroll out of the centre panel. The clamp stops it
    // at gapFromEdge short of availableWidth rather than hanging off the
    // right.
    x: isExpanded
        ? Math.max(metrics.gapFromEdge,
            Math.min(collapsedX, availableWidth - targetW - metrics.gapFromEdge))
        : collapsedX

    Behavior on width {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
    }
    Behavior on height {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
    }
    Behavior on x {
        enabled: !MotionConfig.reduceMotion && !centerIsOsd
        SpringAnimation { spring: 9; damping: MotionConfig.springDamping; mass: 0.6 }
    }

    Surface {
        id: rightSurface
        anchors.fill: parent
        cornerRadius: root.isExpanded ? metrics.expandedCornerRadius : metrics.effectiveCollapsedRadius
        topLeftRadius: (metrics.notchMode && !root.isExpanded) ? 0 : cornerRadius
        topRightRadius: (metrics.notchMode && !root.isExpanded) ? 0 : cornerRadius
        bottomLeftRadius: cornerRadius
        bottomRightRadius: cornerRadius
        backgroundColor: Theme.colors.background
        shadow: root.isExpanded

        Behavior on cornerRadius {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }

        // The collapsed face. A crossfade rather than a slide, so the ring
        // and the wifi glyph do not visibly slide as they are replaced.
        Item {
            anchors.fill: parent
            visible: !root.isExpanded
            opacity: root.isExpanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

            Item {
                id: rightDotArtContainer
                anchors.centerIn: parent
                width: metrics.barHeight - 2 * BarConfig.innerPadding
                height: width

                // anchors.centerIn plus an explicit x/y on the same item: the
                // explicit values win, and centreIn is what established the
                // starting position they are offsets from.
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2 - (rightDotHover.containsMouse ? BarConfig.stageLiftOnHover : 0)
                scale: rightDotHover.containsMouse ? 1.05 : 1.0

                Behavior on scale {
                    enabled: !MotionConfig.reduceMotion
                    SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                }
                Behavior on y {
                    enabled: !MotionConfig.reduceMotion
                    SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                }

                // The ring is the battery indicator; it draws its own track
                // and fill, so it needs no background behind it.
                BatteryRing {
                    anchors.fill: parent
                    percentage: Battery.percentage
                    charging: Battery.charging
                    strokeWidth: 2.2
                }

                Icon {
                    anchors.centerIn: parent
                    icon: !Wifi.enabled ? "wifi_off" : (Wifi.connected ? "wifi" : "wifi_find")
                    size: 15
                    iconColor: Theme.withAlpha(Theme.colors.text, 0.92)
                }
            }

            MouseArea {
                id: rightDotHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: UiState.toggleControlCenter()
            }
        }

        // The expanded face slides up from below the dot rather than fading,
        // so the dot looks like a lid lifting off the control centre.
        Item {
            id: controlCenterSlide
            anchors.fill: parent
            visible: root.isExpanded
            y: root.isExpanded ? 0 : -BarConfig.panelSlideIn
            Behavior on y {
                enabled: !MotionConfig.reduceMotion
                NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
            }

            ControlCenter {
                id: controlCenterContent
                anchors.fill: parent
                opacity: root.isExpanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                // The panel's own Surface is the frame; a second one inside it
                // would double the border and the shadow.
                shadow: false
                borderWidth: 0
                backgroundColor: "transparent"
            }
        }
    }
}
