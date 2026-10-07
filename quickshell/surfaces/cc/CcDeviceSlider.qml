import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

// One slider row for a drill page: near-black track with the glyph inside
// the accent fill, percentage on the right. `value` is 0..1.

Item {
    id: slider

    property string icon: "volume_up"
    property real value: 0
    property color trackColor: Theme.cc.track

    signal moved(real fraction)

    implicitHeight: 26

    RowLayout {
        anchors.fill: parent
        spacing: 17

        FillSlider {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            icon: slider.icon
            trackColor: slider.trackColor
            value: slider.value
            onMoved: f => slider.moved(f)
        }

        Label {
            text: Math.round(slider.value * 100) + "%"
            font.pixelSize: Theme.px(12)
            color: Theme.withAlpha(Theme.colors.text, 0.6)
            horizontalAlignment: Text.AlignRight
        }
    }
}
