pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persists compositor settings to the JSON store, regenerates the Hyprland
// override file, then reloads Hyprland. Reload is debounced so dragging a
// slider writes one file and issues one reload instead of dozens.
Singleton {
    id: root

    property bool pending: false
    property string error: ""

    function apply() {
        pending = true;
        debounce.restart();
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: {
            root.pending = false;
            if (writer.running) {
                debounce.restart();
                return;
            }
            writer.running = true;
        }
    }

    Process {
        id: writer
        command: ["python3", Quickshell.shellDir + "/scripts/generate-hypr-conf.py"]
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("HyprSettings: generator failed", root.error);
                return;
            }
            root.error = "";
            reload.restart();
        }
    }

    Timer {
        id: reload
        interval: 80
        onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
    }
}
