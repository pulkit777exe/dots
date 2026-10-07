import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// ClipboardHistory.qml -- the clipboard panel: a search field, a list of
// entries, and the keys that walk a selection through it.
//
// What is left in this file is the panel's own state: which entry is
// selected, how the query and the selection follow each other, and the
// focus retry that puts the caret in the search field before the user can
// type. Three things that used to be here are not any more, because each is
// a separate thing to change and each now has a file of its own:
//
//   ClipboardSearchBar.qml  the header: search field and Clear all
//   ClipboardStatus.qml     the line shown when there is no list
//   ClipboardRow.qml        one entry, as a row
//
// Everything to do with cliphist -- the processes, the parsing, the
// thumbnail decode, the entries themselves -- is in
// services/Clipboard.qml, and this file only reads it. There is no Process
// here and none should arrive: a panel that runs `cliphist` cannot be
// reasoned about by reading the panel.

Surface {
    id: root

    width: 550
    cornerRadius: 20
    backgroundColor: Theme.panelFill

    property var results: Clipboard.filteredEntries
    property int selectedIndex: 0

    implicitHeight:
        Math.min(
            480,
            column.implicitHeight + 24
        )

    transformOrigin: Item.Center

    opacity: 0
    scale: 0.96

    // Connected by IslandPanel, and never emitted from here: every path
    // out of this panel calls UiState.closeAll() directly, so the signal is
    // dead. It is left in place because IslandPanel.qml has a handler
    // on it and that file is not this one to change -- a finding to report,
    // not something to quietly drop.
    signal closeRequested()


    function moveSelection(delta) {
        if (results.length === 0)
            return

        selectedIndex =
            Math.max(
                0,
                Math.min(
                    results.length - 1,
                    selectedIndex + delta
                )
            )

        listView.positionViewAtIndex(
            selectedIndex,
            ListView.Contain
        )
    }

    function activateSelection() {
        if (
            results.length > 0 &&
            selectedIndex >= 0 &&
            selectedIndex < results.length
        ) {
            const entry =
                results[selectedIndex]

            Clipboard.copyEntry(
                entry.id
            )

            UiState.closeAll()
        }
    }

    // Focus the header and empty it. Called on completion and every time the
    // panel opens, so a search left over from last time does not silently
    // filter a history the user cannot see is being filtered.
    function focusSearch() {
        searchBar.focusAndClear()
        selectedIndex = 0
    }

    // Unused here and by everything else in the tree; Launcher.qml has the
    // same function with the same problem. Kept for the same reason, and
    // reported rather than removed.
    function searchFieldHasFocus(): bool {
        return searchBar.hasFocus
    }


    onVisibleChanged: {
        if (visible) {
            Clipboard.refresh()
            focusRetry.restart()
        }
    }

    // The panel opens without a key event ever reaching it, so the caret has
    // to be asked for: the window that hosts this is focused by the
    // compositor, and on the first frame the search field is not ready to
    // take focus. 60ms, repeating, until either this panel is hidden again or
    // the field actually has it.
    Timer {
        id: focusRetry

        interval: 60
        repeat: true

        onTriggered: {
            if (
                !root.visible ||
                searchBar.hasFocus
            ) {
                stop()
                return
            }

            root.focusSearch()
        }
    }


    ParallelAnimation {
        id: appearAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: MotionConfig.fadeMs
            easing.type: Easing.OutCubic
        }

        SpringAnimation {
            target: root
            property: "scale"
            to: 1
            spring: 4
            damping:
                MotionConfig.springDamping
            mass: 0.7
        }
    }


    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: 12

        spacing: 0


        ClipboardSearchBar {
            id: searchBar

            Layout.fillWidth: true

            onMoveSelection:
                (delta) => root.moveSelection(
                    delta
                )

            onAccepted:
                root.activateSelection()

            // Every keystroke re-filters the list, so the old index points at
            // a different entry, or past the end of the list entirely.
            onQueryEdited:
                root.selectedIndex = 0
        }


        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1

            Layout.topMargin: 8
            Layout.bottomMargin: 8

            color:
                Theme.colors.divider

            visible:
                Clipboard.entries.length > 0
        }


        ClipboardStatus {
            Layout.fillWidth: true
            Layout.margins: 24

            Layout.alignment:
                Qt.AlignHCenter
        }


        // The viewport is sized in rows rather than given a fixed height, so
        // a short history does not leave a tall empty panel. 52 is one row
        // (50, in ClipboardRow.qml) plus the 2 below.
        ListView {
            id: listView

            Layout.fillWidth: true

            Layout.preferredHeight:
                Math.min(
                    360,
                    Math.max(
                        52,
                        count * 52
                    )
                )

            clip: true

            model: root.results

            currentIndex:
                root.selectedIndex

            boundsBehavior:
                Flickable.StopAtBounds

            spacing: 2

            delegate: ClipboardRow {
                required property var modelData
                required property int index

                width: listView.width

                entry: modelData
                selected: index === root.selectedIndex

                onActivated: {
                    root.selectedIndex =
                        index

                    root.activateSelection()
                }

                onDeleteRequested:
                    Clipboard.deleteEntry(
                        entry.id
                    )
            }
        }
    }


    Component.onCompleted: {
        Clipboard.refresh()
        root.focusSearch()

        if (MotionConfig.reduceMotion) {
            root.opacity = 1
            root.scale = 1
        } else {
            appearAnimation.start()
        }
    }
}
