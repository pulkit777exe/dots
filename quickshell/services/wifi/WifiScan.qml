import QtQuick
import Quickshell.Io

// The AP list: every nmcli that reads it, the parse, the dedupe, and the
// scan lifecycle.
//
// Wifi.qml owns what the list means -- `networks`, `connected`, `ssid`,
// `strength`, and whether the radio is on -- and this file owns the only way
// the list is produced. The two meet in one place: `refresh()` goes in, and
// one `reported(...)` comes out carrying the finished list with the active
// entry already picked out of it.
//
// Two processes and one timer:
//
//   list     nmcli -g ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY d w
//   rescan   nmcli dev wifi list --rescan yes
//   settle   10s, puts NetworkManager's own scanner back down afterwards
//
// Nothing else, and in particular no polling. The 5s and 60s timers live in
// Wifi.qml and reach this file through refresh(); they are the tuning -- the
// 5s one runs only while the control centre's wifi page is open -- and there
// is deliberately nothing here for them to poll.
//
// The Process and the Timer are properties rather than a child-object list
// because a QtObject has no default property: `Process { }` written inside
// one fails to compile with "Cannot assign to non-existent default
// property", which the linter reports as a warning and the engine rejects at
// load.

QtObject {
    id: prober

    // NetworkManager's wifi device, or null until one has been found. Bound by
    // the parent rather than passed per call, so a device that turns up after
    // this file was built is the one that gets scanned with, and there is
    // nothing to re-point when it changes.
    required property var device

    // Called with { list, active } for every reply that carries APs -- `list`
    // deduped and sorted, `active` the connected entry or null. A reply with
    // no APs still reports, with an empty list, because only Wifi.qml knows
    // whether the radio is off and an empty list is therefore believable.
    required property var reported

    // Whether a scan is in flight. This is the whole of Wifi.qml's
    // `scanning`, which used to be a bool this parent wrote from three
    // places; there is one writer now.
    property bool busy: false

    // Read the list. The only thing that starts listProc. Wifi.qml's
    // refreshStatus() calls it -- that is what `nmcli monitor` and both poll
    // timers land on -- and so does rescanProc's exit below.
    function refresh() {
        listProc.running = true;
    }

    // Ask for a fresh scan: NetworkManager's own scanner on, a rescan request
    // out, and the settle timer armed to put the scanner back down. The timer
    // is armed only when there is a device to stand back down, which is what
    // the `if` around it has always said.
    function rescan() {
        prober.busy = true;

        if (prober.device) {
            prober.device.scannerEnabled = true;
            settle.restart();
        }

        rescanProc.running = true;
    }

    // Both ends of `busy` are keyed off these three, and the polls in
    // Wifi.qml touch none of them -- which is the point of the split.
    //
    // `busy` comes back down twice, and did before the split too: the rescan's
    // exit clears it as soon as the rescan is over, and the settle timer
    // clears it again 10s later for the case where the rescan never finished
    // and left NetworkManager's scanner up.
    readonly property Process listProc: Process {
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]

        stdout: StdioCollector {
            onStreamFinished: {
                const all = prober.parse(text);
                const deduped = prober.deduplicate(all);

                prober.reported({
                    list: deduped,
                    active: deduped.find(n => n.active) ?? null
                });
            }
        }
    }

    readonly property Process rescanProc: Process {
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]

        onExited: {
            prober.busy = false;
            prober.refresh();
        }
    }

    readonly property Timer settle: Timer {
        interval: 10000

        onTriggered: {
            prober.busy = false;
            if (prober.device) prober.device.scannerEnabled = false;
        }
    }

    // `nmcli -g` answers with no header and one line per AP, so the columns are
    // exactly the order of the -g argument on listProc: active, signal, freq,
    // ssid, bssid, security.
    //
    // `signal` is nmcli's own 0-100 and is taken as it stands. That is NOT the
    // scale `WifiNetwork.signalStrength` is on -- NetworkManager reports that
    // one as a 0-1 fraction, and the only reader of it is syncState() in
    // Wifi.qml, which multiplies by 100. Reading either number on the other's
    // scale renders "0%" or "1%", which is all a signal is worth once mixed up.
    //
    // A colon inside an SSID comes back escaped as `\:` and nothing else is
    // escaped, so the fields cannot simply be split on ":". The escape is
    // swapped for a placeholder that cannot occur in an SSID before splitting
    // and put back afterwards. A line with no SSID is dropped: an AP with no
    // name is not a row anything can render.
    function parse(output) {
        if (!output || output.length === 0) return [];
        const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
        const rep = new RegExp("\\\\:", "g");
        const rep2 = new RegExp(PLACEHOLDER, "g");

        return output.trim().split("\n").filter(line => line && line.length > 0).map(n => {
            const net = n.replace(rep, PLACEHOLDER).split(":");
            const rawSsid = net[3] ? net[3].replace(rep2, ":") : "";
            const rawBssid = net[4] ? net[4].replace(rep2, ":") : "";
            const rawSec = net[5] ? net[5] : "";
            return {
                active: net[0] === "yes",
                strength: parseInt(net[1] || "0", 10) || 0,
                frequency: parseInt(net[2] || "0", 10) || 0,
                ssid: rawSsid.trim(),
                bssid: rawBssid.trim(),
                security: rawSec.trim(),
                secured: rawSec.trim().length > 0 && !rawSec.includes("NONE")
            };
        }).filter(n => n.ssid && n.ssid.length > 0);
    }

    // One row per SSID.
    //
    // NetworkManager reports every BSSID of a network as its own AP, so a mesh
    // set with a band router and two satellites would otherwise render four
    // rows under one name. The winner is the connected one where there is
    // one and the strongest otherwise, and the sort puts active rows first and
    // the rest by strength -- which is the order the page draws them in.
    function deduplicate(netList) {
        if (!netList || netList.length === 0) return [];
        const map = new Map();
        for (const net of netList) {
            const existing = map.get(net.ssid);
            if (!existing) {
                map.set(net.ssid, net);
            } else {
                if (net.active && !existing.active) {
                    map.set(net.ssid, net);
                } else if (!net.active && !existing.active) {
                    if (net.strength > existing.strength) {
                        map.set(net.ssid, net);
                    }
                }
            }
        }
        return Array.from(map.values()).sort((a, b) => (Number(b.active) - Number(a.active) || b.strength - a.strength));
    }
}