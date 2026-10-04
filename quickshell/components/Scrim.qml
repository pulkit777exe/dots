import QtQuick
import "../services"



Rectangle {
    id: root

    // A dim laid over content the component knows nothing about -- whatever
    // window happens to be behind it. There is no palette key that describes
    // "behind", so this stays a fraction of the panel fill (which Theme holds
    // as a constant) rather than a fraction of `text`: a scrim has to darken
    // a wallpaper as well as a panel, and `text` is a light colour on all six
    // palettes, so tinting it with `text` would LIGHTEN what it is meant to
    // dim. `panelFill` is #000000, so this renders exactly as the
    // `Qt.rgba(0, 0, 0, 0.45)` it replaced.
    property color scrimColor: Theme.withAlpha(Theme.panelFill, 0.45)
    property bool dismissOnClick: true

    signal dismissed()

    color: scrimColor

    MouseArea {
        anchors.fill: parent
        enabled: root.dismissOnClick
        onClicked: root.dismissed()
    }

    
    
    MouseArea {
        anchors.fill: parent
        enabled: !root.dismissOnClick
    }
}
