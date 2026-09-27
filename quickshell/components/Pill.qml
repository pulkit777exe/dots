import QtQuick
import "../services"

// Pill
// A fully-rounded capsule. Sizes itself to its content by default (handy
// for chip-like badges such as the highlighted "today" cell), but can be
// given an explicit width/height like any Rectangle.
Rectangle {
    id: root

    default property alias content: inner.data
    property real horizontalPadding: 8
    property real verticalPadding: 4
    property color pillColor: Theme.colors.accent

    implicitWidth: inner.implicitWidth + horizontalPadding * 2
    implicitHeight: inner.implicitHeight + verticalPadding * 2

    color: pillColor
    radius: height / 2
    antialiasing: true

    Item {
        id: inner
        anchors.centerIn: parent
        // KISS + v0.3.0: avoid childrenRect binding loop when children are anchored.
        // Content should provide implicit size upward; use implicitWidth of hosted item.
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
