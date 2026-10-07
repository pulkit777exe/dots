import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// Label and value over a fill slider; `moved` reports a value in range.

Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property string suffix: ""
    property int decimals: 0

    signal moved(real value)

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    readonly property real fraction: to > from ? (value - from) / (to - from) : 0

    function clamp(v) { return Math.max(from, Math.min(to, v)); }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
                elide: Text.ElideRight
            }

            Label {
                text: root.value.toFixed(root.decimals) + root.suffix
                font.pixelSize: Theme.px(12)
                color: Theme.withAlpha(Theme.colors.text, 0.5)
            }
        }

        FillSlider {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            value: root.fraction
            onMoved: (f) => root.moved(root.clamp(root.from + f * (root.to - root.from)))
            onScrolled: (d) => root.moved(root.clamp(root.value + d * (root.to - root.from) / 20))
        }
    }
}
