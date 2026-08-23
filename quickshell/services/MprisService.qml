pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/** Wraps playerctl for the media pill (Image 1) and Control Center scrubber
 *  (Image 2). playerctl is explicitly "mostly useful for testing/debugging"
 *  per the stack notes -- if Quickshell's own MPRIS module is available in
 *  your version, prefer that over shelling out on every poll. Left as a
 *  process-based implementation here since it needs zero extra dependencies. */
QtObject {
    id: root

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"   // Playing | Paused | Stopped
    property real positionSec: 0
    property real lengthSec: 0

    function togglePlay() { runCmd(["playerctl", "play-pause"]) }
    function next() { runCmd(["playerctl", "next"]) }
    function previous() { runCmd(["playerctl", "previous"]) }

    function runCmd(cmd) {
        actionProcess.command = cmd
        actionProcess.running = true
    }

    property Process actionProcess: Process {
        onExited: root.refresh()
    }

    function refresh() {
        metadataProcess.running = true
    }

    // one formatted call rather than several separate playerctl invocations.
    // {{position}} and {{mpris:length}} are raw microsecond integers (unlike
    // {{duration(...)}}, which returns an already-formatted mm:ss string --
    // requesting that and never parsing it back was why positionSec/lengthSec
    // stayed at 0 forever and the scrubber never appeared).
    property Process metadataProcess: Process {
        command: ["playerctl", "metadata", "--format",
            "{{status}}\t{{title}}\t{{artist}}\t{{mpris:artUrl}}\t{{position}}\t{{mpris:length}}"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const parts = line.split("\t")
                if (parts.length < 6) return
                root.playbackStatus = parts[0]
                root.title = parts[1]
                root.artist = parts[2]
                root.artUrl = parts[3]
                const posUs = parseInt(parts[4])
                const lenUs = parseInt(parts[5])
                root.positionSec = isNaN(posUs) ? 0 : posUs / 1000000
                root.lengthSec = isNaN(lenUs) ? 0 : lenUs / 1000000
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.playbackStatus = "Stopped"
                root.positionSec = 0
                root.lengthSec = 0
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
