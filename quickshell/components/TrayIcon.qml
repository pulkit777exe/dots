import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../services"

Item {
    id: root

    required property var modelData
    property int iconSize: 16

    width: 22
    height: 22
    implicitWidth: 22
    implicitHeight: 22

    readonly property string tipTitle: modelData.tooltipTitle && modelData.tooltipTitle.length > 0
        ? modelData.tooltipTitle : (modelData.title || modelData.id || "")
    readonly property string tipText: modelData.tooltipDescription && modelData.tooltipDescription.length > 0
        ? tipTitle + "\n" + modelData.tooltipDescription : tipTitle

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Theme.withAlpha(Theme.colors.text, hover.containsMouse ? 0.12 : 0)
        Behavior on color { ColorAnimation { duration: Config.hover() } }
    }

    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.modelData.icon
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        mipmap: true
    }

    Rectangle {
        visible: root.modelData.status === Status.NeedsAttention
        width: 6
        height: 6
        radius: 3
        color: Theme.colors.warning
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
    }

    Rectangle {
        visible: hover.containsMouse && root.tipText.length > 0
        width: tipLabel.implicitWidth + 16
        height: tipLabel.implicitHeight + 10
        radius: 8
        color: Theme.colors.surfaceElevated
        border.color: Theme.colors.border
        border.width: 1
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        z: 100

        Label {
            id: tipLabel
            anchors.centerIn: parent
            text: root.tipText
            font.pixelSize: Theme.px(11)
            color: Theme.colors.text
        }
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: root.modelData.hasMenu ? root.modelData.menu : null
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
    }

    function openMenu() {
        if (root.modelData.hasMenu) menuAnchor.open();
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                root.modelData.secondaryActivate();
            } else if (mouse.button === Qt.RightButton) {
                if (root.modelData.hasMenu) root.openMenu();
                else root.modelData.secondaryActivate();
            } else {
                if (root.modelData.onlyMenu) root.openMenu();
                else root.modelData.activate();
            }
        }
        onWheel: (wheel) => {
            root.modelData.scroll(wheel.angleDelta.y, false);
        }
    }
}
