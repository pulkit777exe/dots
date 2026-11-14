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
    readonly property int chargeLimit: data.chargeLimit
    readonly property int lockTimeoutSec: data.lockTimeoutSec
    readonly property int displayTimeoutSec: data.displayTimeoutSec
    readonly property int suspendTimeoutSec: data.suspendTimeoutSec
    readonly property bool idleSeparateCharging: data.idleSeparateCharging
    readonly property int cLockTimeoutSec: data.cLockTimeoutSec
    readonly property int cDisplayTimeoutSec: data.cDisplayTimeoutSec
    readonly property int cSuspendTimeoutSec: data.cSuspendTimeoutSec

    readonly property int currentPage: data.currentPage

    readonly property int gapsIn: data.gapsIn
    readonly property int gapsOut: data.gapsOut
    readonly property int borderSize: data.borderSize
    readonly property int rounding: data.rounding
    readonly property real activeOpacity: data.activeOpacity
    readonly property real inactiveOpacity: data.inactiveOpacity
    readonly property bool dimInactive: data.dimInactive
    readonly property real dimStrength: data.dimStrength
    readonly property bool shadowEnabled: data.shadowEnabled
    readonly property int shadowRange: data.shadowRange
    readonly property bool blurEnabled: data.blurEnabled
    readonly property int blurSize: data.blurSize
    readonly property int blurPasses: data.blurPasses
    readonly property bool animationsEnabled: data.animationsEnabled

    readonly property string kbLayout: data.kbLayout
    readonly property string kbVariant: data.kbVariant
    readonly property int repeatRate: data.repeatRate
    readonly property int repeatDelay: data.repeatDelay
    readonly property bool numlock: data.numlock
    readonly property real sensitivity: data.sensitivity
    readonly property string accelProfile: data.accelProfile
    readonly property bool naturalScroll: data.naturalScroll
    readonly property bool tapToClick: data.tapToClick
    readonly property bool disableWhileTyping: data.disableWhileTyping
    readonly property string scrollMethod: data.scrollMethod

    readonly property var monitors: data.monitors
    readonly property var autostart: data.autostart

    readonly property bool nightLightEnabled: data.nightLightEnabled
    readonly property int nightLightTemperature: data.nightLightTemperature

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
            property int chargeLimit: 100
            property int lockTimeoutSec: 120
            property int displayTimeoutSec: 300
            property int suspendTimeoutSec: 600
            property bool idleSeparateCharging: false
            property int cLockTimeoutSec: 300
            property int cDisplayTimeoutSec: 600
            property int cSuspendTimeoutSec: 1800
            property int currentPage: 0
            property int gapsIn: 5
            property int gapsOut: 10
            property int borderSize: 2
            property int rounding: 10
            property real activeOpacity: 1.0
            property real inactiveOpacity: 1.0
            property bool dimInactive: true
            property real dimStrength: 0.25
            property bool shadowEnabled: true
            property int shadowRange: 4
            property bool blurEnabled: true
            property int blurSize: 7
            property int blurPasses: 2
            property bool animationsEnabled: true
            property string kbLayout: "us"
            property string kbVariant: ""
            property int repeatRate: 25
            property int repeatDelay: 600
            property bool numlock: true
            property real sensitivity: 0
            property string accelProfile: "adaptive"
            property bool naturalScroll: false
            property bool tapToClick: true
            property bool disableWhileTyping: true
            property string scrollMethod: "two_finger"
            property var monitors: ({})
            property var autostart: []
            property bool nightLightEnabled: false
            property int nightLightTemperature: 4000
        }
    }
}
