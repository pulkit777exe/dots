import QtQuick
import Quickshell
import Quickshell.Io

// The monitors: one BrightnessMonitor per screen, which of them answer DDC,
// and how a query string picks one.
//
// The fleet is built over `Quickshell.screens` rather than over the panel
// backlight, because an external display is a brightness control in its own
// right and the panel's sysfs node says nothing about it. That is also why
// the ddcutil probe belongs here rather than in Brightness.qml: the answer to
// "which connector takes VCP 10" is a property of the connector.
//
// Two facts come out of it and both are per-output, which is why they live
// together: `getMonitor(query)` resolves "active", "model:<name>",
// "serial:<value>", "id:<n>" or a bare connector name to one monitor, and
// `ddcMonitorMap` maps connector name to the I2C bus behind it.
//
// `Variants` and `ddcProc` are properties rather than a child-object list
// because a QtObject has no default property: `Variants { }` written inside
// one fails to compile with "Cannot assign to non-existent default
// property", which the linter reports as a warning and the engine rejects at
// load.

QtObject {
    id: fleet

    // Where a value change goes: Brightness.qml owns the OSD request and the
    // shell-wide level, and this file only reports.
    required property var requestOsd
    required property var syncLevel

    property var ddcMonitors: []

    readonly property var ddcMonitorMap: {
        const map = {}

        for (const monitor of ddcMonitors)
            map[monitor.connector] = monitor

        return map
    }

    readonly property var monitors:
        variants.instances

    // Resolves a query to one monitor, or null when there is none.
    //
    // Null is a real answer and callers branch on it: with no monitor for
    // the query, a `setFor` has to fall through to the panel backlight.
    function getMonitor(query) {
        if (!fleet.monitors || fleet.monitors.length === 0)
            return null

        if (query === "active") {
            return fleet.monitors[0]
        }

        if (query.startsWith("model:")) {
            return fleet.findMonitorByField("model", query.slice(6))
        }

        if (query.startsWith("serial:")) {
            return fleet.findMonitorByField("serialNumber", query.slice(7))
        }

        if (query.startsWith("id:")) {
            return fleet.findMonitorByField(
                "name",
                String(parseInt(query.slice(3), 10))
            )
        }

        return fleet.findMonitorByField("name", query)
    }

    // modelData is the ShellScreen Variants built these from, so the monitor
    // identity fields (name, make/model, serial) live one level down. `===`
    // and not `==`: the `id:` path above normalises its argument through
    // parseInt/String, so a monitor name and the query that names it are
    // already the same type here, and a looser compare would only add
    // matches the caller did not ask for.
    function findMonitorByField(field, value) {
        return fleet.monitors.find(
            monitor =>
                monitor.modelData[field] === value
        )
    }

    // The DDC answer is per screen set, so it is re-probed whenever the set
    // changes rather than once at startup -- a screen that has just appeared
    // has not been probed for yet. The old map goes first so a connector that
    // stops answering does not go on claiming it does.
    onMonitorsChanged: {
        fleet.ddcMonitors = []
        ddcProc.running = true
    }

    readonly property Variants variants: Variants {
        model:
            Quickshell.screens

        BrightnessMonitor {
            ddcInfo:
                fleet.ddcMonitorMap[
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
                    fleet.getMonitor("active")

            requestOsd:
                (value) =>
                    fleet.requestOsd(value)

            syncLevel:
                (value) =>
                    fleet.syncLevel(value)
        }
    }

    // Which connectors have a DDC response. `--brief` prints one block per
    // display separated by a blank line; the two fields worth having are the
    // I2C bus (ddcutil needs it for setvcp) and the DRM connector (which is
    // how a Hyprland monitor name is matched to it, after the cardN- prefix
    // is dropped). A block missing either is dropped: ddcutil reports it, but
    // there is nothing to address.
    //
    // `command -v` first so a machine without ddcutil installed gets no
    // stderr in the shell's log on every screen change, and `|| true` so the
    // process exits 0 and does not look like a failure.
    readonly property Process ddcProc: Process {
        command: [
            "bash",
            "-c",
            "command -v ddcutil >/dev/null && " +
            "ddcutil detect --brief || true"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    fleet.ddcMonitors =
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
                    fleet.ddcMonitors = []
                }
            }
        }
    }
}
