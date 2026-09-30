pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io















Singleton {
    id: root

    
    
    
    
    
    
    
    readonly property real cellW: 60
    readonly property real cellH: 52
    readonly property real gapH: 13
    readonly property real gapV: 16

    readonly property int minColumns: 5
    readonly property int maxColumns: 9

    property int columns: 7

    
    property var items: defaultItems()

    property string selectedId: ""

    
    
    
    
    
    
    
    
    
    
    
    
    property var undoStack: []

    
    
    readonly property int undoDepth: undoStack.length

    
    
    
    
    
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

    
    
    
    readonly property var palette: Object.keys(catalogue).map(function (k) {
        return { type: k, label: catalogue[k].label, icon: catalogue[k].icon,
                 size: catalogue[k].sizes[0] };
    })

    
    
    
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

    

    function byId(id) {
        for (let i = 0; i < items.length; i++)
            if (items[i].id === id) return items[i];
        return null;
    }

    function selected() { return selectedId ? byId(selectedId) : null; }

    
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
        
        
        
        root.undoStack = root.undoStack.slice(0, -1);
        commit();
        root.items = prev.items;
        root.columns = prev.columns;
        root.selectedId = "";
    }

    function commit() {
        root.undoStack = root.undoStack.concat([{ items: root.items, columns: root.columns }]);
        if (root.undoStack.length > 50) root.undoStack = root.undoStack.slice(1);
        
        
        
        
        
        
        
        
        
        
        persistDebounce.restart();
    }

    Timer {
        id: persistDebounce
        interval: 60
        onTriggered: root.save()
    }

    
    
    
    
    
    
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

    
    
    
    
    
    
    
    
    
    
    
    
    FileView {
        id: state
        path: Quickshell.statePath("control-center-layout.json")
        
        watchChanges: false
        printErrors: false
        onLoaded: { root.applyState(data); root.resolved = true; }
        
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property int columns: 7
            property var items: []
        }
    }
}
