import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Item {
    id: root

    property string label: ""
    property var options: []
    property var value: undefined

    signal selected(var value)

    implicitHeight: col.implicitHeight
    Layout.fillWidth: true

    function isCurrent(option) {
        return option !== undefined && option.value === root.value;
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 8

        Label {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: Theme.px(13)
            color: Theme.withAlpha(Theme.colors.text, 0.9)
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.options

                Rectangle {
                    id: pill
                    required property var modelData
                    readonly property bool active: root.isCurrent(pill.modelData)

                    width: pillText.implicitWidth + 24
                    height: 30
                    radius: 15
                    color: pill.active ? Qt.alpha(Theme.accentFor("settings"), 0.20)
                        : (pillArea.containsMouse ? Theme.cc.itemHover : Theme.cc.item)
                    border.color: pill.active ? Theme.accentFor("settings") : Theme.cc.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Config.hover() } }

                    Label {
                        id: pillText
                        anchors.centerIn: parent
                        text: pill.modelData.label !== undefined ? pill.modelData.label : String(pill.modelData.value)
                        font.pixelSize: Theme.px(12)
                        font.weight: pill.active ? Font.DemiBold : Font.Normal
                        color: pill.active ? Theme.colors.text
                                           : Theme.withAlpha(Theme.colors.text, 0.72)
                    }

                    MouseArea {
                        id: pillArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(pill.modelData.value)
                    }
                }
            }
        }
    }
}
