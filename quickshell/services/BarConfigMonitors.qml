pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Per-monitor overrides for the bar, layered over BarConfig.
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

Singleton {
    id: root

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

    // The name of the monitor these values apply to, set by Island per
    // screen instance. Quickshell builds one Island per screen, so each
    // copy of this singleton is asked for its own screen's name.
    property string screenName: ""

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

    function loadFor(name) {
        screenName = name;
    }

    FileView {
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
        path: root.screenName
            ? Quickshell.shellDir + "/monitors/" + root.screenName + ".json"
            : ""

        watchChanges: true
        // Most monitors have no override file, and onLoadFailed below
        // handles that. printErrors would warn once per monitor for
        // something that is not wrong.
        printErrors: false

        onLoaded: readIt()
        onFileChanged: readIt()
        onLoadFailed: {
            root.overrides = ({});
            root.rejected = [];
        }

        function readIt() {
            let parsed;
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                console.warn("BarConfigMonitors: " + root.screenName
                             + ".json is not valid JSON, ignoring it: " + e);
                root.overrides = ({});
                root.rejected = [];
                return;
            }
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
                console.warn("BarConfigMonitors: " + root.screenName
                             + ".json must be a JSON object of key/value pairs, ignoring it");
                root.overrides = ({});
                root.rejected = [];
                return;
            }

            const good = {};
            const bad = [];
            for (const key of Object.keys(parsed)) {
                if (root.allowed.indexOf(key) < 0) {
                    bad.push(key);
                } else if (typeof parsed[key] === "number" && isFinite(parsed[key])) {
                    good[key] = parsed[key];
                } else {
                    bad.push(key + " (not a finite number)");
                }
            }
            root.overrides = good;
            root.rejected = bad;
            if (bad.length > 0) {
                console.warn("BarConfigMonitors: " + root.screenName
                             + ".json ignored " + bad.join(", ")
                             + " -- only geometry may be overridden per monitor");
            }
        }
    }
}
