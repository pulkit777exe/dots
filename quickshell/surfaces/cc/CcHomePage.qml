import QtQuick
import QtQuick.Layouts
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


    // Built once per layout change, not once per cell per re-evaluation:
    // rowTop() used to call this itself, so the whole 64-row table was
    // rebuilt for every cell, and it depends on Notifications.active, which
    // moves on every toast.
    readonly property var rowTops: {
        const tops = []
        let y = 0
        for (let r = 0; r < 64; r++) {
            tops.push(y)
            let tallest = 0
            for (const it of layoutItems) {
                if (it.row !== r) continue
                const h = rowHeightFor(it)
                if (h > tallest) tallest = h
            }
            if (tallest === 0) break
            y += tallest + 10
        }
        return tops
    }

    function rowTop(r) {
        return rowTops[r] !== undefined ? rowTops[r] : 0
    }


    readonly property real firstRowBottom:
        rowTops.length < 2 ? Math.min(height, 70) : rowTops[1] - 5


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


    readonly property int notifHomeHeight: Math.max(
        176, 14 * 2 + 8 * 2 + (Notifications.active.length > 0
            ? Math.min(64 * Notifications.active.length, ConfigStore.notifHistoryHeight)
            : 18))

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
