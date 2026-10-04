pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The persisted control centre layout: which controls exist, where each one
// sits, which is selected, and the file that remembers all of it between runs.
//
// What this file deliberately does NOT hold is the placement arithmetic -- where
// a box may go, how a dragged item finds the nearest free cell, how "tidy"
// compacts the layout. That is ControlCenterGrid, a stateless singleton of pure
// functions over (items, columns), and it is asked rather than read: the model
// owns what the layout is, the grid answers where a thing fits. Keeping the two
// apart is what lets the geometry be read, tested and reasoned about without
// dragging the file format, the undo stack and the debounced writer along with
// it.
//
// Every mutator below follows the same three steps, and the order is the
// contract: commit() snapshots the current state for undo and arms the
// debounce, THEN the items change. commit() reads `items` and `columns`, so a
// mutator that assigned first and committed second would push the state it just
// replaced onto the undo stack -- undo would become redo.

Singleton {
    id: root

    // Cell metrics. Read by the arranger canvas to convert (col, row) to pixels
    // and by nothing else; they are here rather than on the canvas because the
    // canvas has to agree with the persisted spans about what a colSpan means.
    readonly property real cellW: 60
    readonly property real cellH: 52
    readonly property real gapH: 13
    readonly property real gapV: 16

    // Why the clamp is a floor and not zero: a five-column layout is what the
    // smallest control grid can hold, and a three-column layout persisted from a
    // narrower window would place the first item in a column the arranger cannot
    // draw. Better to come back up to the floor than to render off the canvas.
    readonly property int minColumns: 5
    readonly property int maxColumns: 9

    property int columns: 7

    property var items: defaultItems()

    // Empty string, not null: select() toggles, and `null === null` would make
    // the first click on an already-selected item a no-op that reads as a
    // dropped click.
    property string selectedId: ""

    property var undoStack: []
    readonly property int undoDepth: undoStack.length

    // Every control the arranger can place, with the sizes it may take.
    //
    // `sizes` is ordered largest-first and `add()` uses sizes[0], so the order is
    // the default a newly-added control arrives at. ArrangerCanvas's size popup
    // renders it in this order too, which is why it is a list rather than a
    // set: the menu is this order.
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

    // The "add a control" row, flattened from the catalogue in declaration
    // order. Derived rather than a second hand-written list, because a palette
    // chip that offered a control the canvas could not place -- or missed one
    // entirely -- would be a silent disagreement between two tables.
    readonly property var palette: Object.keys(catalogue).map(function (k) {
        return { type: k, label: catalogue[k].label, icon: catalogue[k].icon,
                 size: catalogue[k].sizes[0] };
    })

    // What an installation with no state file gets. Note that this leaves
    // clipboard, battery, idleInhibit, nowPlaying and gameMode out: those are
    // opt-in, and a default layout that carried all thirteen would make the
    // control centre a dashboard rather than a control panel.
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

    // ---- queries -----------------------------------------------------------

    function byId(id) {
        for (let i = 0; i < items.length; i++)
            if (items[i].id === id) return items[i];
        return null;
    }

    // null, not undefined, so `if (sel)` in the canvas's size popup is false for
    // "nothing selected" rather than true for a lookup that returned nothing.
    function selected() { return selectedId ? byId(selectedId) : null; }

    // ---- selection ---------------------------------------------------------

    function select(id) { root.selectedId = (root.selectedId === id ? "" : id); }

    // ---- placement ---------------------------------------------------------
    //
    // Every function below that changes where something sits builds its
    // occupancy once -- with itself excluded, because an item is being asked
    // about its own cells -- asks ControlCenterGrid for a legal position, and
    // assigns only if the position actually differs. That last check is what
    // stops a drag that lands where the item already is from pushing a
    // no-op onto the undo stack, which would make Undo appear to do nothing.

    function moveTo(id, col, row) {
        const it = byId(id);
        if (!it) return;
        const p = ControlCenterGrid.settle(
            ControlCenterGrid.occupied(items, id), columns,
            col, row, it.colSpan, it.rowSpan);
        if (p.col === it.col && p.row === it.row) return;
        commit();
        root.items = root.items.map(function (x) {
            return x.id === id ? { id: x.id, type: x.type, col: p.col, row: p.row,
                                   colSpan: x.colSpan, rowSpan: x.rowSpan } : x;
        });
    }

    // Resizing is placement too: the new footprint may no longer fit where the
    // item is, so the same settle() decides where it lands. The comparison
    // covers span as well as position, because a resize that only changes the
    // footprint still changes the layout and still has to be undoable.
    function resizeTo(id, colSpan, rowSpan) {
        const it = byId(id);
        if (!it) return;
        const taken = ControlCenterGrid.occupied(items, id);
        const p = ControlCenterGrid.fits(taken, columns, it.col, it.row, colSpan, rowSpan)
            ? { col: it.col, row: it.row }
            : ControlCenterGrid.settle(taken, columns, it.col, it.row, colSpan, rowSpan);
        if (p.col === it.col && p.row === it.row &&
            it.colSpan === colSpan && it.rowSpan === rowSpan) return;
        commit();
        root.items = root.items.map(function (x) {
            return x.id === id ? { id: x.id, type: x.type, col: p.col, row: p.row,
                                   colSpan: colSpan, rowSpan: rowSpan } : x;
        });
    }

    // Step to the next or previous entry in the type's own sizes list, wrapping.
    // An item whose current span is not in the list -- only reachable by
    // hand-editing the state file -- starts from the largest, so the first
    // bracket press snaps it to something the size popup can cycle from.
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
        const p = ControlCenterGrid.settle(
            ControlCenterGrid.occupied(items, id), columns,
            it.col + dCol, it.row + dRow, it.colSpan, it.rowSpan);
        moveTo(id, p.col, p.row);
    }

    // ---- adding and removing ----------------------------------------------

    function remove(id) {
        if (!byId(id)) return;
        commit();
        root.items = root.items.filter(function (x) { return x.id !== id; });
        if (root.selectedId === id) root.selectedId = "";
    }

    // Drop a new control into the first hole big enough for its default size,
    // and select it so the user can move or size it without hunting for it.
    //
    // -1 means the grid is full at this size. The caller shows nothing rather
    // than a failure, which is the one place in this file where "did not happen"
    // is silent: adding is a palette click with no dialog to report into.
    //
    // The generated id is type + origin rather than a counter, so two adds can
    // never collide and the id stays meaningful when read back out of the file.
    function add(type) {
        const entry = catalogue[type];
        if (!entry) return -1;
        const span = entry.sizes[0];
        const p = ControlCenterGrid.firstFree(
            ControlCenterGrid.occupied(items), columns, span[0], span[1]);
        if (!p) return -1;
        commit();
        const id = type + "-" + (p.row * 100 + p.col);
        root.items = root.items.concat([{ id: id, type: type, col: p.col, row: p.row,
                                          colSpan: span[0], rowSpan: span[1] }]);
        root.selectedId = id;
        return id;
    }

    // ---- whole-layout operations ------------------------------------------

    function tidy() {
        commit();
        root.items = ControlCenterGrid.pack(root.items, root.columns);
    }

    function reset() {
        commit();
        root.items = defaultItems();
        root.selectedId = "";
    }

    // Narrowing drops what cannot fit rather than scaling it: a three-column
    // control in a five-column grid has no honest smaller size, and squeezing it
    // would give it a footprint the arranger's own catalogue says it does not
    // have. An item whose settled position still does not fit is dropped -- at
    // that point the grid is full and there is nowhere left to put it.
    function setColumns(n) {
        n = Math.max(minColumns, Math.min(maxColumns, n));
        if (n === root.columns) return;
        commit();
        const kept = [];
        for (const it of root.items) {
            if (it.col + it.colSpan <= n) { kept.push(it); continue; }
            const taken = ControlCenterGrid.occupied(items, it.id);
            const p = ControlCenterGrid.settle(taken, n, n - it.colSpan, it.row,
                                              it.colSpan, it.rowSpan);
            if (p.col >= 0 && ControlCenterGrid.fits(taken, n, p.col, p.row,
                                                    it.colSpan, it.rowSpan))
                kept.push({ id: it.id, type: it.type, col: p.col, row: p.row,
                            colSpan: it.colSpan, rowSpan: it.rowSpan });
        }
        root.columns = n;
        root.items = kept;
    }

    // Undo restores the whole layout -- items AND columns -- as one step. They
    // are one snapshot because they change together: a column change that
    // dropped an item is not undoable without the item coming back.
    //
    // The pop happens before commit(), so the commit() records the state being
    // undone rather than the state being restored to. Redo is the same button
    // again, which is all this has ever claimed.
    function undo() {
        if (root.undoStack.length === 0) return;
        const prev = root.undoStack[root.undoStack.length - 1];
        root.undoStack = root.undoStack.slice(0, -1);
        commit();
        root.items = prev.items;
        root.columns = prev.columns;
        root.selectedId = "";
    }

    // ---- persistence -------------------------------------------------------

    // Snapshot for undo, then arm the debounce. Both halves matter and they are
    // the same function: every mutator calls exactly this, so the 50-deep cap
    // and the 60ms coalescing cannot drift apart from the code they protect.
    function commit() {
        root.undoStack = root.undoStack.concat([{ items: root.items, columns: root.columns }]);
        if (root.undoStack.length > 50) root.undoStack = root.undoStack.slice(1);
        persistDebounce.restart();
    }

    // 60ms, and restarting rather than checking a flag. A drag emits a commit
    // per motion event; coalescing them means the file is written once when the
    // pointer stops, not sixty times while it moves. `restart()` is what makes
    // that true -- a plain start on an already-running timer would fire at the
    // first tick instead of the last.
    Timer {
        id: persistDebounce
        interval: 60
        onTriggered: root.save()
    }

    // Nothing is written before the file has been read. A save that ran against
    // the built-in defaults would overwrite a real layout with defaultItems() on
    // a slow disk, and the user would come back to a control centre they had
    // arranged. `resolved` is the flag for exactly that ordering.
    property bool resolved: false

    // Tested for a length, not with Array.isArray: the adapter's `var`
    // arrays arrive wrapped in a QML value, so isArray is false for them
    // even though length/filter/map all work. Guarding on isArray drops
    // the whole saved layout silently.
    function applyState(d) {
        if (!d || typeof d !== "object") return;
        if (typeof d.columns === "number")
            root.columns = Math.max(root.minColumns, Math.min(root.maxColumns, d.columns));
        if (d.items && d.items.length) {
            // Anything whose type is no longer in the catalogue is dropped
            // rather than kept as a placeholder. A control the shell cannot draw
            // is a hole in the grid that tidy() would then refuse to fill,
            // because the hole is still occupied by something.
            root.items = d.items
                .filter(function (x) { return x && root.catalogue[x.type]; })
                .map(function (x) {
                    return { id: String(x.id), type: x.type,
                             col: x.col | 0, row: x.row | 0,
                             colSpan: x.colSpan | 0, rowSpan: x.rowSpan | 0 };
                });
        }
    }

    function save() {
        if (!root.resolved) return;
        data.columns = root.columns;
        data.items = root.items;
        state.writeAdapter();
    }

    // watchChanges: false on purpose. This is a file the shell owns and writes;
    // watching it would let a write land back as a load, and applyState() would
    // then reset selectedId and lose the selection mid-drag. Nothing else
    // edits it.
    FileView {
        id: state
        path: Quickshell.statePath("control-center-layout.json")

        watchChanges: false
        printErrors: false
        // onLoadFailed also sets resolved: a missing state file is the normal
        // first-run case, and leaving it false would disable saving forever on
        // every machine that had never had one.
        onLoaded: { root.applyState(data); root.resolved = true; }
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property int columns: 7
            property var items: []
        }
    }
}