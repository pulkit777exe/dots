pragma ComponentBehavior: Bound

import QtQuick
import "../../components"
import "../../services"


// CcHomePage.qml -- the control centre's home grid.
//
// Extracted from ControlCenter.qml. The grid, the row table and the input-leak
// gate all move together because they are one thing: which cells sit on top of
// what, and which of them still take a click. `firstRowBottom` is the line the
// drill card covers from, and ControlCenter reads it to place that card, so the
// gate and the geometry cannot come apart.

Item {
    id: root


    CcTokens { id: cc }
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }

    // ControlCenter owns the view name and the popover anchor; this page only
    // says which cell was pressed.
    property bool drillOpen: false
    property Item panel
    signal drillRequested(string view, point origin)

    readonly property var layoutItems: ControlCenterLayout.items
    readonly property int cols: ControlCenterLayout.columns


    readonly property real cellW: (width - (cols - 1) * 10) / cols


    function colX(c) { return c * (cellW + 10) }


    // The control-centre layout is sparse and user-editable, so derive offsets
    // from the rows that actually exist instead of maintaining a fixed-size
    // table. This stays correct for both the default grid and rearranged items.
    readonly property var rowTops: {
        const heights = {}
        for (const item of layoutItems) {
            const row = item.row
            heights[row] = Math.max(heights[row] || 0, rowHeightFor(item))
        }

        const rows = Object.keys(heights).map(Number).sort((a, b) => a - b)
        const tops = {}
        let y = 0
        for (const row of rows) {
            tops[row] = y
            y += heights[row] + 10
        }
        return tops
    }

    readonly property var rows: Object.keys(rowTops).map(Number).sort((a, b) => a - b)

    function rowTop(row) { return rowTops[row] ?? 0 }

    readonly property real firstRowBottom: {
        if (rows.length < 2) return Math.min(height, 70)
        return rowTop(rows[1]) - 5
    }


    function rowHeightFor(it) {
        switch (it.type) {
        case "lock": case "nightLight": case "idleInhibit": case "battery":
            return 60
        case "sound": case "display":
            return 52
        case "notifications":
            return root.notifHomeHeight
        default:
            return 57
        }
    }


    // The notification row's reserved height. This is the arithmetic the card
    // in CcControl actually draws -- 14 margin + the header row + 8 spacing +
    // the list + 14 margin -- because the row table cannot read the card's own
    // implicitHeight from here, and writing a second, differently-shaped
    // formula for it is exactly how the two drifted: this used to reserve
    // 44 + min(64n, hist), which at two notifications came to 176 while the
    // card drew 188, so the last row overflowed the height the panel was sized
    // from. 16 is the header row's line box (StyledText at pixelSize 12) and
    // 17 the empty-state line's; the 176 floor covers the empty case, where
    // the arithmetic would ask for only 69.
    readonly property int notifHomeHeight: {
        const n = Notifications.active.length
        const inner = n > 0
            ? 16 + 8 + Math.min(72 * n - 8, ConfigStore.notifHistoryHeight)
            : 16 + 8 + 17
        return Math.max(176, inner + 28)
    }

    // The grid's own bottom, in page coordinates: the deepest cell's lower
    // edge. It follows the resolved row offsets, so a rearrangement cannot
    // leave a hand-maintained panel height behind.
    readonly property real contentBottom: {
        let bottom = 0
        for (const it of layoutItems) {
            const cellBottom = rowTop(it.row) + rowHeightFor(it)
            if (cellBottom > bottom) bottom = cellBottom
        }
        return bottom
    }

    Repeater {
        model: root.layoutItems

        delegate: CcControl {
            id: placed
            required property var modelData

            readonly property real w: root.colX(modelData.colSpan) - 10
            readonly property real yTop: root.rowTop(modelData.row)

            controlType: modelData.type
            x: root.colX(modelData.col)
            y: yTop
            width: w
            height: placed.cellHeight

            // A drill page is drawn over this grid from firstRowBottom
            // down, and the card covering it is a plain Rectangle -- it
            // takes no input, so every cell underneath stayed clickable
            // through it. The Bluetooth page's on/off switch lands exactly
            // on the Night Light disc in row 1, so one tap turned Bluetooth
            // off *and* the night light on (the screen going yellow); the
            // same leak made the drill pages' back arrow re-open the page
            // it sits on. Cells the drill card covers stop taking input
            // while it covers them, and only then: on the home view every
            // cell is the way into a page, so all of them stay live. Row 0
            // ends above that line and keeps working during a drill, which
            // is what makes it the page switcher.
            enabled: !root.drillOpen
                || yTop + cellHeight <= root.firstRowBottom

            panel: root.panel
            onDrillRequested: (view, origin) => root.drillRequested(view, origin)
        }
    }
}
