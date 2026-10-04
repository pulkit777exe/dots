import QtQuick
import Quickshell.Io

// The thumbnail cache for an image entry in the clipboard history.
//
// `cliphist list` cannot show a picture. For a binary row it prints a
// placeholder -- "[[ binary data 214.7 KiB png image 1920x1080 24 bpp ... ]]"
// -- which is enough text for a list row to render and useless as an image,
// so something has to turn that row's id into a file an `Image` can load
// before the entry can show what was actually copied.
//
// This is that something, and it is a cache of files on disk rather than
// bytes in memory for the same reason Clipboard.qml's copy path is
// `cliphist decode | wl-copy`: the original content is arbitrary binary and
// has no business passing through a JS string on its way to a decoder. So
// `cliphist decode` writes to `/tmp/quickshell-cliphist/<id>.png` and the
// row only ever receives a `file://` URL. cliphist's own store remains the
// durable copy; everything here is disposable and rebuilt on demand.
//
// Three things and one Process:
//
//   directory      the single fact that names where a thumbnail lives
//   thumbnailUrl() what a row loads
//   decode()       put a file on disk for every image id in a list
//   decoded()      which ids actually landed
//
// The interface is deliberately ids in, ids out. Clipboard.qml owns the
// entry shape -- it builds the list and it flips `thumbnailReady` -- so
// keeping a second copy of the entries here would be a second thing that can
// disagree with the first. This file reads `id` and `isImage` and knows
// nothing else about an entry.
//
// `decodeProc` is a `readonly property` rather than a child object because a
// QtObject has no default property: `Process { }` written inside one fails to
// compile with "Cannot assign to non-existent default property", which the
// linter reports as a warning and the engine rejects at load.

QtObject {
    id: cache

    // One fact, three uses: the URL a row loads, the file the decode writes,
    // and the directory the decode creates. Under /tmp because these are
    // derived bytes -- cliphist still owns the original, so the worst a stale
    // cache can cost is a thumbnail of an entry that no longer exists, which
    // `cliphist list` will not report anyway.
    readonly property string directory: "/tmp/quickshell-cliphist"

    // Which ids have a usable file. Reported rather than stored: the caller
    // holds the entries, so a copy kept here would be one more thing to keep
    // in step with them, and a decode that lands after the list has already
    // been replaced must not resurrect the previous list's state.
    signal decoded(var ready)

    function thumbnailUrl(entryId): string {
        return (
            "file://" +
            cache.directory +
            "/" +
            entryId +
            ".png"
        )
    }

    // The decode, as one shell script rather than one Process per image: a
    // row's placeholder means there may be a dozen image entries in a list,
    // and a dozen short-lived processes on every refresh is a dozen chances
    // to interleave with another refresh.
    //
    // Three details in it are load-bearing:
    //
    //   [ -s ]  and not [ -f ]. A failed `cliphist decode` leaves a
    //           zero-byte file behind, and a row pointed at an empty file is
    //           a broken image rather than a missing one.
    //   rm -f   on failure, so a zero-byte file cannot be cached and then
    //           skipped forever by the `[ ! -s ]` test below.
    //   skip if present   this is the cache. Decoding an image is the most
    //           expensive thing the service does, and it is idempotent, so
    //           re-listing does not re-decode.
    //
    // The ids arrive as positional arguments ("$@"), never interpolated into
    // the script text, so no preview content can reach the shell parser.
    // `cache.directory` is the only interpolation and it is a literal in
    // this file.
    function decodeScript(): string {
        const dir = cache.directory

        return [
            "mkdir -p " + dir + ";",
            'for id in "$@"; do',
            'file="' + dir + '/${id}.png";',
            'if [ ! -s "$file" ]; then',
            'printf "%s\\t\\n" "$id" | cliphist decode' +
                ' > "$file" 2>/dev/null || rm -f "$file";',
            "fi;",
            'if [ -s "$file" ]; then',
            'printf "%s\\n" "$id";',
            "fi;",
            "done"
        ].join(" ")
    }

    // No-op on a list with no images, which is the common case: a list of
    // copied text should not spawn anything.
    function decode(entries) {
        const imageIds =
            entries
            .filter(
                entry =>
                    entry.isImage
            )
            .map(
                entry =>
                    entry.id
            )

        if (imageIds.length === 0)
            return

        decodeProc.command =
            [
                "bash",
                "-c",
                cache.decodeScript(),
                "--"
            ].concat(imageIds)

        decodeProc.running = true
    }

    // The answer is the list of ids whose file exists and is not empty --
    // decided by the shell that wrote them, because `-s` is the only test
    // that agrees with what the row will find when it loads the URL.
    readonly property Process decodeProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const ready = {}

                text
                    .split("\n")
                    .filter(
                        line =>
                            line.trim().length > 0
                    )
                    .forEach(
                        entryId => {
                            ready[entryId.trim()] = true
                        }
                    )

                cache.decoded(ready)
            }
        }
    }
}
