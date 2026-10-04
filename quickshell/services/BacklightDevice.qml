import QtQuick
import Quickshell
import Quickshell.Io

// The panel's own backlight: /sys/class/backlight/<device>/brightness.
//
// Four processes, and this file is all four of them:
//
//   discover   brightnessctl -m -l, once, to learn the device name and the
//              full-scale value the kernel will accept
//   watcher    inotify-watch.py on the sysfs node, so a change made outside
//              the shell -- another keybind, a daemon, the DE's own key
//              handler -- is noticed at all
//   reader     cat the node, because the sysfs value is the only truth
//              about what the panel is actually showing
//   setter     brightnessctl set, to write
//
// It is a hardware adapter and nothing else: it holds the device name, the
// full-scale maximum, the current percentage and whether a backlight was
// found at all, and it does not decide what those mean. Brightness.qml owns
// the shell-wide brightness number and the rules about who may write it.
//
// The four are properties rather than a child-object list because a QtObject
// has no default property -- `Process { }` written inside one fails to
// compile with "Cannot assign to non-existent default property", which
// the linter reports as a warning and the engine rejects at load.

QtObject {
    id: backlight

    property string device: ""
    property int max: 100
    property int level: 0
    property bool available: false

    // A percentage as the string brightnessctl gets in its argv.
    //
    // The plain `clamped + "%"` this replaces could carry binary-float noise
    // into a child process: 0.33 * 100 is 33.000000000000004, so a percentage
    // that arrived over IPC as "0.33" -- or that any multiply produced -- went
    // out as "33.000000000000004%". Six decimals is far below any real
    // backlight's granularity (one step of a 0..960 sysfs file is ~0.1%) and
    // far above the noise floor, so it drops the noise without rounding a
    // percentage anybody asked for: 33.5 stays "33.5", 33.000000000000004
    // becomes "33".
    function percentArg(pct): string {
        return Number(pct.toFixed(6)) + "%";
    }

    // Write a percentage. The 1..100 clamp deliberately is NOT here: it is in
    // Brightness.qml's setBrightness(), the one place both the IPC path and
    // the keybinds pass through, and a second clamp would be a second answer
    // to "what is the floor".
    function setPercent(pct) {
        setter.command = [
            "brightnessctl",
            "set",
            backlight.percentArg(pct)
        ];

        setter.running = true;
    }

    readonly property Process reader: Process {
        command:
            backlight.device
                ? [
                    "cat",
                    "/sys/class/backlight/" +
                        backlight.device +
                        "/brightness"
                  ]
                : []

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (line) => {
                const raw = parseInt(line)

                if (
                    !isNaN(raw) &&
                    backlight.max > 0
                ) {
                    backlight.level =
                        Math.round(
                            (raw / backlight.max) * 100
                        )
                }
            }
        }
    }

    // The retry for a watch that never got established. inotify-watch.py
    // exits 1 when the path it was given does not exist -- which is what
    // happens if the device node shows up after the shell does. Without this
    // the level would freeze at the last successful read.
    readonly property Timer restartWatcher: Timer {
        interval: 3000

        onTriggered:
            watcher.running = true
    }

    readonly property Process watcher: Process {
        command:
            backlight.device
                ? [
                    Quickshell.shellDir +
                        "/scripts/inotify-watch.py",
                    "/sys/class/backlight/" +
                        backlight.device +
                        "/brightness"
                  ]
                : []

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (line) =>
                reader.running = true
        }

        onExited:
            restartWatcher.start()
    }

    // `brightnessctl -m -l` prints one line per light as
    // name,type,current,max. Only a backlight is a brightness control -- the
    // rest are LEDs (keyboard caps, network ports) and taking one of those
    // would make the slider write to a network indicator.
    // Fires once at construction. The extract that moved this file here
    // dropped the trigger, which left the Process declared, documented and
    // never started -- so `device`, `max` and `available` stayed at their
    // defaults and the non-DDC fallback wrote to no device at all.
    Component.onCompleted: discover.running = true

    readonly property Process discover: Process {
        command: [
            "brightnessctl",
            "-m",
            "-l"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (line) => {
                const parts = line.split(",")

                if (
                    parts.length >= 5 &&
                    parts[1] === "backlight"
                ) {
                    backlight.device = parts[0]

                    backlight.max =
                        parseInt(parts[4]) || 100

                    backlight.level =
                        parseInt(parts[3]) || 0

                    backlight.available = true

                    // The watch path is built from the device name, so the
                    // watch has to be torn down and rebuilt when the name
                    // changes -- which is the first time it is known at all.
                    watcher.running = false
                    watcher.running = true
                }
            }
        }
    }

    readonly property Process setter: Process {
        onExited:
            // Read back rather than assume the write landed. It costs one
            // `cat`, and it is the only way the slider ends up showing the
            // level the panel is really at when a write is refused.
            reader.running = true
    }
}
