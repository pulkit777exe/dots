pragma Singleton
import QtQuick

/**
 * Single source of truth for WHAT SHAPE the Island is, WHICH PANEL is open,
 * and WHETHER it's visible at all. Reads Theme/Config but never writes them.
 *
 * Visibility is workspace-aware (see HyprlandService): the island fully
 * hides when the active workspace has any window and nothing is forcing it
 * open. Three interaction tiers on top of that:
 *   minimal -> peek (light hover, ~120ms)  -> expanded (sustained hover, ~350ms)
 * Both timers start together on hover-enter; peek just resolves first.
 *
 * panelStack is a real stack, not a fixed hierarchy, because Super+T /
 * Super+W can push theme/wallpaper directly without going through settings
 * first. "Back" always pops the stack rather than jumping to a hardcoded
 * parent.
 */
QtObject {
    id: root

    // -- top-level shape --
    // idle | mediaChange | volumeToast | brightnessToast | notifToast
    // | expanded | launcher | locked
    property string shape: "idle"

    // light-hover reveal tier: wifi/battery/last-played, no full expand.
    // Orthogonal to `shape` -- it's the same IdlePill, just showing more.
    property bool peeking: false

    // panels pushed while shape === "expanded": "settings" | "wifi"
    // | "bluetooth" | "audio" | "theme" | "wallpaper" | "power"
    property var panelStack: []

    readonly property var currentPanel: panelStack.length > 0
        ? panelStack[panelStack.length - 1] : null

    // -- visibility --
    // Forced visible whenever the island is doing anything other than
    // sitting idle/peeking -- a toast, the launcher, an expanded panel, or
    // the lock screen should never be hidden mid-interaction regardless of
    // what's on the workspace.
    readonly property bool forcedVisible: shape !== "idle"
    readonly property bool visible: forcedVisible || peeking

    // -- entering --

    function openExpanded() {
        shape = "expanded"
    }

    function openLauncher() {
        // top-level, deliberately NOT nested under expanded's panel stack
        shape = "launcher"
    }

    function pushPanel(name) {
        if (shape !== "expanded") shape = "expanded"
        panelStack = panelStack.concat([name])
    }

    // entry points for Super+T / Super+W: push directly onto an otherwise
    // empty stack, so popPanel() below naturally lands back on idle instead
    // of an assumed "settings" parent that was never actually visited.
    function openThemeDirect() { shape = "expanded"; panelStack = ["theme"] }
    function openWallpaperDirect() { shape = "expanded"; panelStack = ["wallpaper"] }
    function openSettingsDirect() { shape = "expanded"; panelStack = ["settings"] }
    function openPowerDirect() { shape = "expanded"; panelStack = ["power"] }

    // -- leaving --

    function popPanel() {
        if (panelStack.length === 0) {
            close()
            return
        }
        panelStack = panelStack.slice(0, -1)
        if (panelStack.length === 0) close()
    }

    function close() {
        shape = "idle"
        panelStack = []
        peeking = false
        collapseTimer.stop()
    }

    // -- transient toasts (media/volume/brightness/notification) --

    function showToast(kind, timeoutMs) {
        if (shape === "expanded" || shape === "launcher" || shape === "locked")
            return // don't interrupt an active view with a toast
        shape = kind
        collapseTimer.interval = timeoutMs || Config.toastTimeout
        collapseTimer.restart()
    }

    property Timer collapseTimer: Timer {
        onTriggered: if (root.shape !== "expanded" && root.shape !== "launcher") root.shape = "idle"
    }

    // -- hover-intent: two timers started together, peek resolves first --

    property Timer peekOpenTimer: Timer {
        interval: Config.peekOpenDelay
        onTriggered: root.peeking = true
    }
    property Timer peekCloseTimer: Timer {
        interval: Config.peekCloseDelay
        onTriggered: root.peeking = false
    }
    property Timer expandOpenTimer: Timer {
        interval: Config.hoverOpenDelay
        onTriggered: root.openExpanded()
    }
    property Timer expandCloseTimer: Timer {
        interval: Config.hoverCloseDelay
        onTriggered: if (root.shape === "expanded" && root.panelStack.length === 0) root.close()
    }

    // called both by the always-present hot-zone (island hidden/minimal)
    // and by the pill itself once visible -- same hover contract either way.
    function onIslandHoverEntered() {
        peekCloseTimer.stop()
        expandCloseTimer.stop()
        if (shape === "idle") {
            peekOpenTimer.restart()
            expandOpenTimer.restart()
        }
    }
    function onIslandHoverExited() {
        peekOpenTimer.stop()
        expandOpenTimer.stop()
        if (peeking) peekCloseTimer.restart()
        if (shape === "expanded" && panelStack.length === 0) expandCloseTimer.restart()
    }
    function onExpandedHoverEntered() {
        expandCloseTimer.stop()
    }
    function onExpandedHoverExited() {
        expandCloseTimer.restart()
    }

    function onLock() { shape = "locked" }
    function onUnlock() { close() }
}
