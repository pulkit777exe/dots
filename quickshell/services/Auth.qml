pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Polkit authentication bridge. The agent daemon (scripts/polkit-agent.py)
// owns the polkit protocol; this module owns the dialog state and the
// password response file. The daemon passes everything the dialog needs
// in one JSON payload, so QML never constructs daemon-side paths.
//
// Any close path without an explicit submit/dismiss writes a cancellation,
// so the daemon can never hang waiting on a dismissed dialog.
Singleton {
    id: root

    property string cookie: ""
    property string user: ""
    property string message: ""
    property bool isRetry: false
    property string respPath: ""
    property bool settled: true

    function show(payload: string) {
        let d = null;
        try {
            d = JSON.parse(payload);
        } catch (e) {
            console.warn("Auth: ignoring malformed payload");
            return;
        }
        if (!d || !d.cookie || !d.respPath) {
            console.warn("Auth: payload missing cookie/respPath");
            return;
        }
        root.cookie = String(d.cookie).replace(/\//g, "");
        root.user = d.user || "";
        root.message = d.message || "";
        root.isRetry = !!d.retry;
        root.respPath = d.respPath;
        root.settled = false;
        respView.path = root.respPath;
        UiState.openAuth();
    }

    function submit(password: string) {
        if (root.settled || !root.respPath) return;
        respView.setText(JSON.stringify({ password: password }));
        root.settled = true;
        UiState.close();
    }

    function cancel() {
        if (!root.settled && root.respPath)
            respView.setText(JSON.stringify({ cancelled: true }));
        root.settled = true;
        UiState.close();
    }

    function dismiss(cookie: string) {
        if (String(cookie).replace(/\//g, "") !== root.cookie || root.cookie === "")
            return;
        root.settled = true;
        UiState.close();
    }

    Connections {
        target: UiState
        function onAuthOpenChanged() {
            if (!UiState.authOpen && !root.settled) root.cancel();
        }
    }

    FileView {
        id: respView
        watchChanges: false
    }
}
