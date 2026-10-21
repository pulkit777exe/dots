import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Rectangle {
    id: card

    property string label: ""
    property string icon: ""
    property real value: 0
    property color accent: Theme.accentFor("control-center")

    signal moved(real fraction)
    signal scrolled(int direction)
    signal chevronClicked()

    height: 52
    radius: 14
    color: Theme.cc.card
    border.color: Theme.cc.border
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: card.label
                font.pixelSize: Theme.px(13)
                font.weight: Font.Bold
                color: Theme.colors.text
                Layout.fillWidth: true
            }
            Icon {
                icon: "chevron_right"
                size: 15
                iconColor: Theme.withAlpha(Theme.colors.text, 0.55)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.chevronClicked()
                }
            }
        }

        FillSlider {
            Layout.fillWidth: true
            Layout.fillHeight: true
            value: card.value
            icon: card.icon
            accent: card.accent
            onMoved: (f) => card.moved(f)
            onScrolled: (d) => card.scrolled(d)
        }
    }
}
