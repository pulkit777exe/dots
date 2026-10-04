pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The clipboard history: cliphist's entry list, the search filter over it,
// the commands that act on an entry, and the IPC.
//
// Six processes, and this file owns all of them:
//
//   probe        command -v cliphist / wl-paste, once at construction. A
//                machine without them gets `available: false` and an empty
//                list, which the surface already has a state for, rather
//                than a Process that fails on every refresh.
//   watcher      wl-paste --watch cliphist store. The one permanent watcher
//                this repo starts rather than asking the user to add to
//                their Hyprland config, because it has no purpose beyond
//                this feature. It outlives a reload -- Quickshell does not
//                take it down when the config is reloaded or the shell
//                exits -- so scripts/recovery.sh reaps the ones a reload
//                leaves reparented to init. That list must keep naming it.
//   list         cliphist list, parsed into entries below.
//   copy/del/wipe   one-shot. del and wipe destroy data, so both re-list on
//                exit rather than leaving the list describing a store that
//                no longer matches it.
//
// The one job here that is not a process on an entry is turning an image id
// into a PNG on disk, and that is ClipboardThumbnails.qml. It is the part that
// can be a separate file without a second entry list to keep in step with this
// one: it takes image ids in and reports which ones landed, and this file owns
// the entry shape both before and after that report.
//
// The copy path is a shell pipeline (`cliphist decode | wl-copy`) rather than
// `cliphist decode` into a property: `cliphist`'s content is arbitrary binary
// and has no business round-tripping through a JS string. Only the numeric id
// is interpolated, as a positional shell argument, so no preview text can
// reach the shell parser.

