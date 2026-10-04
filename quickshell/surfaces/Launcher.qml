import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// Launcher.qml -- the app launcher.
//
// What is left here is the launcher's own state and the timing around it:
//
//   * which row is selected, and the arrow keys that move it
//   * the debounce, and the crossfade, that turn a keystroke into a query
//   * the focus retry that puts the caret in the search field before the user
//     can type
//   * the panel's own appear animation
//
// Three things that used to be here are not any more, because each is a
// separate thing to change and each now has a file of its own:
//
//   LauncherSearch.qml    the search field and the keys that reach it
//   LauncherResults.qml   the rows, the sliding highlight, the row count
//
// `AppLauncher.setQuery`, the launching of a result and the IPC behind both are
// in services/AppLauncher.qml, and this file only reads them: there is no
// Process here and none should arrive, for the reason ClipboardHistory.qml gives
// -- a panel that indexes .desktop files cannot be reasoned about by reading
// the panel.

Surface {
    id: root

    cornerRadius: 20
    backgroundColor: Theme.panelFill

    // Written by IslandCenterPanel too, which passes AppLauncher.results in
    // from outside rather than letting this file reach for it.
    property var results: AppLauncher.results

    property int selectedIndex: 0
    property int hoverIndex: -1

    implicitHeight: column.implicitHeight + 38

    transformOrigin: Item.Center

    opacity: 0
    scale: 0.96

    signal activated(var result)

    // 180ms: long enough that a fast typist produces one query rather than
    // eight, short enough that the list does not feel like it is ignoring the
    // keyboard. repeat: false so it is a debounce and not a poll.
    Timer {
        id: searchDebounce

        interval: 180
        repeat: false

        onTriggered: {
            searchTransition.restart()
        }
    }

    // Reduced motion: no crossfade and no delay, because MotionConfig.fade(0.275)
    // is already 0 there -- the animation would be instant but the results
    // would still land 180ms after the keystroke, which is the part that reads
    // as lag.
    function queueSearch() {
        searchDebounce.restart()
    }

    function applySearchImmediately() {
        AppLauncher.setQuery(searchBar.text)

        selectedIndex = 0
        hoverIndex = -1

        resultsArea.opacity = 1
    }

    // Fade out, swap, fade back in: three steps, in this order, and the swap is
    // a ScriptAction between the two numbers so the list is never re-populated
    // while it is half faded.
    SequentialAnimation {
        id: searchTransition

        NumberAnimation {
            target: resultsArea
            property: "opacity"

            to: 0

            duration: MotionConfig.fade(0.275)
            easing.type: Easing.OutQuad
        }

        ScriptAction {
            script: {
                AppLauncher.setQuery(searchBar.text)

                selectedIndex = 0
                hoverIndex = -1
            }
        }

        NumberAnimation {
            target: resultsArea
            property: "opacity"

            from: 0
            to: 1

            duration: MotionConfig.fade(0.45)
            easing.type: Easing.OutCubic
        }
    }

    function moveSelection(delta) {
        if (results.length === 0)
            return

        hoverIndex = -1

        selectedIndex = Math.max(
            0,
            Math.min(
                results.length - 1,
                selectedIndex + delta
            )
        )
    }

    function activateSelection() {
        if (results.length === 0)
            return

        root.activated(results[selectedIndex])
    }

    // Focus the field and empty it. Called on completion and every time the
    // panel opens, so a search left over from last time does not silently
    // filter a list the user cannot see is being filtered.
    function searchFieldFocus() {
        searchBar.text = ""

        selectedIndex = 0
        hoverIndex = -1

        searchBar.focusInput()
    }

    // Unused here and by everything else in the tree, and duplicated verbatim
    // in ClipboardHistory.qml -- which is a file that is not this one to
    // change. Kept for the same reason it is kept there, and reported rather
    // than removed: a focus query that nothing asks is one more thing to
    // keep true.
    function searchFieldHasFocus(): bool {
        return searchBar.hasFocus
    }

    onVisibleChanged: {
        if (visible)
            focusRetry.restart()
    }

    // The panel opens without a key event ever reaching it, so the caret has
    // to be asked for: the window that hosts this is focused by the
    // compositor, and on the first frame the search field is not ready to take
    // focus. 60ms, repeating, until either the panel is hidden again or the
    // field actually has it.
    Timer {
        id: focusRetry

        interval: 60
        repeat: true

        onTriggered: {
            if (!root.visible || searchBar.hasFocus) {
                stop()
                return
            }

            root.searchFieldFocus()
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
            damping: MotionConfig.springDamping
            mass: 0.7
        }
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 21
        anchors.bottomMargin: 17

        spacing: 0

        LauncherSearch {
            id: searchBar

            Layout.fillWidth: true

            Layout.leftMargin: 8
            Layout.rightMargin: 8

            onMoved: (delta) => root.moveSelection(delta)

            onAccepted: root.activateSelection()

            // Every keystroke re-filters the list, so the old index points at
            // a different app, or past the end of the list entirely. The
            // panel owns that decision because the panel owns the debounce.
            onQueryEdited: {
                if (MotionConfig.reduceMotion) {
                    searchDebounce.stop()
                    root.applySearchImmediately()
                } else {
                    root.queueSearch()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1

            Layout.topMargin: 8
            Layout.bottomMargin: 11

            color: Theme.colors.divider

            visible: root.results.length > 0
        }

        // Height from the row count, animated so a search that goes from 9
        // results to 1 does not snap the panel shut under the user's eyes.
        // LauncherResults owns the count -- it is what draws the rows -- and
        // this is the only place the two are put together.
        LauncherResults {
            id: resultsArea

            Layout.fillWidth: true

            Layout.preferredHeight: resultsArea.implicitHeight

            Behavior on Layout.preferredHeight {
                enabled: !MotionConfig.reduceMotion

                NumberAnimation {
                    duration: MotionConfig.movement(0.35)
                    easing.type: Easing.OutCubic
                }
            }

            results: root.results
            selectedIndex: root.selectedIndex
            hoverIndex: root.hoverIndex

            onRowHovered: (index) => root.hoverIndex = index

            onRowActivated: (index) => {
                root.selectedIndex = index
                root.hoverIndex = -1

                root.activateSelection()
            }
        }
    }

    Component.onCompleted: {
        if (MotionConfig.reduceMotion) {
            root.opacity = 1
            root.scale = 1
            resultsArea.opacity = 1
        } else {
            appearAnimation.start()
        }
    }
}
