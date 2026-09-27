pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
  AppLauncher service — thin adapter over Quickshell DesktopEntries.

  DesktopEntries owns discovery, watching, and .desktop parsing.
  This service only normalizes state for the Launcher surface.

  Consumer API (unchanged):
    allApps, query, results
    setQuery(text), launch(result), refresh()
*/

Singleton {
    id: root

    property string query: ""
    property var allApps: []     // kept for compat, populated from DesktopEntries
    property var results: []     // filtered, shaped for Launcher.qml

    signal launched(var app)
    signal launchFailed(string command)

    function setQuery(text) {
        query = text;
        _refilter();
    }

    function launch(result) {
        const app = allApps.find(a => a.name === result.title);
        if (!app) {
            launchFailed(result.title ?? "");
            return;
        }
        // Use DesktopEntry.execute() — handles working dir, env, etc.
        const entry = _findEntry(result.title);
        if (entry) {
            entry.execute();
            launched(app);
        } else {
            launchFailed(result.title ?? "");
        }
    }

    function refresh() {
        _buildIndex();
    }

    Connections {
        target: ConfigStore
        function onLauncherMaxResultsChanged() { root._refilter(); }
    }

    // ── Native desktop entries ──────────────────────────────────────
    // UntypedObjectModel exposes `values` (a QObjectList) — there is no
    // .count/.get(i) API on it, so the old count/get loop silently
    // produced an empty index (launcher showed no apps).
    readonly property var _entries: DesktopEntries.applications.values

    function _findEntry(name) {
        for (let i = 0; i < _entries.length; i++) {
            const e = _entries[i];
            if (e.name === name) return e;
        }
        return null;
    }

    function _buildIndex() {
        const apps = [];
        for (let i = 0; i < _entries.length; i++) {
            const e = _entries[i];
            if (e.noDisplay) continue;
            apps.push({
                name: e.name,
                exec: e.execString,
                icon: e.icon,
                description: e.comment || e.genericName || "",
                terminal: e.runInTerminal,
                categories: e.categories ?? [],
                _entry: e  // reference for launch
            });
        }
        allApps = apps;
        _refilter();
    }

    function _refilter() {
        const q = query.trim().toLowerCase();
        let pool = allApps;
        if (q.length > 0) {
            pool = pool.filter(a =>
                a.name.toLowerCase().includes(q) ||
                a.description.toLowerCase().includes(q) ||
                a.categories.some(c => c.toLowerCase().includes(q))
            );
        }
        results = pool.slice(0, Math.max(1, ConfigStore.launcherMaxResults)).map(a => ({
            icon: _materialIconFor(a),
            iconSource: a.icon || "",
            title: a.name,
            subtitle: a.description
        }));
    }

    function _materialIconFor(app) {
        const cats = (app.categories || []).map(c => c.toLowerCase());
        if (app.terminal || cats.includes("terminalemulator")) return "terminal";
        if (cats.includes("network") || cats.includes("webbrowser")) return "language";
        if (cats.includes("audiovideo") || cats.includes("audio") || cats.includes("video")) return "movie";
        if (cats.includes("graphics")) return "image";
        if (cats.includes("development") || cats.includes("ide")) return "code";
        if (cats.includes("office")) return "description";
        if (cats.includes("game")) return "sports_esports";
        if (cats.includes("settings") || cats.includes("system")) return "settings";
        return "apps";
    }

    // Rebuild when the desktop entries model changes (installs/uninstalls)
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root._buildIndex() }
    }

    Component.onCompleted: _buildIndex()
}
