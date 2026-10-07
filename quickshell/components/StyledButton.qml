import QtQuick
import "../services"

// The pill button used by the settings app (power modes, lock).

Rectangle {
    id: root

    property string label: ""
    property bool filled: false
    property color accent: Theme.colors.accent

    signal clicked()

    implicitWidth: labelText.implicitWidth + 32
    implicitHeight: 36
    radius: height / 2

    readonly property color baseColor: filled
        ? accent
        : Theme.withAlpha(Theme.colors.text, 0.08)

    color: press.containsMouse && press.pressed
        ? (filled ? Qt.darker(accent, 1.12) : Theme.withAlpha(Theme.colors.text, 0.18))
        : (press.containsMouse && !filled ? Theme.withAlpha(Theme.colors.text, 0.14) : baseColor)

    Behavior on color { ColorAnimation { duration: Config.hover() } }

    scale: press.pressed ? 0.96 : 1.0
    Behavior on scale {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 }
    }

    Label {
        id: labelText
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: Theme.px(13)
        font.weight: Font.DemiBold
        color: root.filled ? Theme.colors.accentText : Theme.withAlpha(Theme.colors.text, 0.85)
    }

    MouseArea {
        id: press
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
