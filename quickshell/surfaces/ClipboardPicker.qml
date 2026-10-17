import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../services"

PopupPanel {
    id: root

    open: UiState.clipboardOpen
    readonly property bool imageView: UiState.clipboardView === "image"

    width: imageView ? 460 : 640
    cornerRadius: open ? 22 : pillRadius
    backgroundColor: Theme.panelFill

    property var entries: []
    property string query: ""
    property int selectedIndex: 0

    property var thumbs: ({})

    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "") return entries;
        return entries.filter(e => e.preview.toLowerCase().includes(q));
    }
    readonly property var selected:
        (results.length > 0 && selectedIndex < results.length) ? results[selectedIndex] : null

    readonly property int textRowHeight: 32
    readonly property int imageRowHeight: 78
    readonly property int maxListHeight: 320

    readonly property string counter: results.length === 0
        ? "0 / 0 (" + entries.length + ")"
        : (selectedIndex + 1) + " / " + results.length + " (" + entries.length + ")"

    function rowHeight(e) { return e.image ? imageRowHeight : textRowHeight; }

    implicitHeight: (imageView ? imageColumn.implicitHeight : listColumn.implicitHeight) + 32

    Behavior on width {
        enabled: !Config.reduceMotion
        NumberAnimation { duration: Config.movement(0.5); easing.type: Easing.OutQuint }
    }

    readonly property string thumbDir: Quickshell.statePath("cliphist-thumbs")

    function refresh() {
        if (lister.running) lister.running = false;
        lister.running = true;
    }

    Process {
        id: lister
        running: false
        command: ["sh", "-c",
            "rm -rf '" + root.thumbDir + "' && mkdir -p '" + root.thumbDir + "' && cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const preview = line.slice(tab + 1);
                    let mime = "";
                    if (preview.startsWith("[[ binary data")) {
                        const kind = (preview.match(/\b([a-z]+)\s+\d+x\d+\s+\]\]/) || [])[1];
                        if (kind === "png" || kind === "gif" || kind === "webp" || kind === "bmp")
                            mime = "image/" + kind;
                        else if (kind === "jpeg" || kind === "jpg")
                            mime = "image/jpeg";
                    }
                    rows.push({ id: line.slice(0, tab), preview: preview, image: mime !== "", mime: mime });
                }
                root.entries = rows;
                root.selectedIndex = 0;
                root.thumbs = ({});
            }
        }
    }

    function thumbPath(id) { return Quickshell.statePath("cliphist-thumbs/" + id); }

    function setThumb(id, path) {
        const next = Object.assign({}, thumbs);
        next[id] = path;
        thumbs = next;
    }

    function copySelected() {
        const e = selected;
        if (!e) return;
        if (e.image)
            Quickshell.execDetached(["sh", "-c",
                "cliphist decode " + e.id + " | wl-copy --type " + e.mime]);
        else
            Quickshell.execDetached(["sh", "-c", "cliphist decode " + e.id + " | wl-copy"]);
        UiState.close();
    }

    function activateSelection() {
        if (!selected) return;
        if (selected.image) UiState.clipboardView = "image";
        else copySelected();
    }

    function moveSelection(delta) {
        if (results.length === 0) return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    onOpenChanged: {
        if (open) {
            search.text = "";
            query = "";
            selectedIndex = 0;
            list.contentY = 0;
            refresh();
            focusRetry.restart();
        } else {
            focusRetry.stop();
        }
    }

    onImageViewChanged: {
        if (imageView) forceActiveFocus();
        else if (open) focusRetry.restart();
    }
    Keys.onReturnPressed: imageView ? copySelected() : activateSelection()
    Keys.onEnterPressed: imageView ? copySelected() : activateSelection()
    Keys.onUpPressed: if (!imageView) moveSelection(-1)
    Keys.onDownPressed: if (!imageView) moveSelection(1)

    Timer {
        id: focusRetry
        interval: 60
        repeat: true
        onTriggered: {
            if (!root.open || root.imageView || search.inputFocused) { stop(); return; }
            search.forceInputFocus();
        }
    }

    ColumnLayout {
        id: listColumn

        anchors.fill: parent
        anchors.margins: 16
        spacing: 0
        visible: !root.imageView

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 12

            Label {
                text: "Clipboard Manager"
                font.pixelSize: Theme.px(15)
                font.weight: Font.Medium
                color: Theme.withAlpha(Theme.colors.text, 0.95)
            }
            Item { Layout.fillWidth: true }
            Label {
                text: root.counter
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.5)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 8
            color: Theme.cc.card
            border.width: 1
            border.color: Theme.cc.border

            SearchField {
                id: search

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                fieldHeight: 34
                placeholderText: "search clips..."
                placeholderWhenFocused: true

                onNavigateUp: root.moveSelection(-1)
                onNavigateDown: root.moveSelection(1)
                onAccepted: root.activateSelection()

                onTextChanged: {
                    root.query = text;
                    root.selectedIndex = 0;
                    list.contentY = 0;
                }
            }
        }

        Item {
            id: listViewport

            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.preferredHeight: root.results.length === 0 ? 56
                : Math.min(list.contentHeight, root.maxListHeight)

            Behavior on Layout.preferredHeight {
                enabled: !Config.reduceMotion
                NumberAnimation { duration: Config.movement(0.35); easing.type: Easing.OutQuint }
            }

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.results

                delegate: Item {
                    id: row

                    required property int index
                    required property var modelData

                    width: list.width
                    height: root.rowHeight(modelData)

                    Glow {
                        anchors.fill: parent
                        anchors.margins: -5
                        cornerRadius: 15
                        glowColor: Theme.withAlpha(Theme.accentFor("clipboard"), 0.08)
                        on: row.index === root.selectedIndex
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: row.index === root.selectedIndex
                        radius: 10
                        color: Theme.cc.card
                    }

                    Label {
                        visible: !row.modelData.image
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                            rightMargin: 10
                        }
                        text: row.modelData.preview
                        font.pixelSize: Theme.px(14)
                        color: Theme.withAlpha(Theme.colors.text, 0.9)
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: row.modelData.image
                        anchors.centerIn: parent
                        width: 140
                        height: 62
                        radius: 8
                        clip: true
                        color: Qt.rgba(0, 0, 0, 0.25)

                        Image {
                            anchors.fill: parent
                            source: root.thumbs[row.modelData.id] !== undefined
                                ? "file://" + root.thumbs[row.modelData.id] : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }
                    }

                    Process {
                        id: thumbber
                        running: false
                        command: ["sh", "-c",
                            "F='" + root.thumbPath(row.modelData.id) + "'; " +
                            "cliphist decode " + row.modelData.id + " > \"$F\" 2>/dev/null && " +
                            "file -b --mime-type \"$F\" | grep -q '^image/' && exit 0; " +
                            "rm -f \"$F\"; exit 1"]
                        onExited: (code) => {
                            if (code === 0)
                                root.setThumb(row.modelData.id, root.thumbPath(row.modelData.id));
                        }
                    }
                    Component.onCompleted: {
                        if (row.modelData.image && root.thumbs[row.modelData.id] === undefined)
                            thumbber.running = true;
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) root.selectedIndex = row.index;
                        }
                    }

                    TapHandler {
                        onTapped: {
                            root.selectedIndex = row.index;
                            root.activateSelection();
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: "Clipboard history is empty"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.45)
            }
        }
    }

    ColumnLayout {
        id: imageColumn

        anchors.fill: parent
        anchors.margins: 16
        spacing: 8
        visible: root.imageView

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 400
            radius: 10
            clip: true
            color: Qt.rgba(0, 0, 0, 0.25)

            Image {
                anchors.fill: parent
                source: root.selected && root.selected.image
                    && root.thumbs[root.selected.id] !== undefined
                    ? "file://" + root.thumbs[root.selected.id] : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: (root.selectedIndex + 1) + " / " + root.results.length
            font.pixelSize: Theme.px(13)
            color: Theme.withAlpha(Theme.colors.text, 0.5)
        }
    }
}
