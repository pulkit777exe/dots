import QtQuick
import QtQuick.Effects
import "../services"

// Surface
// Generic themed panel. Supports independent corner radii (Qt 6.7+ Rectangle
// per-corner radius) so it can be a pill, a notch body, or a flat sheet.
// Children declared inside a Surface {} are parented into the painted body.
//
// Shadow: natural soft blur via QtQuick.Effects MultiEffect (GPU gaussian),
// not stacked shape copies. Previous layered-shape fallback looked like
// hard stepped outlines, especially on asymmetric radii (notch flare) and
// when nested Surfaces both cast shadows (Island → Launcher double-shadow).
// MultiEffect gives a true blurred penumbra with correct per-corner radius
// handling and no extra items. Falls back to no shadow on low-spec if
// Effects unavailable.
Item {
    id: root

    property real cornerRadius: 20
    property real topLeftRadius: cornerRadius
    property real topRightRadius: cornerRadius
    property real bottomLeftRadius: cornerRadius
    property real bottomRightRadius: cornerRadius

    // Qt.alpha(), not Qt.rgba(Theme.colors.background.r, ...): Theme.colors is
    // a plain JS object of hex *strings*, so `.r` / `.g` / `.b` are undefined
    // and Qt.rgba() silently produced black-at-94% instead of the theme's
    // background. Qt.alpha() takes the colour as-is and only sets alpha.
    property color backgroundColor: Qt.alpha(Theme.colors.background, 0.94)
    property color borderColor: Qt.rgba(1, 1, 1, 0.07)
    property real borderWidth: 1

    property bool shadow: true
    // Natural Apple-like: soft 30px spread, low opacity, lifted vertical offset.
    // MultiEffect shadowBlur 0-1 → ~0.9 ≈ 32px, 0.20 alpha reads as 0.12 on light wallpapers.
    property color shadowColor: Qt.rgba(0, 0, 0, 0.20)
    property real shadowBlur: 0.85
    property real shadowVerticalOffset: 14
    property real shadowHorizontalOffset: 0

    default property alias content: body.data

    // Outer container reserves padding so blurred shadow isn't clipped by parent
    // (MultiEffect autoPadding does this on Qt 6.8+, explicit padding for 6.7 compat)
    Rectangle {
        id: body
        anchors.fill: parent
        antialiasing: true

        color: root.backgroundColor
        border.color: root.borderColor
        border.width: root.borderWidth

        radius: root.cornerRadius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius

        layer.enabled: root.shadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            autoPaddingEnabled: true
            shadowBlur: root.shadowBlur * (DeviceProfile.lowSpec ? 0.55 : 1.0)
            shadowColor: DeviceProfile.lowSpec ? Qt.rgba(0,0,0,0.14) : root.shadowColor
            shadowVerticalOffset: root.shadowVerticalOffset * (DeviceProfile.lowSpec ? 0.6 : 1.0)
            shadowHorizontalOffset: root.shadowHorizontalOffset
            blurEnabled: false
        }
    }
}
