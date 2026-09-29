pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ControlCenterLayout
// The authoritative model behind the Control Center arranger
// (settings/pages/ControlCenterPage.qml) and, eventually, the popover itself.
//
// The Control Center used to be a hand-written ColumnLayout: a fixed stack of
// rows, each hand-placed, with no notion of a grid, a size, or a position. That
// cannot express "drag it", "make it 3x2", or "put it in column 5", so this
// replaces that structure with an explicit list of placed controls on a
// column grid.
//
// Every mutation goes through commit(), which snapshots the previous state
// onto the undo stack before applying. Nothing else may assign to `items` --
// doing so would skip both persistence and undo, which is how the two get out
// of step with each other.
Singleton {
    id: root

    // ---- Geometry of the grid -------------------------------------------
    // Cell metrics for the arranger canvas, measured off
    // 2026-09-20_22-29-19: the row of seven empty placeholder circles is
    // 7 x 60px wide with 13px gaps, and a one-row control is 52px tall with a
    // 16px gap to the next row. The canvas is centred in the content column
    // rather than stretched, which is what the reference does -- it leaves
    // ~280px of empty content either side of the grid.
    readonly property real cellW: 60
    readonly property real cellH: 52
    readonly property real gapH: 13
    readonly property real gapV: 16

    readonly property int minColumns: 5
    readonly property int maxColumns: 9

    property int columns: 7

    // Each entry: { id, type, col, row, colSpan, rowSpan }
    property var items: defaultItems()

    property string selectedId: ""

    // NOT readonly. commit() pushes onto it and undo() pops off it, and a
    // readonly property makes both throw:
    //
    //   TypeError: Cannot assign to read-only property "undoStack"
    //     at services/ControlCenterLayout.qml[309:-1]
    //
    // That silently disabled the entire arranger. commit() runs *before*
    // the caller writes the new state, so the throw aborted resizeTo, moveTo,
    // remove, setColumns, add, tidy and reset -- each one returned without
    // doing anything, and with no visible error, because the exception was
    // swallowed inside a QML function call. Only the selection chrome
    // appeared to work, since that path does not commit.
    property var undoStack: []

    // Derived, so this one can stay readonly; it re-evaluates on each
    // reassignment of undoStack.
    readonly property int undoDepth: undoStack.length

    // ---- Control catalogue ----------------------------------------------
    // `sizes` is the list of [colSpan, rowSpan] pairs a control may take, in
    // the order [ and ] step through them. A control's size is never free-form:
    // the right-click menu offers exactly these, and resize snaps to the
    // nearest one.
    readonly property var catalogue: ({
        wifi:         { label: "Wi-Fi",         icon: "wifi",                       sizes: [[3,1],[2,1],[4,1]] },
        bluetooth:    { label: "Bluetooth",     icon: "bluetooth",                  sizes: [[3,1],[2,1],[4,1]] },
        focus:        { label: "Focus",         icon: "do_not_disturb_on",         sizes: [[3,1],[2,1]] },
        gameMode:     { label: "Game Mode",     icon: "sports_esports",            sizes: [[3,1],[2,1]] },
        lock:         { label: "Lock",          icon: "lock",                       sizes: [[1,1]] },
        nightLight:   { label: "Night Light",   icon: "dark_mode",                  sizes: [[1,1]] },
        sound:        { label: "Sound",         icon: "volume_up",                  sizes: [[7,1],[4,1],[6,1]] },
        display:      { label: "Display",       icon: "brightness_high",            sizes: [[7,1],[4,1],[6,1]] },
        notifications:{ label: "Notifications", icon: "notifications",              sizes: [[7,2],[4,2]] },
        nowPlaying:   { label: "Now Playing",   icon: "music_note",                 sizes: [[3,2],[2,2],[4,2]] },
        clipboard:    { label: "Clipboard",     icon: "content_paste",             sizes: [[3,2],[2,2]] },
        battery:      { label: "Battery",       icon: "battery_std",                sizes: [[1,1],[2,1]] },
        idleInhibit:  { label: "Keep Awake",    icon: "coffee",                     sizes: [[1,1],[2,1]] }
    })

    // The catalogue as a list, for the "Add a control" palette. Sorted by the
    // order they appear in the object above, which is the visual order in the
    // reference's own popover.
    readonly property var palette: Object.keys(catalogue).map(function (k) {
        return { type: k, label: catalogue[k].label, icon: catalogue[k].icon,
                 size: catalogue[k].sizes[0] };
    })

    // The reference's starting arrangement (2026-09-20_22-29-19, 7 columns):
    // three wide pills and a round button per row, then the two full-width
    // drill-downs, then notifications, then a row of empties.
    function defaultItems() {
        return [
            { id: "wifi",          type: "wifi",          col: 0, row: 0, colSpan: 3, rowSpan: 1 },
            { id: "focus",         type: "focus",         col: 3, row: 0, colSpan: 3, rowSpan: 1 },
            { id: "lock",          type: "lock",          col: 6, row: 0, colSpan: 1, rowSpan: 1 },
            { id: "bluetooth",     type: "bluetooth",     col: 0, row: 1, colSpan: 3, rowSpan: 1 },
            { id: "gameMode",      type: "gameMode",      col: 3, row: 1, colSpan: 3, rowSpan: 1 },
            { id: "nightLight",    type: "nightLight",    col: 6, row: 1, colSpan: 1, rowSpan: 1 },
            { id: "sound",         type: "sound",         col: 0, row: 2, colSpan: 7, rowSpan: 1 },
            { id: "display",       type: "display",       col: 0, row: 3, colSpan: 7, rowSpan: 1 },
            { id: "notifications", type: "notifications", col: 0, row: 4, colSpan: 7, rowSpan: 2 }
        ];
    }

    // ---- Queries ---------------------------------------------------------

    function byId(id) {
        for (let i = 0; i < items.length; i++)
            if (items[i].id === id) return items[i];
        return null;
    }

    function selected() { return selectedId ? byId(selectedId) : null; }

    // Every cell the placed controls currently occupy.
    function occupied(exceptId) {
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

    function fits(item, col, row, exceptId) {
        if (col < 0 || row < 0) return false;
        if (col + item.colSpan > columns) return false;
        const taken = occupied(exceptId);
        for (let r = row; r < row + item.rowSpan; r++)
            for (let c = col; c < col + item.colSpan; c++)
                if (taken.indexOf(r + ":" + c) !== -1) return false;
        return true;
    }

    // Slide a control toward (col,row) as far as it will go without
    // overlapping anything or leaving the grid. Returns the settled position.
    function settle(item, col, row) {
        let c = Math.max(0, Math.min(col, columns - item.colSpan));
        let r = Math.max(0, row);
        if (!fits(item, c, r, item.id)) {
            const dr = [-1, 1, -2, 2, -3, 3, -4, 4];
            const dc = [-1, 1, -2, 2, -3, 3];
            let moved = true;
            while (moved) {
                moved = false;
                for (const d of dr) {
                    if (fits(item, c, r + d, item.id)) { r += d; moved = true; break; }
                }
                if (moved) continue;
                for (const d of dc) {
                    if (fits(item, c + d, r, item.id)) { c += d; moved = true; break; }
                }
            }
        }
        return { col: c, row: r };
    }

    // ---- Mutations (all via commit) -------------------------------------

    function select(id) { root.selectedId = (root.selectedId === id ? "" : id); }

    function moveTo(id, col, row) {
        const it = byId(id);
        if (!it) return;
        const p = settle(it, col, row);
        if (p.col === it.col && p.row === it.row) return;
        commit();
        root.items = root.items.map(function (x) {
            return x.id === id ? { id: x.id, type: x.type, col: p.col, row: p.row,
                                   colSpan: x.colSpan, rowSpan: x.rowSpan } : x;
        });
    }

    // Resize to the offered [colSpan,rowSpan], re-settling if the new footprint
    // would overlap a neighbour. The control keeps its top-left corner.
    function resizeTo(id, colSpan, rowSpan) {
        const it = byId(id);
        if (!it) return;
        const wanted = { id: it.id, type: it.type, col: it.col, row: it.row,
                         colSpan: colSpan, rowSpan: rowSpan };
        const p = fits(wanted, it.col, it.row, id)
            ? { col: it.col, row: it.row }
            : settle(wanted, it.col, it.row);
        if (p.col === it.col && p.row === it.row &&
            it.colSpan === colSpan && it.rowSpan === rowSpan) return;
        commit();
        root.items = root.items.map(function (x) {
            return x.id === id ? { id: x.id, type: x.type, col: p.col, row: p.row,
                                   colSpan: colSpan, rowSpan: rowSpan } : x;
        });
    }

    // [ and ] -- step through the control's offered sizes.
    function cycleSize(id, delta) {
        const it = byId(id);
        if (!it) return;
        const sizes = catalogue[it.type].sizes;
        let idx = -1;
        for (let i = 0; i < sizes.length; i++)
            if (sizes[i][0] === it.colSpan && sizes[i][1] === it.rowSpan) { idx = i; break; }
        if (idx === -1) idx = 0;
        const next = sizes[(idx + delta + sizes.length) % sizes.length];
        resizeTo(id, next[0], next[1]);
    }

    function nudge(id, dCol, dRow) {
        const it = byId(id);
        if (!it) return;
        const p = settle(it, it.col + dCol, it.row + dRow);
        moveTo(id, p.col, p.row);
    }

    function remove(id) {
        if (!byId(id)) return;
        commit();
        root.items = root.items.filter(function (x) { return x.id !== id; });
        if (root.selectedId === id) root.selectedId = "";
    }

    // Add a control of `type` at the first free cell that fits it.
    function add(type) {
        const entry = catalogue[type];
        if (!entry) return -1;
        const span = entry.sizes[0];
        const probe = { id: "__probe", type: type, col: 0, row: 0,
                        colSpan: span[0], rowSpan: span[1] };
        for (let r = 0; r < 64; r++) {
            for (let c = 0; c <= columns - span[0]; c++) {
                if (fits(probe, c, r)) {
                    commit();
                    const id = type + "-" + (r * 100 + c);
                    root.items = root.items.concat([{ id: id, type: type, col: c, row: r,
                                                      colSpan: span[0], rowSpan: span[1] }]);
                    root.selectedId = id;
                    return id;
                }
            }
        }
        return -1;
    }

    // Tidy: pack everything up and left in reading order, largest first within
    // each row-band, so a ragged layout closes up without changing any sizes.
    function tidy() {
        commit();
        const sorted = root.items.slice().sort(function (a, b) {
            if (a.row !== b.row) return a.row - b.row;
            if (a.col !== b.col) return a.col - b.col;
            return a.id < b.id ? -1 : 1;
        });
        const taken = [];
        const out = [];
        for (const it of sorted) {
            let placed = null;
            for (let r = 0; r < 64 && !placed; r++) {
                for (let c = 0; c <= columns - it.colSpan; c++) {
                    let free = true;
                    for (let rr = r; rr < r + it.rowSpan && free; rr++)
                        for (let cc = c; cc < c + it.colSpan; cc++)
                            if (taken.indexOf(rr + ":" + cc) !== -1) { free = false; break; }
                    if (free) {
                        placed = { id: it.id, type: it.type, col: c, row: r,
                                   colSpan: it.colSpan, rowSpan: it.rowSpan };
                        for (let rr = r; rr < r + it.rowSpan; rr++)
                            for (let cc = c; cc < c + it.colSpan; cc++)
                                taken.push(rr + ":" + cc);
                        break;
                    }
                }
            }
            if (placed) out.push(placed);
        }
        root.items = out;
    }

    function reset() {
        commit();
        root.items = defaultItems();
        root.selectedId = "";
    }

    function setColumns(n) {
        n = Math.max(minColumns, Math.min(maxColumns, n));
        if (n === root.columns) return;
        commit();
        // Anything hanging off the right edge is pulled back in; if it still
        // does not fit it is dropped, because a control the grid cannot hold
        // has nowhere sensible to go.
        const kept = [];
        for (const it of root.items) {
            if (it.col + it.colSpan <= n) { kept.push(it); continue; }
            const probe = { id: it.id, type: it.type, col: 0, row: it.row,
                            colSpan: it.colSpan, rowSpan: it.rowSpan };
            const p = settle(probe, n - it.colSpan, it.row);
            if (p.col >= 0 && fits(probe, p.col, p.row, it.id))
                kept.push({ id: it.id, type: it.type, col: p.col, row: p.row,
                            colSpan: it.colSpan, rowSpan: it.rowSpan });
        }
        root.columns = n;
        root.items = kept;
    }

    function undo() {
        if (root.undoStack.length === 0) return;
        const prev = root.undoStack[root.undoStack.length - 1];
        // Re-push the *current* state so undo is its own inverse, then apply
        // the popped one. That makes repeated undo walk backwards through the
        // whole history instead of getting stuck on the last two states.
        root.undoStack = root.undoStack.slice(0, -1);
        commit();
        root.items = prev.items;
        root.columns = prev.columns;
        root.selectedId = "";
    }

    function commit() {
        root.undoStack = root.undoStack.concat([{ items: root.items, columns: root.columns }]);
        if (root.undoStack.length > 50) root.undoStack = root.undoStack.slice(1);
        // Deferred, not persisted here. Every caller runs commit() *before*
        // it writes the new state -- resizeTo, moveTo, remove, undo and
        // setColumns all follow this call with their assignment to items --
        // so persisting inline serialised the pre-edit layout and the file
        // always lagged one change behind, losing the last edit on restart.
        //
        // A short debounce rather than Qt.callLater: callLater never ran here
        // (and a 0ms Timer.restart() never fired either), so nothing was
        // written at all. 60ms also coalesces a drag, which commits on every
        // pointer move, into a single write of the final layout.
        persistDebounce.restart();
    }

    Timer {
        id: persistDebounce
        interval: 60
        onTriggered: root.save()
    }

    // ---- Persistence -----------------------------------------------------
    // Unlike the other three state services, `columns` and `items` are
    // genuinely mutable here -- the drag and resize handlers rewrite them in
    // eight places -- so they stay the source of truth and the adapter is
    // only the file format. It still does the parsing and the type checking,
    // which is why there is no hand-written parse of the text here.
    property bool resolved: false

    // Moves a loaded file into the live properties. Clamping the column count
    // and dropping entries the catalogue no longer has both belong here rather
    // than in a setter, so a hand-edited or stale file cannot put the grid
    // into a state the UI has no way to reach.
    //
    // `d.items` is tested for a length, not with Array.isArray: the adapter
    // hands back a JSON array wrapped in a QML value, so Array.isArray is
    // false for it even though length, filter and map all work. Guarding on
    // isArray silently dropped the whole saved layout and left the default
    // one in place.
    function applyState(d) {
        if (!d || typeof d !== "object") return;
        if (typeof d.columns === "number")
            root.columns = Math.max(root.minColumns, Math.min(root.maxColumns, d.columns));
        if (d.items && d.items.length) {
            // Drop anything whose type is no longer in the catalogue rather
            // than letting it render as a blank hole.
            root.items = d.items
                .filter(function (x) { return x && root.catalogue[x.type]; })
                .map(function (x) {
                    return { id: String(x.id), type: x.type,
                             col: x.col | 0, row: x.row | 0,
                             colSpan: x.colSpan | 0, rowSpan: x.rowSpan | 0 };
                });
        }
    }

    // Guarded on `resolved`: writing before the load resolves would save the
    // defaults straight over the saved layout. Called from commit(), which is
    // itself debounced, so this only ever runs on a real edit.
    function save() {
        if (!root.resolved) return;
        data.columns = root.columns;
        data.items = root.items;
        state.writeAdapter();
    }

    // One FileView with an adapter on it. `items` is declared as a var
    // because it is a JSON array, which the adapter round-trips unchanged.
    //
    // The adapter is fully populated by the time onLoaded runs -- measured,
    // not assumed: with a file of columns 9 and one item, the adapter's change
    // handlers all fire before onLoaded, and data.columns/data.items already
    // hold the file's values at that point. So reading them from onLoaded is
    // safe, and is the same point the text was parsed at before.
    //
    // Written with an explicit writeAdapter() from save() rather than
    // onAdapterUpdated, because loading the file also updates the adapter's
    // properties, and that would rewrite the file on every start.
    FileView {
        id: state
        path: Quickshell.statePath("control-center-layout.json")
        // Read once at startup. Watching would fight our own writes.
        watchChanges: false
        printErrors: false
        onLoaded: { root.applyState(data); root.resolved = true; }
        // No saved layout yet is the normal first-run case, not an error.
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property int columns: 7
            property var items: []
        }
    }
}
