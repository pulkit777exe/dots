import QtQuick
import Quickshell
import Quickshell.Io

// Per-monitor overrides for the bar, layered over BarConfig, for ONE monitor.
//
// A file at monitors/<screen name>.json overrides only the keys it names.
// Every other key falls through to the global value from bar-config.json,
// so unplugging a monitor removes its override and the bar returns to
// exactly what it was -- there is no second copy of the defaults here to
// drift out of step.
//
// Only geometry may be overridden. These stay global on purpose, because a
// per-monitor copy of them would be a second source of truth for something
// that is not a property of the monitor:
//
//   notchMode, statusCircleEnabled, albumArtCircleEnabled  which parts of
//       the bar exist at all; a half-and-half bar reads as a bug
//   panelSlideIn, stageLiftOnHover, innerPadding            motion and
//       padding, tuned as one set against the global bar height
//
// Anything not in `allowed` is ignored, and says so in the log rather than
// being applied silently. That is the whole point of the list: a typo in a
// hand-written override should not quietly do nothing.
//
// ---------------------------------------------------------------------------
// ONE instance per monitor, and `screenName` is given, never set. This file
// used to be `pragma Singleton` with a mutable `screenName` and a
// `loadFor(name)` that assigned it, and it was wrong for a reason the comment
// above it used to insist was impossible. IslandMetrics.qml builds one
// IslandMetrics per screen, so on a two-monitor machine two Islands called
// `loadFor` on the one copy of this object; the last call won and both bars
// read that monitor's file. There is no "each copy is asked for its own
// screen" -- a Singleton has exactly one copy, which is the whole point of
// the pragma, and the comment claiming otherwise was the bug's cover story.
//
// So this is now an ordinary QtObject, constructed per monitor by the thing
// that already knows which monitor it is for, and `screenName` is a
// `required property`: it is set once, at construction, from the owner's own
// binding. There is no writer, so there is nothing for two screens to race
// over, and the mistake cannot come back through a second call site.
//
// That is the same shape BrightnessMonitors.qml and BrightnessMonitor.qml
// already use for the brightness fleet: per-screen instances held by the
// parent, each handed its screen as an argument. Renaming this file to
// BarConfigMonitor.qml would match BrightnessMonitor.qml exactly; the plural
// name is historical and is the second half of why this read as safe.
//
// The plural name is the only thing here that is misleading, and it is left
// alone deliberately: renaming the type means renaming the warning prefix,
// which `monitors/README.md` quotes verbatim, for no behaviour change.

QtObject {
    id: monitor

    // Keys a monitor file may set. Everything else is ignored on purpose.
    readonly property var allowed: [
        "barHeight",
        "collapsedWidth",
        "expandedHeight",
        "minimumExpandedWidth",
        "gapFromScreenEdge",
        "expandedCornerRadius",
        "collapsedCornerRadius",
        "notchFlare",
    ]

    // The name of the monitor these values apply to, e.g. "eDP-1". Required,
    // not optional: there is no sensible default screen, and a `required` that
    // is never satisfied is a load-time error naming the owner rather than a
    // monitor that silently gets nobody else's file.
    required property string screenName

    // Overrides read from the file, as a plain object. Empty when the
    // monitor has no file, which is the common case.
    property var overrides: ({})

    // Names in the file that are not in `allowed`, kept so the settings
    // page can list what was ignored instead of leaving the user to guess.
    property var rejected: []

    readonly property bool hasOverride: Object.keys(overrides).length > 0

    function value(key, fallback) {
        if (overrides && Object.prototype.hasOwnProperty.call(overrides, key))
            return overrides[key];
        return fallback;
    }

    // The file is read here, in a service that watches nothing user-visible --
    // it is re-invoked whenever a monitor file is written. Nothing outside
    // services/ touches this file: it is not on the shell/uis IPC table and it
    // has no ConfigStore key, so keeping the read here costs no window and no
    // reload.
    readonly property FileView monitorFile: FileView {
        id: monitorFile

        // A binding, not an assignment. Setting `path` imperatively after
        // the FileView is constructed does not trigger the initial load, so
        // onLoaded never fires and the override silently does nothing --
        // which is what happened on the first attempt at this. Theme.qml
        // binds its path the same way for the same reason.
        //
        // The explicit "/" matters. Quickshell.shellDir has NO trailing
        // slash, so `shellDir + "monitors/..."` produces
        // ".../quickshellmonitors/eDP-1.json", a path that does not exist.
        // A missing file is not an error here, so the override just quietly
        // never applied.
        //
        // shellDir, not configDir: configDir is deprecated and warns on
        // every startup.
        path: monitor.screenName
            ? Quickshell.shellDir + "/monitors/" + monitor.screenName + ".json"
            : ""

        watchChanges: true
        // Most monitors have no override file, and onLoadFailed below
        // handles that. printErrors would warn once per monitor for
        // something that is not wrong.
        printErrors: false

        onLoaded: readIt()
        onFileChanged: readIt()
        onLoadFailed: {
            monitor.overrides = ({});
            monitor.rejected = [];
        }

        function readIt() {
            let parsed;
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                console.warn("BarConfigMonitors: " + monitor.screenName
                             + ".json is not valid JSON, ignoring it: " + e);
                monitor.overrides = ({});
                monitor.rejected = [];
                return;
            }
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
                console.warn("BarConfigMonitors: " + monitor.screenName
                             + ".json must be a JSON object of key/value pairs, ignoring it");
                monitor.overrides = ({});
                monitor.rejected = [];
                return;
            }

            const good = {};
            const bad = [];
            for (const key of Object.keys(parsed)) {
                if (monitor.allowed.indexOf(key) < 0) {
                    bad.push(key);
                } else if (typeof parsed[key] === "number" && isFinite(parsed[key])) {
                    good[key] = parsed[key];
                } else {
                    bad.push(key + " (not a finite number)");
                }
            }
            monitor.overrides = good;
            monitor.rejected = bad;
            if (bad.length > 0) {
                console.warn("BarConfigMonitors: " + monitor.screenName
                             + ".json ignored " + bad.join(", ")
                             + " -- only geometry may be overridden per monitor");
            }
        }
    }
}
