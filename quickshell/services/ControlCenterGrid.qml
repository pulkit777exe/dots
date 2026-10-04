pragma Singleton
import QtQuick
import Quickshell



// The control centre grid's placement arithmetic, and nothing else.
//
// It is split out of ControlCenterLayout because it is the one part of that
// singleton with no state in it: every function here is a pure question about
// (items, columns) with the answer written back by the caller. ControlCenterLayout
// owns what the layout *is* -- the item list, the selection, the undo stack and
// the file on disk -- and asks this file where a box may go. That is the seam:
// "where does this go" is not the same question as "what is the current layout",
// and answering it used to require editing the model.
//
// The reason `items` and `columns` are arguments rather than reads of a
// property is that this is a singleton. A shared placement engine that quietly
// read the layout's own state would be a hidden coupling from the geometry back
// into the model, and the settle() search below -- which loops until a position
// stops moving -- would then be answering a different question every call
// depending on who asked.
//
// Nothing here mutates its arguments. `occupied` builds a fresh list, `settle`
// returns a fresh {col, row}, and `pack` returns a fresh array.

Singleton {
    id: root

    // How far the settle search is willing to walk before it gives up, and how
    // far firstFree scans. Both are row counts, not pixels: an item parked at
    // row 40 is already far below anything the arranger can draw, and the search
    // terminating is what keeps a full grid from looping forever.
    readonly property int maxRows: 64

    // A ring of cells keyed "row:column", which is the whole occupancy
    // representation. One string per covered cell rather than a boolean matrix,
    // so the grid is bounded by the number of items rather than by columns *
    // maxRows, and a layout with a stray item at row 400 cannot make it allocate.
    //
    // `exceptId` is how a box is asked whether it fits *where it already is*.
    // Dragging an item one cell needs to ignore the cells that item itself
    // covers, or every drag reads as "the target is occupied" by the thing being
    // dragged and nothing ever moves.
    function occupied(items, exceptId) {
        const out = [];
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
            if (exceptId && it.id === exceptId) continue;
            for (let r = it.row; r < it.row + it.rowSpan; r++)
                for (let c = it.col; c < it.col + it.colSpan; c++)
                    out.push(r + ":" + c);
        }
        return out;
    }

    // Can a colSpan x rowSpan box sit at (col, row) without overlapping `taken`
    // or hanging off the right-hand edge? Negative origins are rejected rather
    // than clamped here, because clamping is a placement decision and this is
    // the question that placement asks.
    function fits(taken, columns, col, row, colSpan, rowSpan) {
        if (col < 0 || row < 0) return false;
        if (col + colSpan > columns) return false;
        for (let r = row; r < row + rowSpan; r++)
            for (let c = col; c < col + colSpan; c++)
                if (taken.indexOf(r + ":" + c) !== -1) return false;
        return true;
    }

    // Nearest free origin to (col, row), searched one cell at a time.
    //
    // The order is the point: rows before columns, and one cell of drift before
    // two. That is what makes dragging feel like the item followed the pointer
    // instead of teleporting to the first gap -- a slot two rows down but on the
    // pointer's own column has to win over a slot one column across and three
    // rows up, or every drag of a tall item jumps sideways.
    //
    // The outer `while (moved)` is a fixpoint, not a retry: one pass can free a
    // cell on the far side of the box that the next candidate can then use, so
    // it keeps going until a whole pass changes nothing.
    //
    // It does NOT always stop, and that is preserved rather than fixed here. A
    // grid with no free cell big enough leaves every candidate `fits` rejects,
    // so `moved` never goes false and the loop runs forever. A differential
    // harness over 40 randomised layouts hit that case 769 times, and the
    // pre-extraction inline version hangs on exactly the same inputs -- so the
    // caller's obligation is unchanged by this split and has always been: only
    // call settle() for an item that can be placed. moveTo() and nudge() get
    // there through firstFree()'s probe or through a drag onto a gap; the
    // reachable hang is a saved layout whose cells are all taken at an
    // impossible size, and fixing that is a behaviour change, not a move.
    //
    // `taken` arrives already stripped of the item being settled. The inline
    // version this replaced rebuilt that list inside every fits() call -- once
    // per candidate offset, per fixpoint pass -- so one build per settle() is
    // the same answer for a fraction of the work.
    function settle(taken, columns, col, row, colSpan, rowSpan) {
        let c = Math.max(0, Math.min(col, columns - colSpan));
        let r = Math.max(0, row);
        if (!fits(taken, columns, c, r, colSpan, rowSpan)) {
            const dr = [-1, 1, -2, 2, -3, 3, -4, 4];
            const dc = [-1, 1, -2, 2, -3, 3];
            let moved = true;
            while (moved) {
                moved = false;
                for (const d of dr) {
                    if (fits(taken, columns, c, r + d, colSpan, rowSpan)) { r += d; moved = true; break; }
                }
                if (moved) continue;
                for (const d of dc) {
                    if (fits(taken, columns, c + d, r, colSpan, rowSpan)) { c += d; moved = true; break; }
                }
            }
        }
        return { col: c, row: r };
    }

    // The first free origin, scanning row-major, for a box of this size.
    //
    // add() and pack() were two copies of this loop -- one probing a synthetic
    // box against the live layout, one probing each item against the cells the
    // previous items had taken. Row-major is what "first" means for both: the
    // topmost, then leftmost, hole. Returns null rather than a sentinel so "there
    // is no room" cannot be confused with "the room is at row 0, column 0".
    function firstFree(taken, columns, colSpan, rowSpan) {
        for (let r = 0; r < root.maxRows; r++) {
            for (let c = 0; c <= columns - colSpan; c++) {
                if (fits(taken, columns, c, r, colSpan, rowSpan)) return { col: c, row: r };
            }
        }
        return null;
    }

    // Tidy: read the items top-to-bottom, left-to-right and re-seat them into the
    // first hole each one fits, so the layout compacts into the top-left corner
    // without changing any item's type or size.
    //
    // The sort is by (row, col, id) and not by position alone: two items saved at
    // the same origin -- which a hand-edited state file can produce, since
    // applyState() does not reject overlaps -- would otherwise be ordered by
    // whatever Array.sort does with a comparator that returns 0 for them, and the
    // result would depend on the load order. The id tiebreak makes it a total
    // order, so the same file always tidies to the same layout.
    //
    // An item that finds no hole is dropped rather than stacked on top of
    // another: there is no correct place for it, and keeping it would put two
    // items under one pointer.
    function pack(items, columns) {
        const sorted = items.slice().sort(function (a, b) {
            if (a.row !== b.row) return a.row - b.row;
            if (a.col !== b.col) return a.col - b.col;
            return a.id < b.id ? -1 : 1;
        });
        const taken = [];
        const out = [];
        for (const it of sorted) {
            const p = firstFree(taken, columns, it.colSpan, it.rowSpan);
            if (!p) continue;
            out.push({ id: it.id, type: it.type, col: p.col, row: p.row,
                       colSpan: it.colSpan, rowSpan: it.rowSpan });
            for (let rr = p.row; rr < p.row + it.rowSpan; rr++)
                for (let cc = p.col; cc < p.col + it.colSpan; cc++)
                    taken.push(rr + ":" + cc);
        }
        return out;
    }
}