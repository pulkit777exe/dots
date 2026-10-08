import QtQuick

// The dot in a picker card's corner: visible while the card is the
// current selection, painted with whatever colour the card passes.

Rectangle {
    property bool selected: false

    visible: selected
    width: 7
    height: 7
    radius: 3.5
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 8
}
