pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

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
    signal imagesDecoded()

    
    
    

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

                        const isBinary =
                            rawPreview.startsWith(
                                "[[ binary data"
                            ) ||
                            rawPreview.startsWith(
                                "[binary data"
                            )

                        const isImage =
                            isBinary &&
                            (
                                rawPreview
                                    .toLowerCase()
                                    .includes("png") ||

                                rawPreview
                                    .toLowerCase()
                                    .includes("jpg") ||

                                rawPreview
                                    .toLowerCase()
                                    .includes("jpeg") ||

                                rawPreview
                                    .toLowerCase()
                                    .includes("image") ||

                                rawPreview
                                    .toLowerCase()
                                    .includes("webp") ||

                                rawPreview
                                    .toLowerCase()
                                    .includes("x-")
                            )

                        return {
                            id: id,

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

                            thumbnail:
                                "file:///tmp/" +
                                "quickshell-cliphist/" +
                                id +
                                ".png",

                            thumbnailReady:
                                false
                        }
                    })
                    .filter(
                        entry =>
                            entry !== null
                    )

                root.entries = parsed

                decodeThumbnails(parsed)
            }
        }
    }

    
    
    

    function decodeThumbnails(items) {
        const imageIds =
            items
            .filter(
                entry =>
                    entry.isImage
            )
            .map(
                entry =>
                    entry.id
            )

        if (imageIds.length === 0) {
            root.imagesDecoded()
            return
        }

        const script =
            'mkdir -p /tmp/quickshell-cliphist; ' +
            'for id in "$@"; do ' +
            'file="/tmp/quickshell-cliphist/${id}.png"; ' +
            'if [ ! -s "$file" ]; then ' +
            'printf "%s\\t\\n" "$id" | ' +
            'cliphist decode > "$file" 2>/dev/null || ' +
            'rm -f "$file"; ' +
            'fi; ' +
            'if [ -s "$file" ]; then ' +
            'printf "%s\\n" "$id"; ' +
            'fi; ' +
            'done'

        decodeImagesProc.command =
            [
                "bash",
                "-c",
                script,
                "--"
            ].concat(imageIds)

        decodeImagesProc.running = true
    }

    Process {
        id: decodeImagesProc

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
                        id => {
                            ready[id.trim()] = true
                        }
                    )

                root.entries =
                    root.entries.map(
                        entry => {
                            if (!entry.isImage)
                                return entry

                            return {
                                id:
                                    entry.id,

                                preview:
                                    entry.preview,

                                rawPreview:
                                    entry.rawPreview,

                                isImage:
                                    entry.isImage,

                                isBinary:
                                    entry.isBinary,

                                thumbnail:
                                    entry.thumbnail,

                                thumbnailReady:
                                    ready[
                                        entry.id
                                    ] === true
                            }
                        }
                    )

                root.imagesDecoded()
            }
        }
    }

    
    
    

    Process {
        id: copyProc
    }

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

    Component.onCompleted:
        probe.running = true

    
    
    

    IpcHandler {
        target: "clipboard"

        function list() {
            return JSON.stringify(
                root.entries
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

        function isAvailable() {
            return root.available
        }
    }
}