Singleton {
    id: root

    // The thumbnail cache. `onDecoded` is how the decode report comes back:
    // the cache reports ids, this file decides what an id being decoded means
    // for the entry it belongs to.
    ClipboardThumbnails {
        id: thumbnails

        onDecoded: (ready) => root.markThumbnails(ready)
    }

    property bool available: false

    property var entries: []

    property string query: ""

    readonly property var filteredEntries:
        query.length === 0
            ? entries
            : entries.filter(
                entry =>
                    entry.preview
                    .toLowerCase()
                    .includes(
                        query.toLowerCase()
                    )
              )

    signal entryCopied(string preview)

    function refresh() {
        if (!available)
            return

        listProc.running = true
    }

    function copyEntry(id) {
        copyProc.command = [
            "bash",
            "-c",
            'printf "%s\\t\\n" "$1" | cliphist decode | wl-copy',
            "--",
            String(id)
        ]

        copyProc.running = true

        // Reported for the surface's own "copied" feedback, so it is read
        // here rather than passed in: the caller has only the id.
        const match =
            root.entries.find(
                entry =>
                    entry.id === id
            )

        root.entryCopied(
            match
                ? match.preview
                : ""
        )
    }

    function deleteEntry(id) {
        deleteProc.command = [
            "bash",
            "-c",
            'printf "%s\\t\\n" "$1" | cliphist delete',
            "--",
            String(id)
        ]

        deleteProc.running = true

        // Dropped from the list immediately, so the row disappears on the
        // click rather than when the re-list comes back.
        root.entries =
            root.entries.filter(
                entry =>
                    entry.id !== id
            )
    }

    function wipe() {
        wipeProc.running = true
        root.entries = []
    }

    // `cliphist list` prints one line per entry, `<id>\t<preview>`. A line
    // with no tab is not an entry at all and is dropped rather than shown as
    // an empty row.
    //
    // The entry shape is fixed here and nowhere else: id, preview,
    // rawPreview, isImage, isBinary, thumbnail, thumbnailReady. A row reads
    // these, which is why the list stays full-fidelity.
    //
    // `clipboard list` does NOT hand all seven over as JSON. It replies with
    // everything except `rawPreview`, because for a text entry that is the same
    // string as `preview` and for a binary one `preview` already carries what
    // a row shows, and the reply has a byte budget it cannot fit all seven
    // inside. See ipcReply() for the measurements.
    Process {
        id: listProc

        command: [
            "cliphist",
            "list"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines =
                    text
                    .split("\n")
                    .filter(
                        line =>
                            line.length > 0
                    )

                // cliphist's placeholder for a binary row names the format
                // ("[[ binary data 214.7 KiB png image 1920x1080 ... ]]"),
                // so an image is told from other binary content by a word in
                // that placeholder -- no MIME type, and nothing to sniff.
                // `x-` is here for `image/svg+xml`, whose placeholder says
                // "svg image" but never "png" or "jpeg".
                const IMAGE_HINTS = ["png", "jpg", "jpeg", "image", "webp", "x-"]

                const parsed =
                    lines
                    .map(line => {
                        const tab =
                            line.indexOf("\t")

                        if (tab === -1)
                            return null

                        const id =
                            line
                            .slice(0, tab)
                            .trim()

                        const rawPreview =
                            line
                            .slice(tab + 1)

                        // Both spellings, because cliphist has used both.
                        const isBinary =
                            rawPreview.startsWith(
                                "[[ binary data"
                            ) ||
                            rawPreview.startsWith(
                                "[binary data"
                            )

                        const lowered =
                            rawPreview
                            .toLowerCase()

                        const isImage =
                            isBinary &&
                            IMAGE_HINTS.some(
                                hint =>
                                    lowered.includes(
                                        hint
                                    )
                            )

                        return {
                            id: id,

                            // An image's preview is its placeholder with the
                            // brackets stripped, so the row shows the size and
                            // dimensions next to the thumbnail; any other
                            // binary content gets one honest word instead.
                            preview:
                                isBinary
                                    ? (
                                        isImage
                                            ? rawPreview
                                                .replace(
                                                    /[\[\]]/g,
                                                    ""
                                                )
                                                .trim()
                                            : "Binary data"
                                      )
                                    : rawPreview,

                            rawPreview:
                                rawPreview,

                            isImage:
                                isImage,

                            isBinary:
                                isBinary,

                            thumbnail: thumbnails.thumbnailUrl(id),

                            thumbnailReady:
                                false
                        }
                    })
                    .filter(
                        entry =>
                            entry !== null
                    )

                root.entries = parsed

                // Fire and forget: the entries are already usable, and the
                // thumbnails arrive afterwards as a second, separate update.
                thumbnails.decode(parsed)
            }
        }
    }

    // The decode report, applied to the entries.
    //
    // Object.assign rather than a hand-rebuilt literal of all seven keys: the
    // shape is written once, in the parse above, and a second copy of it here
    // is where an eighth key would be silently forgotten. The keys and their
    // order are unchanged -- `thumbnailReady` is already one of them -- so the
    // JSON `clipboard list` returns over IPC is the same either way.
    function markThumbnails(ready) {
        root.entries = root.entries.map(
            entry =>
                entry.isImage
                    ? Object.assign({}, entry, {
                          thumbnailReady:
                              ready[entry.id] === true
                      })
                    : entry
        )
    }

    Process {
        id: copyProc
    }

    // Both of the destructive ones re-list on exit. The local change is
    // optimistic -- the row goes when it is clicked -- so without this the
    // list would quietly disagree with the store until something else
    // happened to refresh it.
    Process {
        id: deleteProc

        onExited:
            root.refresh()
    }

    Process {
        id: wipeProc

        onExited:
            root.refresh()
    }

    // Bound, not fired: `available` is what decides whether cliphist is worth
    // watching for, and it is set by the probe below at construction. A
    // watcher started here and stopped later would need a second binding to
    // tear it down, and one that outlived the shell would be one more for
    // recovery.sh to reap.
    Process {
        id: watcher

        command: [
            "wl-paste",
            "--watch",
            "cliphist",
            "store"
        ]

        running:
            root.available
    }

    Process {
        id: probe

        command: [
            "bash",
            "-c",
            "command -v cliphist >/dev/null && " +
            "command -v wl-paste >/dev/null && " +
            "echo yes || echo no"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (line) => {
                if (line.trim() === "yes") {
                    root.available = true
                    root.refresh()
                }
            }
        }
    }

    // Once, at construction. Nothing else starts the probe, and a probe that
    // is never started leaves `available` false forever -- which looks
    // exactly like cliphist not being installed, and takes the watcher with
    // it.
    Component.onCompleted:
        probe.running = true

    // Bounded, and bounded in the currency that matters: bytes of the UTF-16BE
    // string the socket actually carries.
    //
    // What was wrong. `list()` answered with every entry's full text. At 750
    // entries that is a 433,018-byte reply (216,509 UTF-16 chars), and the IPC
    // socket's send buffer on this machine is 212,992 bytes
    // (`net.core.wmem_default`). The tail never left the shell: the declared
    // length stayed 433,018 on every call while the delivered bytes varied --
    // 219,264 and 255,808 across identical calls, read to EOF by a
    // hand-written client -- and the JSON ended mid-string ("Unterminated
    // string starting at char 109611"). Both clients hit it: this repo's
    // `qs-call` and the real `quickshell ipc call`, which both report a
    // peer-closed socket and print no reply. Nothing was logged shell-side, the
    // shell stayed healthy, and the reply read as an accessor that returns
    // empty -- which is how it was recorded here for as long as it was open.
    //
    // What bounds it now, and why each part is here.
    //
    //   The whole reply, in bytes, measured rather than estimated. The frame
    //   is a u32-BE length followed by UTF-16BE, so a JSON string of n
    //   characters costs exactly 2n bytes, and each record's real cost is
    //   `JSON.stringify(record).length * 2`. Charging the measured cost of
    //   each record as it is admitted makes the reply's size a property of
    //   this function rather than of how much text happens to be in the
    //   clipboard.
    //
    //   One preview length. cliphist truncates its own previews already --
    //   over this machine's 750 entries the longest is 101 characters -- so
    //   this cap changes nothing today. It is here so the per-record cost is
    //   bounded by this file rather than by an implementation detail of
    //   cliphist that nothing documents.
    //
    //   The entry count, which is the only one of the three that actually
    //   binds, and which is why this is a byte budget rather than a count.
    //   Measured on those 750 entries: dropping the duplicated `rawPreview`
    //   takes the reply from 444,586 to 313,892 bytes, and also truncating
    //   every preview to 120 chars takes it to 313,940. Both are still well
    //   over the send buffer, because the payload is 750 copies of a
    //   ~290-byte JSON record and only 750 copies of at most 101 characters of
    //   text -- so at this history length the count is the whole problem, and
    //   a cap on preview length alone would not have fixed it. A byte budget
    //   beats a fixed entry count for the same reason: 64 KiB admits ~125
    //   records even at the worst-case record size (a 7-digit id and a
    //   120-char preview, 521 bytes), and admits several hundred when previews
    //   are short.
    //
    // What is deliberately untouched: `entries` and everything derived from it.
    // ClipboardRow.qml renders `entry.preview` in full and elides it only to
    // the width of the panel, so truncating the in-process list would put a
    // 120-character version of every row on screen. The panel keeps showing
    // whole entries; only the reply is cut down.
    //
    // Blast radius: the reply is now an object -- total, returned, truncated,
    // entries -- rather than a bare array, it carries a bounded window of the
    // newest entries rather than all of them, and one key is gone from the
    // wire shape. `rawPreview` is omitted because for a text entry it is the
    // same string as `preview`, and for a binary one `preview` already carries
    // everything a row shows; it stays on the entry itself. Nothing in this
    // repo reads the reply -- the surfaces use `Clipboard.entries` in process
    // -- so no caller changes, and the IPC function list is untouched: a new
    // function name would change the generated table in ARCHITECTURE.md, which
    // check-ipc-table.py compares against `quickshell ipc show`, and a bound
    // reply needs no second call to be correct.
    //
    // 64 KiB, against the measured numbers above: a third of one send buffer,
    // so the reply is written without the writer ever blocking, and a sixth
    // of the smallest truncation that was observed. It is a deliberate margin,
    // not a threshold found by bisecting this machine's buffers -- a different
    // machine's `net.core.wmem_default` may be smaller, and this has to be
    // right on a fresh clone.
    readonly property int ipcReplyBudget: 65536

    // Reserved before any record is admitted rather than measured after the
    // last one: `{"total":N,"returned":M,"truncated":true,"entries":[` through
    // `]}` is 116 bytes for a three-digit history, plus the six bytes of frame
    // header. 256 covers that with room, and stays enough for a history two
    // orders of magnitude larger.
    readonly property int ipcReplyOverhead: 256

    // 120 characters. Unreachable against cliphist today (see above).
    readonly property int ipcReplyPreviewChars: 120

    // The newest records that fit the budget, and the count they came from.
    // `entries` is ordered newest-first by `cliphist list`, so stopping here
    // drops the oldest, which is the end a list is least likely to be showing
    // anyway.
    //
    // On the singleton rather than inside the IpcHandler: a function declared
    // in one of those is reachable over IPC but is not a method on the
    // singleton, so `root.ipcReply()` below would be undefined and would fail
    // quietly. scripts/ipc-audit.py exists because that has bitten this tree.
    function ipcReply(): var {
        const out = []

        let bytes = root.ipcReplyOverhead

        for (const entry of root.entries) {
            const wire = {
                id: entry.id,

                preview:
                    entry.preview.length > root.ipcReplyPreviewChars
                        ? entry.preview.slice(
                              0,
                              root.ipcReplyPreviewChars
                          ) + "…"
                        : entry.preview,

                isImage: entry.isImage,

                isBinary: entry.isBinary,

                thumbnail: entry.thumbnail,

                thumbnailReady: entry.thumbnailReady
            }

            // +1 is the separating comma, so the measured total is the whole
            // array rather than the records in it.
            const cost =
                JSON.stringify(wire).length * 2 + 1

            // Stop, do not skip: the reply stays a prefix of the history, so
            // `returned` entries are always the `returned` newest ones. One
            // record over budget costs at most one record.
            if (bytes + cost > root.ipcReplyBudget)
                break

            out.push(wire)
            bytes += cost
        }

        return {
            total: root.entries.length,
            returned: out.length,
            truncated: out.length < root.entries.length,
            entries: out
        }
    }

    IpcHandler {
        target: "clipboard"

        function list(): string {
            return JSON.stringify(
                root.ipcReply()
            )
        }

        function refresh() {
            root.refresh()
        }

        function copy(id: string) {
            root.copyEntry(id)
        }

        function del(id: string) {
            root.deleteEntry(id)
        }

        function wipe() {
            root.wipe()
        }

        function isAvailable(): bool {
            return root.available
        }
    }
}
