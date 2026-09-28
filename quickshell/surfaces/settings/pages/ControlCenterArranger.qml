import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// ControlCenterArranger
// The Control Center editor from 2026-09-20_22-29-19: a live canvas of the
// real controls on a column grid, plus the chrome around it (column count,
// Tidy / Undo / Reset, the "Add a control" palette and the two hint lines).
//
// The canvas shows the real ControlPreview at the real grid metrics and is
// centred in the content column rather than stretched -- the reference leaves
// roughly 280px of empty content either side of the grid.
//
// Every edit goes through ControlCenterLayout, which owns the undo stack and
// persistence. This file only turns pointer and key events into calls on it.
//
// The root is the ColumnLayout itself rather than an Item wrapping one: an
// Item whose implicitHeight came from a child ColumnLayout that was in turn
// `anchors.fill`-ing that Item is a circular binding, and QML resolves it by
// collapsing the whole column to near-zero width.
ColumnLayout {
    id: root

    spacing: 10

    // This root's implicitWidth is NOT zeroed here, deliberately. A
    // ColumnLayout regenerates its own implicitWidth during layout, so an
    // `implicitWidth: 0` binding on it is inert -- it reads back as 728, the
    // width of the widest child (the two unwrapped hint lines). The width
    // demand is zeroed by the parent instead, via Layout.preferredWidth: 0 on
    // this component, which is the mechanism a ColumnLayout parent does
    // respect. See ControlCenterPage.qml.

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

    function takeFocus() { root.forceActiveFocus(); }

    Keys.onPressed: (e) => {
        const id = ControlCenterLayout.selectedId;
        if (!id) return;
        const step = e.key === Qt.Key_Shift ? 3 : 1;
        if (e.key === Qt.Key_Left)             { ControlCenterLayout.nudge(id, -step, 0); e.accepted = true; }
        else if (e.key === Qt.Key_Right)       { ControlCenterLayout.nudge(id,  step, 0); e.accepted = true; }
        else if (e.key === Qt.Key_Up)          { ControlCenterLayout.nudge(id, 0, -step); e.accepted = true; }
        else if (e.key === Qt.Key_Down)        { ControlCenterLayout.nudge(id, 0,  step); e.accepted = true; }
        else if (e.key === Qt.Key_BracketLeft)  { ControlCenterLayout.cycleSize(id, -1); e.accepted = true; }
        else if (e.key === Qt.Key_BracketRight) { ControlCenterLayout.cycleSize(id,  1); e.accepted = true; }
        else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
            ControlCenterLayout.remove(id); e.accepted = true;
        }
    }

    // ---- "Layout" caption ------------------------------------------------

    SettingsSectionLabel { label: "Layout" }

    // ---- Column selector, Tidy / Undo / Reset, hint ----------------------

    Item {
        Layout.fillWidth: true
        implicitHeight: 30

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: Array.from(
                    { length: ControlCenterLayout.maxColumns - ControlCenterLayout.minColumns + 1 },
                    (_, i) => ControlCenterLayout.minColumns + i)

                delegate: Rectangle {
                    id: colPill
                    required property int modelData
                    readonly property bool active: modelData === root.cols

                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: colPill.active ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.055)

                    StyledText {
                        anchors.centerIn: parent
                        text: colPill.modelData
                        font.pixelSize: 12
                        font.weight: colPill.active ? Font.DemiBold : Font.Normal
                        color: colPill.active ? "#0B1512" : Qt.rgba(1, 1, 1, 0.7)
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            ControlCenterLayout.setColumns(colPill.modelData);
                            root.takeFocus();
                        }
                    }
                }
            }

            Item { Layout.preferredWidth: 10 }

            Repeater {
                model: [
                    { label: "Tidy",  enabled: true,
                      run: function () { ControlCenterLayout.tidy(); } },
                    { label: "Undo",  enabled: ControlCenterLayout.undoDepth > 0,
                      run: function () { ControlCenterLayout.undo(); } },
                    { label: "Reset", enabled: true,
                      run: function () { ControlCenterLayout.reset(); } }
                ]

                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    readonly property bool on: modelData.enabled

                    Layout.preferredWidth: labelText.implicitWidth + 28
                    Layout.preferredHeight: 30
                    radius: 15
                    color: btn.on
                        ? (btnHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.055))
                        : Qt.rgba(1, 1, 1, 0.02)

                    StyledText {
                        id: labelText
                        anchors.centerIn: parent
                        text: btn.modelData.label
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: btn.on ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(1, 1, 1, 0.28)
                    }

                    HoverHandler { id: btnHover; enabled: btn.on; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: btn.on
                        onTapped: { btn.modelData.run(); root.takeFocus(); }
                    }
                }
            }
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Drag to move · corner to resize · right-click for sizes"
            font.pixelSize: 11
            textColor: Qt.rgba(1, 1, 1, 0.42)
        }
    }

    // ---- The canvas -------------------------------------------------------

    Item {
        Layout.fillWidth: true
        Layout.topMargin: 4
        // The grid plus one extra row of empty slots below it.
        implicitHeight: root.canvasH + ControlCenterLayout.cellH + ControlCenterLayout.gapV

        Item {
            id: canvasBox
            width: root.canvasW
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter

            // Bare canvas: clears the selection. Declared first so it sits
            // behind the controls rather than swallowing their clicks.
            MouseArea {
                // Suspend the canvas while the size menu is up. The menu draws over its
                // neighbours -- it is pinned to the selected control's top-right and is
                // 130px wide -- but a press still reached the slot underneath, so
                // right-clicking a size row selected whichever control happened to be
                // behind the menu instead of resizing anything. A MouseArea under a
                // TapHandler takes the press and cancels the tap, so the rows could never
                // win; disabling the canvas is what makes the menu modal.
                enabled: !sizeMenu.visible
                anchors.fill: parent
                // Left button only. This area's whole job is "click empty space
                // to deselect", and it spans the entire canvas including the
                // controls. Accepting the right button too put it in direct
                // competition with each slot's own right-click handler, which
                // selects the control and opens this same menu: whichever ran
                // last won, and a right-click over a control could leave
                // nothing selected at all. Right-click belongs to the slots.
                acceptedButtons: Qt.LeftButton
                onPressed: { ControlCenterLayout.select(""); root.takeFocus(); }
            }

            // Empty slots: one row of 1x1 discs below the last placed control,
            // one per column, so the grid's width stays legible even when the
            // bottom rows are short.
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
                        color: Qt.rgba(1, 1, 1, 0.03)
                    }
                }
            }

            // Placed controls.
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

                    ControlPreview {
                        anchors.fill: parent
                        anchors.margins: slot.isSelected ? -1 : 0
                        controlType: slot.modelData.type
                        colSpan: slot.modelData.colSpan
                        rowSpan: slot.modelData.rowSpan
                        selected: slot.isSelected
                    }

                    // ---- Drag to move ----
                    MouseArea {
                        // Suspend the canvas while the size menu is up. The menu draws over its
                        // neighbours -- it is pinned to the selected control's top-right and is
                        // 130px wide -- but a press still reached the slot underneath, so
                        // right-clicking a size row selected whichever control happened to be
                        // behind the menu instead of resizing anything. A MouseArea under a
                        // TapHandler takes the press and cancels the tap, so the rows could never
                        // win; disabling the canvas is what makes the menu modal.
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
                            // Re-read after selecting: a click on an unselected
                            // control selects it first, and the model may have
                            // settled it somewhere else on the way in.
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
                            // Re-anchor to the settled cell, so the control
                            // keeps following the pointer instead of jumping a
                            // whole cell on every move event.
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

                    // ---- Right-click for sizes ----
                    MouseArea {
                        // Suspend the canvas while the size menu is up. The menu draws over its
                        // neighbours -- it is pinned to the selected control's top-right and is
                        // 130px wide -- but a press still reached the slot underneath, so
                        // right-clicking a size row selected whichever control happened to be
                        // behind the menu instead of resizing anything. A MouseArea under a
                        // TapHandler takes the press and cancels the tap, so the rows could never
                        // win; disabling the canvas is what makes the menu modal.
                        enabled: !sizeMenu.visible
                        anchors.fill: parent
                        anchors.margins: -4
                        acceptedButtons: Qt.RightButton
                        onPressed: {
                            root.takeFocus();
                            if (!slot.isSelected) ControlCenterLayout.select(slot.modelData.id);
                        }
                    }

                    // ---- Corner to resize ----
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
                            // Suspend the canvas while the size menu is up. The menu draws over its
                            // neighbours -- it is pinned to the selected control's top-right and is
                            // 130px wide -- but a press still reached the slot underneath, so
                            // right-clicking a size row selected whichever control happened to be
                            // behind the menu instead of resizing anything. A MouseArea under a
                            // TapHandler takes the press and cancels the tap, so the rows could never
                            // win; disabling the canvas is what makes the menu modal.
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
                                // Snap to the nearest width the control
                                // actually offers. The reference never lets a
                                // control take an arbitrary size -- right-click
                                // lists a fixed set, and a corner drag steps
                                // through the same set.
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

            // ---- The right-click size menu ----
            Item {
                id: sizeMenu
                // One accessor for the selection so the x/y/height bindings
                // below can guard on it. Calling selected() inline in each of
                // them evaluated against null while the menu was hidden, which
                // threw three TypeErrors on every relayout.
                readonly property var sel: ControlCenterLayout.selected()

                visible: sel !== null
                width: 132
                height: 30 + (sel ? ControlCenterLayout.catalogue[sel.type].sizes.length * 28 : 0)
                // Pinned to the selected control's top-right, clamped inside.
                x: sel ? Math.max(0, Math.min(root.canvasW - width,
                      root.cellX(sel.col) + root.cellX(sel.colSpan) - width)) : 0
                y: sel ? root.cellY(sel.row) : 0
                z: 30

                readonly property var target: sel

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#181614"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                }

                // Dismisses the menu. Needed because the canvas is disabled
                // while the menu is up: without this there would be no way to
                // close it short of Escape, and the canvas click that used to
                // do it is exactly the pass-through being fixed. Declared
                // before the rows, which are MouseAreas too, so a press on a
                // row goes to the row rather than here.
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
                    textColor: Qt.rgba(1, 1, 1, 0.45)
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
                            color: sizeHit.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: sizeRow.modelData[0] + " × " + sizeRow.modelData[1]
                                font.pixelSize: 11
                                color: sizeRow.current ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.75)
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

    // ---- "Add a control" --------------------------------------------------

    SettingsSectionLabel {
        label: "Add a control"
        Layout.topMargin: 6
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: ControlCenterLayout.palette

            delegate: Rectangle {
                id: chip
                required property var modelData
                width: chipRow.implicitWidth + 26
                height: 30
                radius: 15
                color: chipHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.055)

                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 9

                    Icon {
                        icon: chip.modelData.icon
                        size: 14
                        iconColor: Qt.rgba(1, 1, 1, 0.7)
                    }
                    StyledText {
                        text: chip.modelData.label
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Qt.rgba(1, 1, 1, 0.82)
                    }
                    StyledText {
                        text: chip.modelData.size[0] + "×" + chip.modelData.size[1]
                        font.pixelSize: 11
                        textColor: Qt.rgba(1, 1, 1, 0.4)
                    }
                }

                HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        ControlCenterLayout.add(chip.modelData.type);
                        root.takeFocus();
                    }
                }
            }
        }
    }

    // ---- Footer hint ------------------------------------------------------

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: "Drag a control to move it, pull its corner to resize, right-click for every size it supports. With one selected: arrows nudge, [ and ] step through sizes, Delete removes."
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        textColor: Qt.rgba(1, 1, 1, 0.42)
    }
}
