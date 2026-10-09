pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool hasHyprlock: false
    property bool hasHyprshutdown: false

    Process {
        id: probe
        command: ["bash", "-c",
            "command -v hyprlock >/dev/null && echo -n y || echo -n n; " +
            "command -v hyprshutdown >/dev/null && echo y || echo n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text || "").trim();
                root.hasHyprlock = t[0] === "y";
                root.hasHyprshutdown = t.length > 1 && t[1] === "y";
            }
        }
    }
    Component.onCompleted: probe.running = true

    function run(cmd) {
        Quickshell.execDetached(cmd);
    }

    function lock() {
        run(hasHyprlock ? ["hyprlock"] : ["loginctl", "lock-session"]);
    }

    function suspend() {
        run(["systemctl", "suspend"]);
    }

    function logOut() {
        run(hasHyprshutdown ? ["hyprshutdown"] : ["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }

    function reboot() {
        run(hasHyprshutdown ? ["hyprshutdown", "--post-cmd", "systemctl reboot"] : ["systemctl", "reboot"]);
    }

    function powerOff() {
        run(hasHyprshutdown ? ["hyprshutdown", "--post-cmd", "systemctl poweroff"] : ["systemctl", "poweroff"]);
    }
}
