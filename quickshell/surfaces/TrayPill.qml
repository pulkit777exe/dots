import QtQuick
import "../components"
import "../services"

Item {
    id: root

    readonly property bool showTray: Config.trayEnabled && Tray.hasItems
    readonly property bool hidden: Compositor.activeWindowFullscreen

    readonly property int pad: 12

    width: showTray ? 2 * pad + strip.implicitWidth : 0
    height: Config.barHeight

    opacity: (showTray && !hidden) ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic }
    }

    Surface {
        anchors.fill: parent
        readonly property real effRadius: Math.min(Config.collapsedRadius, Config.barHeight / 2)
        cornerRadius: effRadius
        backgroundColor: Theme.colors.background
        shadow: false
    }

    TrayStrip {
        id: strip
        iconSize: 16
        anchors.centerIn: parent
    }
}
