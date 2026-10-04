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
    
    
    // A drop shadow, same reasoning as Scrim.qml: it darkens whatever is behind
    // the panel, which no palette key describes. Expressed as a fraction of
    // `panelFill` (Theme's constant #000000) so it still renders byte-identical
    // to the `Qt.rgba(0, 0, 0, 0.20)` it replaced.
    property color shadowColor: Theme.withAlpha(Theme.panelFill, 0.20)
    property real shadowBlur: 0.85
    property real shadowVerticalOffset: 14
    property real shadowHorizontalOffset: 0

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
            shadowBlur: root.shadowBlur * (DeviceProfile.lowSpec ? 0.55 : 1.0)
            shadowColor: DeviceProfile.lowSpec ? Theme.withAlpha(Theme.panelFill, 0.14) : root.shadowColor
            shadowVerticalOffset: root.shadowVerticalOffset * (DeviceProfile.lowSpec ? 0.6 : 1.0)
            shadowHorizontalOffset: root.shadowHorizontalOffset
            blurEnabled: false
        }
    }
}
