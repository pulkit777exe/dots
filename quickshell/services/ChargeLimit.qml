pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Battery charge limit. Reads the firmware's charge_control_end_threshold
// when the hardware exposes one; writes go through a root-owned helper
// installed by setup.sh (/usr/local/bin/dots-set-charge-limit, NOPASSWD
// sudoers scoped to that path, helper validates 40-100 itself). No prompt
// by design: interactive polkit cannot work until desktop processes join
// a logind session (see SECURITY.md), and the settings gesture already is
// the user's consent. Edits debounce into a single write.
Singleton {
    id: root

    // Resolved threshold node, "" when the firmware exposes none.
    property string node: ""
    readonly property bool available: node !== ""

    // Effective limit: firmware value once read, else stored preference.
    property int limit: Config.chargeLimit
    property string error: ""
    property int pending: -1

    Process {
        id: resolver
        command: ["python3", "-c",
            "import glob; ns = glob.glob('/sys/class/power_supply/BAT*/charge_control_end_threshold'); print(ns[0] if ns else '')"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = (text || "").trim();
                if (n.length > 0) {
                    root.node = n;
                    reader.command = ["cat", n];
                    reader.running = true;
                }
            }
        }
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt((text || "").trim(), 10);
                if (!isNaN(v)) root.limit = Math.max(40, Math.min(100, v));
            }
        }
    }

    Process {
        id: setter
        onExited: (code) => {
            if (code === 0) {
                root.error = "";
                root.limit = root.pending;
                Config.set("chargeLimit", root.pending);
                reader.running = true;
            } else {
                root.error = "Not applied (code " + code + ") — run ./dots packages to install the helper, then retry";
            }
            root.pending = -1;
        }
    }

    Timer {
        id: debounce
        interval: 800
        onTriggered: {
            if (setter.running) { debounce.restart(); return; }
            if (root.pending < 0 || !root.available) return;
            setter.command = ["sudo", "-n", "/usr/local/bin/dots-set-charge-limit", String(root.pending)];
            setter.running = true;
        }
    }

    function setLimit(v: int) {
        if (!root.available) return;
        const c = Math.max(40, Math.min(100, Math.round(v)));
        root.error = "";
        root.limit = c;
        root.pending = c;
        debounce.restart();
    }

    Component.onCompleted: resolver.running = true
}
