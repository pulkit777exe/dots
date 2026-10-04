import QtQuick
import "../components"
import "../services"

// The left dot: album art at rest, media player when expanded.
//
// One region of the bar. It knows three things the others do not: what the
// media surface is called, that its collapsed position is measured leftward
// from the centre panel, and that expanding it slides the panel in rather
// than crossfading in place (see mediaSlide).
//
// It does NOT know where the centre panel is; Island passes centerX in.
// That is the whole contract between these regions: the dots hang off the
// centre panel's edges, so the panel's geometry is the one number they have
// to be told rather than look up.
Item {
    id: root

    // Resolved per-monitor bar geometry -- see IslandMetrics.qml.
    property var metrics

    // The bar window's width, which is what the expanded panel clamps itself
    // against. NOT this item's own width: this item resizes to the panel, so
    // reading `width` here would make the clamp read its own output and pin
    // the expanded panel to the screen edge. Island owns the full-width item
    // and passes its width down for exactly this reason.
    property real availableWidth: 0

    // The centre panel's x. The dot rests one barHeight and one dotSpacing to
    // the left of it, so it is the thing that moves when the panel resizes.
    property real centerX: 0

    // Whether the centre panel is currently showing an OSD. The OSD resizes
    // the panel to 275x43, which would drag both dots sideways; their x
    // springs are switched off for the duration so they jump instead of
    // sliding across the bar to follow it.
    property bool centerIsOsd: false

    y: metrics.topOffset

    // Global, not per-monitor: a half-and-half bar reads as a bug, so this
    // is deliberately not overridable per screen (see BarConfigMonitors).
    visible: BarConfig.albumArtCircleEnabled

    readonly property bool isExpanded: UiState.mediaOpen
    property real targetW: isExpanded ? 406 : metrics.barHeight
    property real targetH: isExpanded ? 214 : metrics.barHeight

    width: targetW
    height: targetH

    readonly property real collapsedX: centerX - metrics.barHeight - metrics.dotSpacing

    // The dot's resting centre. Declared for the same reason it always was:
    // it is the anchor a drag would use, and nothing reads it yet.
    readonly property real collapsedCentre: collapsedX + metrics.barHeight / 2

    // Expanded, the panel's right edge stays pinned where the dot's right edge
    // was and it grows leftward -- so it appears to unroll out of the centre
    // panel rather than sliding in from the screen edge. The max/min pair
    // clamps that to availableWidth so a wide panel on a narrow screen stops
    // at gapFromEdge instead of hanging off the left.
    x: isExpanded
        ? Math.max(metrics.gapFromEdge,
            Math.min(collapsedX + metrics.barHeight - targetW,
                     availableWidth - targetW - metrics.gapFromEdge))
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
        id: leftSurface
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

        // The collapsed face. A crossfade rather than a slide, because the
        // dot and the player are the same few pixels: fading keeps the
        // artwork from visibly sliding as it is replaced.
        Item {
            anchors.fill: parent
            visible: !root.isExpanded
            opacity: root.isExpanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

            Item {
                id: dotArtContainer
                anchors.centerIn: parent
                width: metrics.barHeight - 2 * BarConfig.innerPadding
                height: width

                // anchors.centerIn plus an explicit x/y on the same item: the
                // explicit values win, and centreIn is what established the
                // starting position they are offsets from.
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2 - (leftDotHover.containsMouse ? BarConfig.stageLiftOnHover : 0)
                scale: leftDotHover.containsMouse ? 1.05 : 1.0

                Behavior on scale {
                    enabled: !MotionConfig.reduceMotion
                    SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                }
                Behavior on y {
                    enabled: !MotionConfig.reduceMotion
                    SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                }

                // Circular clip on a transparent rectangle: the raw art is a
                // square Image and the dot is a circle, so it needs clipping
                // rather than a rounded mask.
                Rectangle {
                    id: dotArtClip
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    clip: true
                    visible: Media.artUrl.length > 0

                    Image {
                        id: dotRawArt
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }
                }

                // Stands in when there is no art, so the dot is never empty.
                Icon {
                    anchors.centerIn: parent
                    icon: "music_note"
                    size: 16
                    iconColor: Theme.withAlpha(Theme.colors.text, 0.8)
                    visible: Media.artUrl.length === 0
                }
            }

            MouseArea {
                id: leftDotHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: UiState.toggleMedia()
            }
        }

        // The expanded face slides up from below the dot rather than fading,
        // so the dot looks like a lid lifting off the player.
        Item {
            id: mediaSlide
            anchors.fill: parent
            visible: root.isExpanded
            // On a wrapper, not on the content: the content is
            // anchors.fill, and an explicit y on an anchored item
            // silently overrides the anchor.
            y: root.isExpanded ? 0 : -BarConfig.panelSlideIn
            Behavior on y {
                enabled: !MotionConfig.reduceMotion
                NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
            }

            MediaPlayerSurface {
                anchors.fill: parent
                opacity: root.isExpanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }
        }
    }
}
