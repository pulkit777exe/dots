import QtQuick
import Quickshell.Io

// Putting an image on the screen.
//
// Three backends can do it and which one exists is not something this shell
// decides at start-up, so the choice is made per call and stays in the shell
// script below rather than becoming a chain of Process objects: `&& exit 0`
// means the next backend is reached only when the last is absent or refused.
//
// There is no state here. Which wallpaper is current, and how a change to it
// is animated, are decisions about the theme and stay in Theme.qml.

QtObject {
    id: wallpaper

    readonly property Process proc: Process {}

    // hyprpaper first when it answers, then swww, then swaybg. swaybg is last
    // because it takes the wallpaper over rather than compositing over it, and
    // it is backgrounded because it does not exit on its own.
    function apply(path) {
        wallpaper.proc.command = ["bash", "-c",
            'p="' + path.replace(/"/g, '\\"') + '"; ' +
            'if command -v hyprctl >/dev/null 2>&1; then ' +
            '  hyprctl hyprpaper preload "$p" >/dev/null 2>&1; ' +
            '  hyprctl hyprpaper wallpaper ",$p" >/dev/null 2>&1 && exit 0; ' +
            '  hyprctl hyprpaper reload ",$p" >/dev/null 2>&1 && exit 0; ' +
            'fi; ' +
            'if command -v swww >/dev/null 2>&1; then swww img "$p" --transition-type fade --transition-duration 0.38; exit 0; fi; ' +
            'pkill -x swaybg >/dev/null 2>&1; swaybg -o "*" -i "$p" -m fill &'
        ];
        wallpaper.proc.running = true;
    }
}
