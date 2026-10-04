import QtQuick

import "../components"
import "../services"

// LauncherSearch.qml -- the search field at the top of the launcher.
//
// The field and the keys that reach it, and nothing else. It reports intent
// and knows nothing about results:
//
//   moved(delta)      Up/Down, forwarded to the panel's selection
//   accepted()        Enter
//   queryEdited()     a keystroke, which the panel debounces
//
// It does not close anything on Escape either, and that is worth stating: the
// Keys handlers written twice on this component (once here as `Keys.*` and once
// on the TextInput inside components/SearchField.qml) are the reason a reader
// cannot tell which one is live. SearchField's TextInput takes the focus and
// consumes Up, Down and Escape, so the outer `Keys.*` blocks below can never
// fire; they are kept because they are the launcher's documented behaviour and
// deleting them is a behaviour change, not a refactor, so they are reported
// rather than quietly dropped. See the note in Launcher.qml.

Item {
    id: root

    implicitHeight: 32

    // The text, two-way. The panel reads it to run the query and writes "" to
    // clear a search left over from the last time the launcher opened.
    property alias text: field.text

    readonly property bool hasFocus: field.hasFocus

    signal moved(int delta)
    signal accepted()
    signal queryEdited()

    function focusInput() {
        field.focusInput()
    }

    SearchField {
        id: field

        // Width follows the row; height deliberately does NOT. This row is 32
        // tall and the field is 40 -- SearchField's own implicitHeight -- top
        // aligned and overhanging by 8, which is exactly what it did before
        // this was a file of its own: a RowLayout gives a child with
        // Layout.fillWidth but no fillHeight and no alignment its implicit
        // height rather than stretching it, and the magnifier and the
        // placeholder are both centred in 40. `anchors.fill: parent` would
        // make it 32 and lift those two glyphs by 4px. Measured with a
        // standalone layout probe, not guessed.
        width: parent.width

        placeholderText: "Search..."

        onNavigateDown: root.moved(1)

        onNavigateUp: root.moved(-1)

        // Unreachable: the TextInput inside SearchField has the focus and
        // consumes both of these first, then emits navigateUp/navigateDown,
        // which is what the two handlers above are for.
        Keys.onDownPressed: root.moved(1)

        Keys.onUpPressed: root.moved(-1)

        // Same story, and SearchField's own handler does this exactly.
        Keys.onEscapePressed: {
            UiState.closeAll()
        }

        onAccepted: root.accepted()

        // `textChanged`, not `textEdited`: clearing the field from the panel
        // is also a change, and both used to go through the same debounce.
        onTextChanged: root.queryEdited()
    }
}
