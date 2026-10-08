pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every user-facing setting, in one adapter and one file.
//
// Read through readonly projections so a value can never disagree with the
// JSON it came from; written through set(), one entry point for every key.
// Motion helpers live here too: the Motion settings page and every Behavior
// in the tree read the same numbers.

Singleton {
    id: root

    // ---- bar & island ------------------------------------------------
    readonly property bool notchMode: data.notchMode
    readonly property int barHeight: data.barHeight            // 24..56, default 33
    readonly property int collapsedWidth: data.collapsedWidth  // 60..240, default 90
    readonly property int gapFromEdge: data.gapFromEdge        // 0..40, default 11
    readonly property int cardPad: data.cardPad                // 0..12, default 3
    readonly property int collapsedRadius: data.collapsedRadius // 0..40, default 20
    readonly property int expandedRadius: data.expandedRadius  // 12..40, default 27
    readonly property bool statusEnabled: data.statusEnabled
    readonly property bool cardEnabled: data.cardEnabled

    // ---- clock --------------------------------------------------------
    readonly property bool time24h: data.time24h
    readonly property bool showSeconds: data.showSeconds

    // ---- motion -------------------------------------------------------
    readonly property bool reduceMotion: data.reduceMotion
        || Quickshell.env("QUICKSHELL_REDUCE_MOTION") === "1"
    readonly property int movementMs: data.movementMs          // 100..800, default 400
    readonly property int fadeMs: data.fadeMs                  // 50..500, default 200
    readonly property int hoverMs: data.hoverMs                // 50..400, default 150
    readonly property int bouncePercent: data.bouncePercent    // 0..100, default 40
    readonly property real springDamping: Math.max(0.45, 0.75 - bouncePercent / 100 * 0.35)

    function fade(m = 1): int { return reduceMotion ? 0 : Math.round(fadeMs * m) }
    function hover(): int { return reduceMotion ? 0 : hoverMs }
    function movement(m = 1): int { return reduceMotion ? 0 : Math.round(movementMs * m) }

    // ---- notifications & the volume/brightness OSD --------------------------
    readonly property bool dnd: data.dnd   // the Focus pill; persisted because it should survive a reload
    readonly property int notifPopupTimeoutMs: data.notifPopupTimeoutMs
    readonly property int notifUrgentTimeoutMs: data.notifUrgentTimeoutMs
    readonly property real notifWidth: data.notifWidth
    readonly property bool notifShowBodyText: data.notifShowBodyText
    readonly property real notifHistoryHeight: data.notifHistoryHeight
    readonly property int osdTimeoutMs: data.osdTimeoutMs
    readonly property real osdBarThickness: data.osdBarThickness

    // ---- appearance ---------------------------------------------------
    readonly property string accentOverride: data.accentOverride // "" or "#rrggbb"
    readonly property bool colorBurst: data.colorBurst
    readonly property int fontSize: data.fontSize                 // 11..20, default 15

    // ---- settings app -------------------------------------------------
    readonly property int currentPage: data.currentPage

    // One entry point: set("barHeight", 40). Bracket access on the adapter
    // resolves the property by name, so a new key needs a line in the
    // adapter and a projection above -- not a third setter.
    function set(key: string, value) {
        data[key] = value;
        save();
    }

    function save() {
        if (!loaded) return;
        state.writeAdapter();
    }

    property bool loaded: false

    FileView {
        id: state
        path: Quickshell.statePath("settings.json")
        watchChanges: false
        printErrors: false
        onLoaded: root.loaded = true
        onLoadFailed: root.loaded = true

        JsonAdapter {
            id: data
            property bool notchMode: false
            property int barHeight: 33
            property int collapsedWidth: 90
            property int gapFromEdge: 11
            property int cardPad: 3
            property int collapsedRadius: 20
            property int expandedRadius: 27
            property bool statusEnabled: true
            property bool cardEnabled: true
            property bool time24h: true
            property bool showSeconds: false
            property bool reduceMotion: false
            property int movementMs: 400
            property int fadeMs: 200
            property int hoverMs: 150
            property int bouncePercent: 40
            property bool dnd: false
            property int notifPopupTimeoutMs: 2000
            property int notifUrgentTimeoutMs: 6000
            property real notifWidth: 449
            property bool notifShowBodyText: true
            property real notifHistoryHeight: 200
            property int osdTimeoutMs: 1500
            property real osdBarThickness: 6
            property string accentOverride: ""
            property bool colorBurst: false
            property int fontSize: 15
            property int currentPage: 0
        }
    }
}
