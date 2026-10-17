import QtQuick
import QtQuick.Effects
import "../services"

Item {
    id: root

    property real cornerRadius: 20
    property real topLeftRadius: cornerRadius
    property real topRightRadius: cornerRadius
    property real bottomLeftRadius: cornerRadius
    property real bottomRightRadius: cornerRadius

    property color backgroundColor: Theme.panelFill
    property color borderColor: Theme.withAlpha(Theme.colors.text, 0.07)
    property real borderWidth: 1

    property bool shadow: true
    property color shadowColor: Theme.withAlpha(Theme.shadowTint, 0.16)

    default property alias content: contentWrap.data

    Rectangle {
        id: bg
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
            // macOS-like: one wide, soft, low-opacity shadow with a small
            // downward offset. No hard ring, no long drop.
            shadowEnabled: true
            autoPaddingEnabled: true
            blurMax: 48
            shadowBlur: 0.8
            shadowColor: root.shadowColor
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            blurEnabled: false
        }
    }

    Item {
        id: contentWrap
        anchors.fill: parent
    }
}
