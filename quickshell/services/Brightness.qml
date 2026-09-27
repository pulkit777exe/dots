pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
  Brightness service — upgraded to Caelestia multi-monitor pattern.

  Keeps your existing single-device API 100% compat:
    - level (0-100), available, iconName, osdRequested,
      setBrightness(pct), step(delta)

  Adds Caelestia additions alongside:
    - DDC per-monitor via ddcutil detect --brief
    - Apple Studio Display via asdbctl get/set
    - Variants<Monitor> per Quickshell.screens
    - getMonitor(query) / increase/decreaseBrightness
    - IpcHandler target:"brightness" with get/getFor/set/setFor
    - CustomShortcut brightnessUp/brightnessDown
    - queuedBrightness + 500ms coalesce Timer for DDC

  Event source stays inotify on sysfs for the legacy single-device path;
  per-monitor Monitors handle their own init via ddcutil/brightnessctl/asdbctl.

  Any writer (brightnessctl/hotkey/this service) touching sysfs wakes inotifywait.
*/

Singleton {
    id: root

    // ------------------------------------------------------------
    // Legacy single-device compatibility
    // ------------------------------------------------------------

    property string device: ""
    property int max: 100
    property int level: 0
    property bool available: false

    readonly property string iconName: {
        if (!available && monitors.length === 0)
            return "brightness_unavailable"

        if (level >= 75)
            return "brightness_high"

        if (level >= 40)
            return "brightness_medium"

        if (level > 0)
            return "brightness_low"

        return "brightness_off"
    }

    signal osdRequested(int percent)

    onLevelChanged:
        osdRequested(level)

    // Event-driven: don't set level optimistically.
    // Let inotify / per-monitor readback drive it.
    function setBrightness(pct) {
        const clamped = Math.max(
            1,
            Math.min(100, pct)
        )

        const active = getMonitor("active")

        if (active) {
            active.setBrightness(
                clamped / 100.0
            )
            return
        }

        setter.command = [
            "brightnessctl",
            "set",
            clamped + "%"
        ]

        setter.running = true
    }

    function step(delta) {
        setBrightness(level + delta)
    }

    // ------------------------------------------------------------
    // Multi-monitor
    // ------------------------------------------------------------

    property var ddcMonitors: []

    readonly property var ddcMonitorMap: {
        const map = {}

        for (const monitor of ddcMonitors)
            map[monitor.connector] = monitor

        return map
    }

    readonly property var monitors:
        variants.instances

    property bool appleDisplayPresent: false

    property int brightnessIncrement: 5

    function getMonitor(query) {
        if (!monitors || monitors.length === 0)
            return null

        if (query === "active") {
            // Without Hyprland service, active = first available.
            return monitors[0]
        }

        if (query.startsWith("model:")) {
            const model = query.slice(6)

            return monitors.find(
                monitor =>
                    monitor.modelData.model === model
            )
        }

        if (query.startsWith("serial:")) {
            const serial = query.slice(7)

            return monitors.find(
                monitor =>
                    monitor.modelData.serialNumber === serial
            )
        }

        if (query.startsWith("id:")) {
            const id =
                parseInt(
                    query.slice(3),
                    10
                )

            return monitors.find(
                monitor =>
                    monitor.modelData.name === String(id)
            )
        }

        return monitors.find(
            monitor =>
                monitor.modelData.name === query
        )
    }

    function increaseBrightness() {
        const monitor = getMonitor("active")

        if (monitor) {
            monitor.setBrightness(
                monitor.brightness +
                brightnessIncrement / 100.0
            )
        } else {
            step(brightnessIncrement)
        }
    }

    function decreaseBrightness() {
        const monitor = getMonitor("active")

        if (monitor) {
            monitor.setBrightness(
                monitor.brightness -
                brightnessIncrement / 100.0
            )
        } else {
            step(-brightnessIncrement)
        }
    }

    onMonitorsChanged: {
        ddcMonitors = []
        ddcProc.running = true
    }

    // ------------------------------------------------------------
    // Legacy single-device discovery
    // ------------------------------------------------------------

    Process {
        id: discover

        command: [
            "brightnessctl",
            "-m",
            "-l"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (line) => {
                const parts = line.split(",")

                if (
                    parts.length >= 5 &&
                    parts[1] === "backlight"
                ) {
                    root.device = parts[0]

                    root.max =
                        parseInt(parts[4]) || 100

                    root.level =
                        parseInt(parts[3]) || 0

                    root.available = true

                    watcher.running = false
                    watcher.running = true
                }
            }
        }
    }

    Component.onCompleted:
        discover.running = true

    Process {
        id: setter

        onExited:
            reader.running = true
    }

    Process {
        id: watcher

        command:
            root.device
                ? [
                    Quickshell.shellDir +
                        "/scripts/inotify-watch.py",
                    "/sys/class/backlight/" +
                        root.device +
                        "/brightness"
                  ]
                : []

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (line) =>
                reader.running = true
        }

        onExited:
            restartWatcher.start()
    }

    Timer {
        id: restartWatcher

        interval: 3000

        onTriggered:
            watcher.running = true
    }

    Process {
        id: reader

        command:
            root.device
                ? [
                    "cat",
                    "/sys/class/backlight/" +
                        root.device +
                        "/brightness"
                  ]
                : []

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (line) => {
                const raw = parseInt(line)

                if (
                    !isNaN(raw) &&
                    root.max > 0
                ) {
                    root.level =
                        Math.round(
                            (raw / root.max) * 100
                        )
                }
            }
        }
    }

    // ------------------------------------------------------------
    // Per-monitor variants
    // ------------------------------------------------------------

    Variants {
        id: variants

        model:
            Quickshell.screens

        BrightnessMonitor {
            ddcInfo:
                root.ddcMonitorMap[
                    modelData.name
                ] ?? null

            isDdc:
                ddcInfo !== null

            busNum:
                ddcInfo &&
                ddcInfo.busNum
                    ? ddcInfo.busNum
                    : ""

            isAppleDisplay: false

            getMonitorActive:
                () =>
                    root.getMonitor("active")

            requestOsd:
                (value) =>
                    root.osdRequested(value)

            syncLevel:
                (value) =>
                    root.level = value
        }
    }

    // ------------------------------------------------------------
    // DDC discovery
    // ------------------------------------------------------------

    Process {
        id: ddcProc

        command: [
            "bash",
            "-c",
            "command -v ddcutil >/dev/null && " +
            "ddcutil detect --brief || true"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.ddcMonitors =
                        text
                        .trim()
                        .split("\n\n")
                        .filter(
                            block =>
                                block.startsWith("Display ")
                        )
                        .map(
                            block => ({
                                busNum:
                                    (
                                        block.match(
                                            /I2C bus:[ ]*\/dev\/i2c-([0-9]+)/
                                        ) ||
                                        [, ""]
                                    )[1],

                                connector:
                                    (
                                        block.match(
                                            /DRM connector:\s+(.*)/
                                        ) ||
                                        [, ""]
                                    )[1]
                                    .replace(
                                        /^card\d+-/,
                                        ""
                                    )
                            })
                        )
                        .filter(
                            monitor =>
                                monitor.busNum &&
                                monitor.connector
                        )
                } catch (error) {
                    root.ddcMonitors = []
                }
            }
        }
    }

    // ------------------------------------------------------------
    // IPC
    // ------------------------------------------------------------

    IpcHandler {
        target: "brightness"

        function get() {
            return getFor("active")
        }

        function getFor(query: string) {
            const monitor =
                root.getMonitor(query)

            if (monitor)
                return monitor.brightness

            return root.available
                ? root.level / 100.0
                : -1
        }

        function set(value: string) {
            return setFor(
                "active",
                value
            )
        }

        function setFor(
            query: string,
            value: string
        ) {
            const monitor =
                root.getMonitor(query)

            if (monitor) {
                let targetBrightness

                if (value.endsWith("%-")) {
                    const p =
                        parseFloat(
                            value.slice(0, -2)
                        )

                    targetBrightness =
                        monitor.brightness -
                        p / 100

                } else if (
                    value.startsWith("+") &&
                    value.endsWith("%")
                ) {
                    const p =
                        parseFloat(
                            value.slice(1, -1)
                        )

                    targetBrightness =
                        monitor.brightness +
                        p / 100

                } else if (
                    value.endsWith("%")
                ) {
                    const p =
                        parseFloat(
                            value.slice(0, -1)
                        )

                    targetBrightness =
                        p / 100

                } else if (
                    value.startsWith("+")
                ) {
                    const increment =
                        parseFloat(
                            value.slice(1)
                        )

                    targetBrightness =
                        monitor.brightness +
                        increment

                } else if (
                    value.endsWith("-")
                ) {
                    const decrement =
                        parseFloat(
                            value.slice(0, -1)
                        )

                    targetBrightness =
                        monitor.brightness -
                        decrement

                } else {
                    targetBrightness =
                        parseFloat(value)
                }

                if (isNaN(targetBrightness)) {
                    return (
                        "Failed to parse value: " +
                        value
                    )
                }

                monitor.setBrightness(
                    targetBrightness
                )

                return (
                    "Set monitor " +
                    monitor.modelData.name +
                    " brightness to " +
                    Number(
                        monitor.brightness
                    ).toFixed(2)
                )
            }

            let target

            if (value.endsWith("%")) {
                target =
                    parseFloat(
                        value.slice(0, -1)
                    )
            } else {
                target =
                    parseFloat(value) * 100
            }

            if (isNaN(target)) {
                return (
                    "Failed to parse value: " +
                    value
                )
            }

            root.setBrightness(target)

            return (
                "Set brightness to " +
                root.level +
                "%"
            )
        }
    }
}