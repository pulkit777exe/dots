import QtQuick
// Not decorative: Layout.fillWidth/Layout.topMargin below are attached
// properties, and an attached property from an unimported module is dropped
// without a word rather than raising.
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// The editable grid itself: the drop-target ghost row, one slot per entry in
// ControlCenterLayout.items, and the size popup.
//
// This owns every pixel of grid arithmetic -- how wide the canvas is, where
// cell (col,row) starts, and which cell a pixel offset falls in. Nothing
// above it needs those, so the page does not carry them.
//
// Three interactions live here and are all pointer-driven: press-and-drag a
// slot to move it, drag the bottom-right handle to resize, right-click for
// the size popup. Each is gated on the popup being closed, except the
// popup's own click-away area, which must keep receiving the click that
// dismissed it.
Item {
    id: root

    // The page owns the Keys handler and the focus, so it owns deciding when
    // focus goes back to it. Every interaction below calls takeFocus().
    signal wantFocus()

    readonly property int cols: ControlCenterLayout.columns

    readonly property int rowCount: {
        let n = 1
        for (const it of ControlCenterLayout.items)
            n = Math.max(n, it.row + it.rowSpan)
        return n
    }
    readonly property real canvasW: cols * ControlCenterLayout.cellW
                                 + (cols - 1) * ControlCenterLayout.gapH
    readonly property real canvasH: rowCount * ControlCenterLayout.cellH
                                 + (rowCount - 1) * ControlCenterLayout.gapV

    function cellX(col) { return col * (ControlCenterLayout.cellW + ControlCenterLayout.gapH); }
    function cellY(row) { return row * (ControlCenterLayout.cellH + ControlCenterLayout.gapV); }
    function colAt(x) { return Math.round(x / (ControlCenterLayout.cellW + ControlCenterLayout.gapH)); }
    function rowAt(y) { return Math.round(y / (ControlCenterLayout.cellH + ControlCenterLayout.gapV)); }

    function takeFocus() { root.wantFocus(); }

    Layout.fillWidth: true
    Layout.topMargin: 4

    // One empty row below the last used one, so there is somewhere to drop a
    // control being dragged from the palette.
    implicitHeight: root.canvasH + ControlCenterLayout.cellH + ControlCenterLayout.gapV

    Item {
        id: canvasBox
        width: root.canvasW
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter

        // Pressing the empty canvas clears the selection. Left button only:
        // the slots' right-click handlers sit above this one.
        MouseArea {
            enabled: !sizeMenu.visible
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: { ControlCenterLayout.select(""); root.takeFocus(); }
        }

        Row {
            anchors.top: parent.top
            anchors.topMargin: root.cellY(root.rowCount)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: ControlCenterLayout.gapH

            Repeater {
                model: root.cols
                delegate: Rectangle {
                    required property int index
                    width: ControlCenterLayout.cellW
                    height: ControlCenterLayout.cellH
                    radius: width / 2
                    color: Theme.withAlpha(Theme.colors.text, 0.03)
                }
            }
        }

        Repeater {
            model: ControlCenterLayout.items

            delegate: Item {
                id: slot
                required property var modelData

                readonly property bool isSelected: ControlCenterLayout.selectedId === slot.modelData.id

                width: slot.modelData.colSpan * ControlCenterLayout.cellW
                     + (slot.modelData.colSpan - 1) * ControlCenterLayout.gapH
                height: slot.modelData.rowSpan * ControlCenterLayout.cellH
                     + (slot.modelData.rowSpan - 1) * ControlCenterLayout.gapV
                x: root.cellX(slot.modelData.col)
                y: root.cellY(slot.modelData.row)
                z: slot.isSelected ? 10 : 1

                // Grow by a pixel when selected so the slot's own ring is not
                // clipped by the slot's bounds.
                ControlPreview {
                    anchors.fill: parent
                    anchors.margins: slot.isSelected ? -1 : 0
                    controlType: slot.modelData.type
                    colSpan: slot.modelData.colSpan
                    rowSpan: slot.modelData.rowSpan
                    selected: slot.isSelected
                }

                // Drag to move. The anchor column/row and the grab offset are
                // re-read from the model after every move, because settle()
                // may have pushed the item somewhere other than where it was
                // dropped -- without that, a refused move would keep trying
                // the same impossible target and the item would stick.
                MouseArea {
                    enabled: !sizeMenu.visible
                    id: grab
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.SizeAllCursor
                    acceptedButtons: Qt.LeftButton

                    property int anchorCol: 0
                    property int anchorRow: 0
                    property real grabX: 0
                    property real grabY: 0

                    onPressed: (m) => {
                        root.takeFocus();
                        if (!slot.isSelected) ControlCenterLayout.select(slot.modelData.id);

                        const it = ControlCenterLayout.byId(slot.modelData.id);
                        grab.anchorCol = it.col;
                        grab.anchorRow = it.row;
                        grab.grabX = m.x;
                        grab.grabY = m.y;
                    }
                    onPositionChanged: (m) => {
                        if (!pressed) return;
                        ControlCenterLayout.moveTo(
                            slot.modelData.id,
                            grab.anchorCol + root.colAt(m.x - grab.grabX),
                            grab.anchorRow + root.rowAt(m.y - grab.grabY));

                        const it = ControlCenterLayout.byId(slot.modelData.id);
                        if (!it) return;
                        grab.anchorCol = it.col;
                        grab.anchorRow = it.row;
                        grab.grabX = m.x - root.colAt(m.x - grab.grabX)
                                        * (ControlCenterLayout.cellW + ControlCenterLayout.gapH);
                        grab.grabY = m.y - root.rowAt(m.y - grab.grabY)
                                        * (ControlCenterLayout.cellH + ControlCenterLayout.gapV);
                    }
                }

                // Right-click opens the size popup. Its own MouseArea has to
                // sit above the drag one, which is why it is accepted here and
                // the drag area refuses this button.
                MouseArea {
                    enabled: !sizeMenu.visible
                    anchors.fill: parent
                    anchors.margins: -4
                    acceptedButtons: Qt.RightButton
                    onPressed: {
                        root.takeFocus();
                        if (!slot.isSelected) ControlCenterLayout.select(slot.modelData.id);
                    }
                }

                Rectangle {
                    id: handle
                    visible: slot.isSelected
                    width: 12; height: 12; radius: 6
                    color: Theme.colors.accent
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -6
                    anchors.bottomMargin: -6
                    z: 20

                    MouseArea {
                        id: handleResize
                        enabled: !sizeMenu.visible
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.SizeFDiagCursor
                        property int fromSpan: 1

                        onPressed: (m) => {
                            root.takeFocus();
                            const it = ControlCenterLayout.byId(slot.modelData.id);
                            if (it) handleResize.fromSpan = it.colSpan;
                        }
                        onPositionChanged: (m) => {
                            if (!pressed) return;
                            const it = ControlCenterLayout.byId(slot.modelData.id);
                            if (!it) return;

                            // ColSpan only. Every entry in the catalogue is a
                            // one-row-tall size, so the vertical component of
                            // the gesture is not worth reading.
                            const want = handleResize.fromSpan + root.colAt(m.x);
                            const sizes = ControlCenterLayout.catalogue[it.type].sizes;
                            let best = sizes[0], bestD = 1e9;
                            for (const s of sizes) {
                                const d = Math.abs(s[0] - want);
                                if (d < bestD) { bestD = d; best = s; }
                            }
                            ControlCenterLayout.resizeTo(slot.modelData.id, best[0], best[1]);
                        }
                    }
                }
            }
        }

        Item {
            id: sizeMenu

            readonly property var sel: ControlCenterLayout.selected()

            visible: sel !== null
            width: 132
            height: 30 + (sel ? ControlCenterLayout.catalogue[sel.type].sizes.length * 28 : 0)

            x: sel ? Math.max(0, Math.min(root.canvasW - width,
                  root.cellX(sel.col) + root.cellX(sel.colSpan) - width)) : 0
            y: sel ? root.cellY(sel.row) : 0
            z: 30

            readonly property var target: sel

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.colors.surface
                border.width: 1
                border.color: Theme.colors.border
            }

            // Click-away. This one deliberately ignores `visible`, unlike every
            // MouseArea above it: if it went dead the moment the popup opened,
            // the click that opened it would fall through to the drag area
            // underneath and the popup could never be dismissed.
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    ControlCenterLayout.select("");
                    root.takeFocus();
                }
            }

            StyledText {
                id: menuTitle
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                text: "Size"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                textColor: Theme.withAlpha(Theme.colors.text, 0.45)
            }

            Column {
                anchors.top: menuTitle.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 6
                anchors.rightMargin: 6

                Repeater {
                    model: sizeMenu.visible
                           ? ControlCenterLayout.catalogue[sizeMenu.target.type].sizes : []

                    delegate: Rectangle {
                        id: sizeRow
                        required property var modelData
                        readonly property bool current: modelData[0] === sizeMenu.target.colSpan
                                                      && modelData[1] === sizeMenu.target.rowSpan
                        width: parent.width
                        height: 24
                        radius: 6
                        color: sizeHit.containsMouse ? Theme.colors.surfaceAlt : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: sizeRow.modelData[0] + " × " + sizeRow.modelData[1]
                            font.pixelSize: 11
                            color: sizeRow.current ? Theme.colors.accent : Theme.withAlpha(Theme.colors.text, 0.75)
                        }

                        MouseArea {
                            id: sizeHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ControlCenterLayout.resizeTo(sizeMenu.target.id,
                                                             sizeRow.modelData[0],
                                                             sizeRow.modelData[1]);
                                root.takeFocus();
                            }
                        }
                    }
                }
            }
        }
    }
}
