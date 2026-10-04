import QtQuick
import Quickshell.Io

// The command layer: every nmcli that asks NetworkManager to *do* something.
//
//   radio      nmcli radio wifi on|off
//   connect    nmcli device wifi connect <ssid> [--password ..] [--bssid ..]
//   disconnect nmcli device disconnect <iface>
//   forget     nmcli connection delete <ssid>
//
// Rescanning is NOT here: it belongs to the scan lifecycle, so it belongs to
// WifiScan.qml beside the `busy` flag it clears and the timer that arms it.
// One scan, one nmcli.
//
// It is a process adapter and nothing else, the same shape BacklightDevice.qml
// is for brightnessctl: it holds the argv each command needs and it does not
// decide what any of it means. `enabled`, `connected`, `ssid`, `strength`,
// `activeInterface` and the AP list belong to Wifi.qml, which is also what
// decides whether a command is worth running at all -- so the same guard
// ("only if the radio is off", "only while this page is open") stays on the
// side that knows the answer.
//
// Three things come back out, and all three are arguments rather than
// reach-back into the parent:
//
//   requestRefresh   any command exited, so the readers should run again. The
//                    child cannot call Wifi's refreshStatus() because it does
//                    not know the parent exists, so Wifi.qml hands in a
//                    callback that does -- the `syncLevel`/`requestOsd` shape
//                    BrightnessMonitors.qml uses.
//   radioResolved    the on/off nmcli actually applied.
//   the callback     passed in per connect() call by whoever wants the
//                    result, already shaped into the object
//                    ControlCenter.qml's two password flows expect.
//
// No polling and no timers here either. Everything that fires on a schedule
// is in Wifi.qml, which is why nothing in this file can be running unless the
// shell asked for it.
//
// The Processes are properties rather than a child-object list because a
// QtObject has no default property: `Process { }` written inside one fails to
// compile with "Cannot assign to non-existent default property", which the
// linter reports as a warning and the engine rejects at load.

QtObject {
    id: cmds

    // Called after every command below exits. Wifi.qml passes
    // `() => root.refreshStatus()`.
    required property var requestRefresh

    // Called with the answer nmcli gave for the radio. Wifi.qml owns `enabled`
    // -- it reads it off the NetworkManager device -- so this reports the
    // command's answer rather than being trusted to set it.
    required property var radioResolved

    // The argv is an argument list and never a string, so an SSID containing a
    // space, a quote or a `;` is one argv entry rather than a shell to inject
    // into. See SECURITY.md.
    function connect(targetSsid, password, bssid, callback) {
        if (!targetSsid) return;
        let cmd = ["nmcli", "device", "wifi", "connect", targetSsid];
        if (password && password.length > 0) {
            cmd.push("password", password);
        }
        if (bssid && bssid.length > 0) {
            cmd.push("bssid", bssid);
        }
        const proc = connectProc;
        proc.cb = callback;
        proc.targetSsid = targetSsid;
        proc.command = cmd;
        proc.running = true;
    }

    function forget(targetSsid) {
        forgetProc.ssidArg = targetSsid;
        forgetProc.running = true;
    }

    // The interface is an argument because it is Wifi.qml's: it comes from
    // `nmcli device status` there, and "wifi" is the fallback nmcli itself
    // would have picked on a machine with one wireless device.
    function disconnect(iface) {
        disconnectProc.ifaceArg = iface;
        disconnectProc.running = true;
    }

    // `enable` is the caller's answer, not this file's, so the exit handler
    // reports it back rather than deriving it again.
    function radio(enable) {
        radioProc.cmdState = enable ? "on" : "off";
        radioProc.running = true;
    }

    readonly property Process radioProc: Process {
        property string cmdState: "on"
        command: ["nmcli", "radio", "wifi", cmdState]
        onExited: (code) => {
            cmds.radioResolved(radioProc.cmdState === "on");
            cmds.requestRefresh();
        }
    }

    readonly property Process disconnectProc: Process {
        // A property the argv binds to rather than a command assigned per
        // call, so the argument stays the single source of the argv exactly as
        // it was when this binding read the parent directly -- and so a second
        // disconnect() while the first is still running cannot rebuild the
        // command out from under a live process.
        property string ifaceArg: ""
        command: ["nmcli", "device", "disconnect", ifaceArg || "wifi"]
        onExited: cmds.requestRefresh()
    }

    readonly property Process forgetProc: Process {
        property string ssidArg: ""
        command: ["nmcli", "connection", "delete", ssidArg]
        onExited: cmds.requestRefresh()
    }

    readonly property Process connectProc: Process {
        property var cb: null
        // Written by connect() and not read anywhere, here or above. It is the
        // SSID the attempt was for, and the callback below already carries the
        // answer, so nothing needs it; kept because it was here before.
        property string targetSsid: ""
        stdout: StdioCollector { id: connectStdout }
        stderr: StdioCollector { id: connectStderr }
        onExited: (code) => {
            const err = connectStderr.text ? connectStderr.text.trim() : "";
            const out = connectStdout.text ? connectStdout.text.trim() : "";
            const needsPass = err.includes("Secrets were required") || err.includes("password") || err.includes("No secrets provided");
            const success = (code === 0);

            if (connectProc.cb) {
                connectProc.cb({
                    success: success,
                    needsPassword: needsPass,
                    output: out,
                    error: err,
                    exitCode: code
                });
            }
            cmds.requestRefresh();
        }
    }
}