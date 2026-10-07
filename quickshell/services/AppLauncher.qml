pragma Singleton

import QtQuick
import Quickshell

// The application index: freedesktop .desktop entries straight from
// Quickshell's own scanner, cached alphabetically, filtered by setQuery().
// The launcher only ever reads `results` and calls launch().
Singleton {
    id: root

    property string query: ""
    property var allApps: []    // { entry, name, subtitle, iconSource, glyph }
    property var results: []

    readonly property var entries: DesktopEntries.applications.values

    function setQuery(text: string) {
        query = text;
        refilter();
    }

    function launch(result) {
        if (result && result.entry) result.entry.execute();
    }

    // Rebuilt whenever the .desktop set changes; sorting here means the
    // unfiltered list is already alphabetical.
    function refresh() {
        const apps = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay) continue;
            apps.push({
                entry: e,
                name: e.name,
                subtitle: e.comment || e.genericName || "",
                iconSource: iconSourceFor(e),
                glyph: glyphFor(e),
                keywords: String(e.keywords || "").toLowerCase(),
            });
        }
        apps.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        allApps = apps;
        refilter();
    }

    function refilter() {
        const q = query.trim().toLowerCase();
        if (q.length === 0) {
            results = allApps;
            return;
        }
        results = allApps.filter(a =>
            a.name.toLowerCase().includes(q) ||
            a.subtitle.toLowerCase().includes(q) ||
            a.keywords.includes(q)
        );
    }

    // Icon name, absolute path or an already-built url: resolved once here
    // so the row is just an Image source. Empty means "no icon", and the row
    // falls back to the glyph.
    function iconSourceFor(e): string {
        const icon = e.icon || "";
        if (icon.length === 0) return "";
        if (icon.startsWith("file://") || icon.startsWith("image://")) return icon;
        if (icon.startsWith("/")) return "file://" + icon;
        return "image://icon/" + icon;
    }

    // Material glyph for entries with no icon of their own.
    function glyphFor(e): string {
        if (e.runInTerminal) return "terminal";
        const c = String(e.categories || "").toLowerCase();
        if (c.includes("network") || c.includes("webbrowser")) return "language";
        if (c.includes("audiovideo") || c.includes("audio") || c.includes("video")) return "movie";
        if (c.includes("graphics")) return "image";
        if (c.includes("development")) return "code";
        if (c.includes("game")) return "sports_esports";
        if (c.includes("settings") || c.includes("system")) return "settings";
        return "apps";
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refresh(); }
    }

    Component.onCompleted: refresh()
}
