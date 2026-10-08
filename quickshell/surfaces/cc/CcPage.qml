import QtQuick
import QtQuick.Layouts

// The frame every drill page sits in: the column, its margins, and the
// height the drill card sizes to. A page fills `rows` with its header
// and its cards; anything else it needs (a visible hook, say) it keeps
// on the root as usual.

Item {
    id: page

    signal back()

    // Pages whose cards sit inset from the panel edges pass 15.
    property int sideMargin: 0

    default property alias rows: col.data

    readonly property real contentHeight: col.implicitHeight + 26 // 12 top, 14 bottom
    implicitHeight: contentHeight

    ColumnLayout {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 12
        anchors.leftMargin: page.sideMargin
        anchors.rightMargin: page.sideMargin
        spacing: 0
    }
}
