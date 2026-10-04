// Something happened rather than something connected: the power profile
// changed, night light was toggled, the keep-awake inhibitor was flipped, the
// theme was applied, a track changed, something was copied.
//
// One of the two leaves NotificationWatchers.qml is built from. Not a
// singleton, and nothing here owns a toast, a list or a timer: each
// Connections below decides that something happened and hands it to the
// fleet's `notify`.
//
// These six are together because the toast is about an event rather than
// about a piece of hardware, which is also why two of them (the keep-awake
// inhibitor and the theme) need no startup guard at all and one of them (the
// media watcher) carries a guard that is not a startup guard but a
// first-track rule. The four that are purely "a service's state arrived late"
// are in NotificationDeviceWatchers.qml, where the measurements that justify
// the guards sit next to each other.
//
// A QtObject has no default property, so every Connections below is held in a
// property rather than written as a child -- otherwise the whole config fails
// with "Cannot assign to non-existent default property" (measured, and the
// same reason services/BrightnessMonitor.qml holds its Process and Timer that
// way).

import QtQuick

QtObject {
    id: root

    // The one capability this file needs: file a toast. Called as
    // `root.notify(...)` by every handler below.
    //
    // Assigned by NotificationWatchers.qml, always, at construction -- which is
    // why there is no null check here. The one gate for the whole fleet is that
    // file's announce(), so this file cannot hold an unwired `notify` in the
    // gap: the assignment is part of building this object, and no signal
    // handler runs until the event loop turns, which is after that.
    property var notify: null

    readonly property Connections powerProfile: Connections {
        target: PowerProfile

        property bool initialised: false

        function onProfileChanged(profile) {
            if (!initialised) {
                initialised = true
                return
            }

            const activeProfile =
                profile ||
                PowerProfile.active

            const modeName =
                activeProfile.charAt(0).toUpperCase()
                +
                activeProfile.slice(1)

            root.notify(
                "Power Profile Changed",

                "Switched to " +
                modeName +
                " mode",

                "Power",

                "speed"
            )
        }
    }

    readonly property Connections nightLight: Connections {
        target: NightLight

        property bool initialised: false

        function onToggled(enabled) {
            if (!initialised) {
                initialised = true
                return
            }

            root.notify(
                "Night Light",

                enabled
                    ? "Screen warmth enabled"
                    : "Screen warmth disabled",

                "Display",

                "nightlight"
            )
        }
    }

    readonly property Connections idleInhibit: Connections {
        target: IdleInhibit

        // No guard: `active` is a plain property this service owns and
        // only `toggle()` writes it, so nothing can move it at startup.
        // Measured: 0 activeChanged over 25s. A guard here ate the first
        // keep-awake toggle of every session and nothing else.
        function onActiveChanged() {
            root.notify(
                "Keep-Awake Inhibitor",
                IdleInhibit.active
                    ? "Screen sleep inhibited"
                    : "Screen sleep allowed",
                "System",
                "coffee"
            )
        }
    }

    readonly property Connections theme: Connections {
        target: Theme

        // No guard: `themeChanged` is a user-action signal, not a state
        // change. Startup assigns `currentName` directly in
        // `resolveTheme()` instead of going through `setTheme()`, which is
        // the only thing that emits the signal -- so the signal stays
        // silent while `currentName` itself moves "" -> "ariadne"
        // underneath it. Measured: 0 themeChanged over 25s. A guard ate
        // the first real theme switch of every session.
        function onThemeChanged(name) {
            root.notify(
                "Theme Changed",
                "Applied " +
                (
                    Theme.displayName ||
                    name
                ) +
                " theme",
                "Appearance",
                "palette"
            )
        }
    }

    // The key to toast `title` under, or "" for stay quiet.
    //
    // Three unrelated reasons say no -- toasts switched off, nothing playing,
    // nothing new to say -- and none of them belongs to the string building,
    // so the question is asked here and maybeToast() only acts on the answer.
    // "" cannot be a real key: every key is `title + "|" + artist`, so it
    // always contains a "|".
    function trackToastKey(title, artist, lastKey): string {
        if (!ConfigStore.mediaShowToast)
            return "";

        if (!Media.playing)
            return "";

        const key = title + "|" + artist;

        if (!title || key === lastKey || key === "|")
            return "";

        return key;
    }

    // A media toast's message: the title, with artist and album as one detail
    // line under it when there is an artist to name. Only the shape of a track
    // lives here.
    function trackMessage(title, artist, album): string {
        const detail =
            artist
                ? artist +
                  (
                      album
                          ? " · " + album
                          : ""
                  )
                : "";

        return title + (detail ? "\n" + detail : "");
    }

    readonly property Connections media: Connections {
        target: Media

        property bool initialised: false
        property string lastTrackKey: ""

        function maybeToast() {
            const key = root.trackToastKey(
                Media.title,
                Media.artist,
                lastTrackKey
            );

            if (!key)
                return;

            lastTrackKey = key;

            if (!initialised) {
                initialised = true;
                return;
            }

            root.notify(
                "Now Playing",

                root.trackMessage(
                    Media.title,
                    Media.artist,
                    Media.album
                ),

                "Music",

                "music_note"
            );
        }

        function onTitleChanged() {
            maybeToast()
        }

        function onArtistChanged() {
            maybeToast()
        }

        function onPlayingChanged() {
            if (Media.playing) {
                initialised = true
                maybeToast()
            }
        }
    }

    readonly property Connections clipboard: Connections {
        target: Clipboard

        property bool initialised: false

        function onEntryCopied(text) {
            if (!initialised) {
                initialised = true
                return
            }

            const preview =
                text.length > 60
                    ? text.slice(0, 60) + "…"
                    : text

            root.notify(
                "Copied to Clipboard",

                preview,

                "System",

                "content_copy"
            )
        }
    }
}