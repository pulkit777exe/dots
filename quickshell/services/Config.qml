pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool notchMode: data.notchMode
    readonly property int barHeight: data.barHeight
    readonly property int collapsedWidth: data.collapsedWidth
    readonly property int gapFromEdge: data.gapFromEdge
    readonly property int cardPad: data.cardPad
    readonly property int collapsedRadius: data.collapsedRadius
    readonly property int expandedRadius: data.expandedRadius
    readonly property bool statusEnabled: data.statusEnabled
    readonly property bool cardEnabled: data.cardEnabled
    readonly property bool trayEnabled: data.trayEnabled

    readonly property bool time24h: data.time24h
    readonly property bool showSeconds: data.showSeconds

    readonly property bool reduceMotion: data.reduceMotion
        || Quickshell.env("QUICKSHELL_REDUCE_MOTION") === "1"
    readonly property int movementMs: data.movementMs
    readonly property int fadeMs: data.fadeMs
    readonly property int hoverMs: data.hoverMs
    readonly property int bouncePercent: data.bouncePercent
    readonly property real springDamping: Math.max(0.45, 0.75 - bouncePercent / 100 * 0.35)

    function fade(m = 1): int { return reduceMotion ? 0 : Math.round(fadeMs * m) }
    function hover(): int { return reduceMotion ? 0 : hoverMs }
    function movement(m = 1): int { return reduceMotion ? 0 : Math.round(movementMs * m) }

    readonly property bool dnd: data.dnd
    readonly property int notifPopupTimeoutMs: data.notifPopupTimeoutMs
    readonly property int notifUrgentTimeoutMs: data.notifUrgentTimeoutMs
    readonly property real notifWidth: data.notifWidth
    readonly property bool notifShowBodyText: data.notifShowBodyText
    readonly property real notifHistoryHeight: data.notifHistoryHeight
    readonly property int osdTimeoutMs: data.osdTimeoutMs
    readonly property real osdBarThickness: data.osdBarThickness

    readonly property string accentOverride: data.accentOverride
    readonly property bool colorBurst: data.colorBurst
    readonly property int fontSize: data.fontSize

    readonly property int currentPage: data.currentPage

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
            property bool trayEnabled: true
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
