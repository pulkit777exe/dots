import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Item {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""

    signal committed(string value)

    implicitHeight: col.implicitHeight
    Layout.fillWidth: true

    function commit() {
        if (field.text !== root.value) root.committed(field.text);
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 10
            color: Theme.withAlpha(Theme.colors.text, 0.07)
            border.color: field.activeFocus ? Theme.accentFor("settings")
                                            : Theme.withAlpha(Theme.colors.text, 0.12)
            border.width: 1

            TextField {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                textSize: 13
                text: root.value
                onEditingFinished: root.commit()
                Keys.onReturnPressed: root.commit()
                Keys.onEnterPressed: root.commit()
            }

            Label {
                anchors.fill: parent
                anchors.leftMargin: 12
                verticalAlignment: Text.AlignVCenter
                visible: field.text.length === 0
                text: root.placeholder
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.35)
            }
        }
    }
}
