pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    property string query: ""
    property var allApps: []     
    property var results: []     

    function setQuery(text) {
        query = text;
        refilter();
    }

    function launch(result) {
        const app = allApps.find(a => a.name === result.title);
        if (!app) {
            return;
        }
        
        const entry = findEntry(result.title);
        if (entry) {
            entry.execute();
        }
    }

    function refresh() {
        buildIndex();
    }

    Connections {
        target: ConfigStore
        function onLauncherMaxResultsChanged() { root.refilter(); }
    }

    
    
    
    
    readonly property var entries: DesktopEntries.applications.values

    function findEntry(name) {
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.name === name) return e;
        }
        return null;
    }

    function buildIndex() {
        const apps = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay) continue;
            apps.push({
                name: e.name,
                exec: e.execString,
                icon: e.icon,
                description: e.comment || e.genericName || "",
                terminal: e.runInTerminal,
                categories: e.categories ?? [],
            });
        }
        allApps = apps;
        refilter();
    }

    function refilter() {
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
            icon: materialIconFor(a),
            iconSource: a.icon || "",
            title: a.name,
            subtitle: a.description
        }));
    }

    function materialIconFor(app) {
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

    
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.buildIndex() }
    }

    Component.onCompleted: buildIndex()
}
