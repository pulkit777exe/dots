import QtQuick
import QtQuick.Effects
import "../services"

// Soft blurred glow behind the parent. Layer shells get no compositor
// shadow (Hyprland layerrule has no shadow effect), so glow renders
// client-side. RectangularShadow is the cheap path per Qt docs: real
// blurred falloff, not a translucent ring. Not MultiEffect (heavier),
// not Qt5Compat (banned by lint).
RectangularShadow {
    id: root

    property color glowColor: Theme.withAlpha(Theme.colors.accent, 0.15)
    property bool on: true
    property real cornerRadius: 16
    property real glowBlur: 8

    // Callers anchor this (usually fill parent with negative margins).
    radius: root.cornerRadius
    blur: root.glowBlur
    spread: 0
    color: root.glowColor
    opacity: root.on ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: Config.hover(); easing.type: Easing.OutCubic } }
}
