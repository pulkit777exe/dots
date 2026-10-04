pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The shell-wide brightness: one number, one slider, one OSD.
//
// Where that number comes from is not this file's business. The panel
// backlight lives in BacklightDevice.qml -- brightnessctl to read and write,
// inotify-watch.py on the sysfs node to notice a change made outside the
// shell -- and the per-screen monitors live in BrightnessMonitors.qml: one
// BrightnessMonitor per screen, ddcutil to say which of them answer, and the
// query grammar that picks one. What is here is the arbitration between the
// two, the value the shell reports, and the IPC.
//
// The two set paths have two parsers on purpose and they are both below:
// resolveMonitorTarget() for a monitor, setGlobalBrightness() for the panel.
// See the comment on setGlobalBrightness() for why they must not be merged.

Singleton {
    id: root

    BacklightDevice { id: backlight }

    BrightnessMonitors {
        id: fleet
        requestOsd: (value) => root.osdRequested(value)
        // The one writer of the level from outside this file: a monitor that
        // changed without the shell asking -- a key on the display itself, a
        // write that arrived over DDC -- reports here, and the OSD below
        // fires off the same change signal a backlight write does.
        syncLevel: (value) => { backlight.level = value; }
    }

    // The panel backlight as the shell sees it. Read-only views of the
    // device's own answers, so nothing here can put the two out of step.
    readonly property string device: backlight.device
    readonly property int max: backlight.max
    readonly property bool available: backlight.available

    // The level lives on the backlight because every read of it starts there.
    // The fleet writes into it from syncLevel below, so the shell still has
    // exactly one brightness number whichever device answered.
    readonly property int level: backlight.level

    // `available` is the panel backlight's answer and `monitors` is the
    // fleet's, and they are independent: an external display is a brightness
    // control with no backlight behind it. The icon asks both.
    readonly property var monitors: fleet.monitors

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

    // The 1..100 clamp. 0 is what a slider would ask for at the bottom of a
    // scale, and this is the one place both the IPC path and the keybinds
    // pass through, so it is the one place that gets to decide what to do
    // with it.
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

        // No monitor: the panel. percentArg() and the brightnessctl argv
        // live with the backlight's other processes, in BacklightDevice.qml.
        backlight.setPercent(clamped)
    }

    function step(delta) {
        setBrightness(level + delta)
    }

    // "active", "model:<name>", "serial:<value>", "id:<n>" or a bare
    // connector name. Null when nothing matches, which is what sends setFor()
    // to the panel instead.
    function getMonitor(query) {
        return fleet.getMonitor(query);
    }

    property int brightnessIncrement: 5

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

    // ---- what the compositor says the outputs are ----------------------
    //
    // Kept here rather than in BrightnessMonitors.qml because it is display
    // configuration, not brightness: the refresh rate and the scale of each
    // output are read by the monitor cards in the control centre, and they
    // come from hyprctl, not from a backlight.
    property var refreshRates: ({})

    property var outputScales: ({})

    // hyprctl has reported the refresh rate as a number under `refreshRate` and
    // as a string under `refresh`, so this accepts either, and takes the
    // millihertz form -- 60000 is 60Hz -- because CcMonitorCard renders the
    // value straight into "N Hz" and 60000 is not a refresh rate anyone reads.
    Process {
        id: monitorProbe
        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    const map = {};
                    const scales = {};
                    for (const m of parsed) {
                        if (!m || !m.name) continue;

                        let hz = (typeof m.refreshRate === "number") ? m.refreshRate : m.refresh;
                        if (typeof hz === "number" && hz > 1000) hz = hz / 1000;
                        if (typeof hz === "number" && isFinite(hz) && hz > 0)
                            map[m.name] = Math.round(hz);
                        const sc = m.scale;
                        if (typeof sc === "number" && isFinite(sc) && sc > 0)
                            scales[m.name] = sc;
                    }
                    root.refreshRates = map;
                    root.outputScales = scales;
                } catch (e) {
                    // Empty on purpose: this probe only supplies labels for
                    // the monitor cards, and both properties keep their last
                    // good values when the reply does not parse.
                }
            }
        }
    }

    // Called when the display page opens and when a monitor card asks for
    // fresh numbers.
    function refreshMonitorInfo(): void {
        monitorProbe.running = true;
    }

    // The value grammar a per-monitor `setFor` accepts: "50", "50%", "+0.1",
    // "+5%", "0.1-" and "50%-" -- the last four relative, the first two
    // absolute, with "%" meaning a hundredth of the monitor's own 0..1 level.
    //
    // The global path parses its argument separately and on purpose:
    // setGlobalBrightness() treats "50%-" as unparseable where this reads it
    // as -50, so the two are not merged.
    function resolveMonitorTarget(monitor, value) {
        if (value.endsWith("%-")) {
            return (
                monitor.brightness -
                parseFloat(value.slice(0, -2)) / 100
            );
        }

        if (value.startsWith("+") && value.endsWith("%")) {
            return (
                monitor.brightness +
                parseFloat(value.slice(1, -1)) / 100
            );
        }

        if (value.endsWith("%")) {
            return parseFloat(value.slice(0, -1)) / 100;
        }

        if (value.startsWith("+")) {
            return monitor.brightness + parseFloat(value.slice(1));
        }

        if (value.endsWith("-")) {
            return (
                monitor.brightness -
                parseFloat(value.slice(0, -1))
            );
        }

        return parseFloat(value);
    }

    // The reply both setFor() branches give when their parse fails. Shared
    // because it is the same string in both -- and because it is the ONLY
    // thing they have in common. The two parses are different parsers on
    // purpose (see resolveMonitorTarget above), so there is nothing else here
    // to factor out; see setGlobalBrightness() for why.
    function parseFailure(value): string {
        return (
            "Failed to parse value: " +
            value
        );
    }

    // setFor()'s per-monitor branch. A monitor takes a 0..1 level, and its
    // grammar includes the relative forms -- "+5", "+5%", "0.1-", "50%-" --
    // that have no meaning on the global path.
    function setMonitorBrightness(monitor, value): string {
        const targetBrightness =
            resolveMonitorTarget(monitor, value)

        if (isNaN(targetBrightness)) {
            return parseFailure(value)
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

    // setFor()'s global branch, on the backlight BacklightDevice.qml drives.
    //
    // This is NOT resolveMonitorTarget, and the difference is a grammar
    // difference rather than a rounding one, so the two parsers stay apart:
    //   monitor  "50%-" is -50, "0.1" is an absolute 0.1
    //   global   "50%-" is unparseable, "0.1" is 10%
    //   global   a bare number is a fraction of full scale, so it x100
    // Merging them would either widen what the monitor path accepts or hand
    // brightnessctl the monitor path's 0..1 argument on the percent path.
    // parseFailure() above is the whole of what is genuinely shared.
    function setGlobalBrightness(value): string {
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
            return parseFailure(value)
        }

        root.setBrightness(target)

        return (
            "Set brightness to " +
            root.level +
            "%"
        )
    }

    Component.onCompleted: {
        backlight.discover.running = true;
        monitorProbe.running = true;
    }

    IpcHandler {
        target: "brightness"

        function get(): real {
            return getFor("active")
        }

        // The return type must stay declared. get() above is annotated `: real`,
        // and Qt types an unannotated callee as void, so dropping this makes the
        // call a void->real coercion. It fires lazily, the first time something
        // calls get(), so it can sit unnoticed for many reloads.
        function getFor(query: string): real {
            const monitor =
                root.getMonitor(query)

            if (monitor)
                return monitor.brightness

            return root.available
                ? root.level / 100.0
                : -1
        }

        // Both handlers must keep an explicit `: string`. They return a value,
        // so Qt types an unannotated callee as void and logs a coercion error
        // on every call that reaches them -- the same class commit 9cbbffb
        // fixed for the other handlers, which this sweep missed.
        function set(value: string): string {
            return setFor(
                "active",
                value
            )
        }

        function setFor(
            query: string,
            value: string
        ): string {
            const monitor =
                root.getMonitor(query)

            return monitor
                ? root.setMonitorBrightness(monitor, value)
                : root.setGlobalBrightness(value)
        }
    }
}
