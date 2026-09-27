import QtQuick
import "../services"

Text {
    id: root

    property string icon: ""
    property int size: 16
    property color iconColor: Qt.rgba(1, 1, 1, 0.92)

    text: icon
    color: iconColor
    font.family: "Material Symbols Rounded"
    font.pixelSize: size

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    antialiasing: true

    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
}
