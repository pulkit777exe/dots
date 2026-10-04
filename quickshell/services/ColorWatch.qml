import QtQml
import Quickshell.Io

// Noticing edits to colors/ and asking the theme to re-discover, debounced.
//
// This is I/O and nothing else: it watches, it debounces, it emits
// reloadRequested. What to do about a reload -- running list-themes.py -- is
// Theme.qml's business, and the palette contents are list-themes.py's.
//
// Nothing here writes. Every FileView is either preloaded (a read) or
// preload: false (a watch with no read at all), and `colors/` is a symlink
// into a git repository, so a setText() here would change the user's live
// theme and dirty their working tree.
//
// The children are properties rather than a child-object list, and that is
// not a style choice: a QtObject has NO default property, so `Timer { }`
// written inside one fails to compile with "Cannot assign to non-existent
// default property". The linter reports that as a warning and the engine
// rejects it at load, which would take the whole configuration down.
// BrightnessMonitor.qml writes its children the same way for the same reason.
//
// ---- watching colors/, in-process ---------------------------------
//
// TRAP, and the reason this file is not shorter than it looks. Theme.qml
// ran `inotify-watch.py -r <colorsRoot>` as a permanent Process:
// 14.5 MB RSS measured off /proc, 0.000s CPU over 40s, which is pure
// memory parked in read(). It was RECURSIVE, so it fired on
// `colors/themes/<name>/colors.json`, while the index.json FileView alone
// fired only on `index.json`. Deleting the watcher on the strength of "a
// FileView already watches that directory" silently breaks editing one
// theme's palette by hand and expecting the shell to pick it up. That
// is the trap; the rest of this file is the coverage that makes
// removing the watcher a non-event.
//
// What list-themes.py reads from inside colors/ is exactly:
//
//   index.json               the theme keys, and `current`
//   themes/<key>/colors.json one per key that index.json names
//   <wallpaperDir>/**        only when that directory is IN colors/
//
// Every wallpaperDir on this machine points into ~/Downloads, so the
// third case is inert here. The first two are the recursive part, and
// FileView serves both by itself: updateWatchedFiles() adds a
// QFileSystemWatcher path for the file AND for its parent directory,
// and onWatchedDirectoryChanged() re-emits fileChanged once the target
// exists. So editing a palette fires, and so do creating and deleting
// one.

QtObject {
    id: watch

    required property string colorsRoot

    signal reloadRequested()

    readonly property Timer debounce: Timer {
        interval: 400
        onTriggered: watch.reloadRequested()
    }

    readonly property FileView indexWatcher: FileView {
        path: watch.colorsRoot + "/index.json"
        watchChanges: true
        printErrors: false
        // Through the same 400ms debounce the python watcher's lines used.
        // Going straight at the reload meant an index.json edit was the one
        // trigger of the three that did not get debounced.
        onFileChanged: debounce.restart()
    }

    // One FileView per theme palette, rebuilt only when the key set moves.
    //
    // Built with createObject rather than a Repeater, on purpose. Repeater
    // cannot build these: it is Item-based, QQuickRepeater::regenerate()
    // returns early when `parentItem()` is null -- and the parent here is a
    // QtObject, not an Item, because a Singleton is not an Item either --
    // and it also refuses delegates that are not Item-derived, which
    // FileView (a QtObject) is not. A Repeater here would have read as the
    // obvious implementation and silently created nothing at all.
    property var paletteWatchers: []
    property string paletteWatchKey: ""

    // `var` and not `Component`: declaring the property with the Component
    // type makes the linter type createObject()'s return as a plain QObject,
    // and it then warns about the fileChanged signal this connects -- a
    // false positive on a type it cannot resolve here anyway. Both spellings
    // create and instantiate the same component.
    readonly property var paletteWatcher: Component {
        // preload false on purpose: only the watch is wanted here, not the
        // read. updatePath() builds the watcher either way, and the contents
        // of colors.json are list-themes.py's business, not this FileView's.
        FileView { watchChanges: true; preload: false; printErrors: false }
    }

    // Called with a freshly discovered preset map.
    function sync(themeMap) {
        const keys = Object.keys(themeMap).sort();
        // The separator is NUL, not a space or a comma, because a key is a
        // directory name and may contain either: {"my theme"} and
        // {"my", "theme"} both spell "my theme" joined on a space, and the
        // guard below would then skip watchers that are genuinely new.
        const signature = keys.join("\u0000");
        if (signature === watch.paletteWatchKey) return;

        for (const fv of watch.paletteWatchers) fv.destroy();
        watch.paletteWatchers = [];

        for (const key of keys) {
            const dir = watch.colorsRoot + "/themes/" + key;
            watch.addWatcher(dir + "/colors.json");
            watch.addInTreeWallpaperWatcher(themeMap[key]);
        }
        watch.paletteWatchKey = signature;
    }

    // A wallpaperDir inside colors/ -- which list-themes.py falls back to
    // when none of the external candidates exist, so a fresh install with
    // no ~/Pictures gets one -- is walked for images, so adding or removing
    // one changes the wallpaper list.
    //
    // Pointed at the directory rather than at a file inside it on purpose:
    // addPath() on a directory registers it in QFileSystemWatcher::directories()
    // rather than ::files(), and onWatchedDirectoryChanged() emits
    // fileChanged exactly when the target is absent from ::files() and
    // exists on disk -- both of which hold here. So a change under it
    // reloads.
    //
    // NOT EXERCISED on this machine: all six wallpaperDirs point into
    // ~/Downloads, so this adds no FileView here. Kept because the
    // recursive watcher it replaces did cover the in-tree case.
    function addInTreeWallpaperWatcher(theme) {
        const wdir = theme && theme.wallpaperDir ? String(theme.wallpaperDir) : "";
        if (!wdir.startsWith(watch.colorsRoot + "/")) return;
        watch.addWatcher(wdir);
    }

    function addWatcher(path) {
        const fv = paletteWatcher.createObject(watch, { path: path });
        if (!fv) {
            console.warn("Theme: could not watch " + path);
            return;
        }
        fv.fileChanged.connect(function() { debounce.restart(); });
        watch.paletteWatchers.push(fv);
    }
}
