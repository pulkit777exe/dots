import QtQuick
import QtQuick.Effects
import "../services"

// The one framed panel: rounded rect, hairline border, drop shadow.
//
// The shadow is a layer effect, so it is off unless asked for -- and a
// shadow on a layer clips to the item, which is why this wraps rather than
// every surface rolling its own.

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
    property color shadowColor: Theme.withAlpha(Theme.panelFill, 0.20)

    default property alias content: body.data

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
            shadowBlur: 0.85
            shadowColor: root.shadowColor
            shadowVerticalOffset: 14
            shadowHorizontalOffset: 0
            blurEnabled: false
        }
    }
}
