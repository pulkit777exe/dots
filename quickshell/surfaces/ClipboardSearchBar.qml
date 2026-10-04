import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// ClipboardSearchBar.qml -- the clipboard panel's header: the search field
// and Clear all.
//
// Extracted from ClipboardHistory.qml. The panel owns the selection; this
// file owns the two things in the header that are not layout -- writing what
// was typed into Clipboard.query, and wiping the history -- and it owns the
// search field itself, which is why the panel talks to `focusAndClear()` and
// `hasFocus` instead of reaching into a SearchField id.
//
// Two signals go back up: moveSelection(delta) for the arrow keys, and
// accepted() for Enter. queryEdited() fires after every keystroke and after
// focusAndClear() empties the field, which is the panel's cue to put its
// selection back on the first match.
//
// Clear all is visible whenever there is anything to clear, which is
// Clipboard.entries and not the filtered list: a search that matches nothing
// does not mean there is nothing to wipe.

Item {
    id: root

    implicitHeight: 44

    readonly property bool hasFocus:
        search.hasFocus

    signal moveSelection(int delta)
    signal accepted()
    signal queryEdited()


    function focusAndClear() {
        search.text = ""
        search.focusInput()
    }


    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: 8
        anchors.rightMargin: 8

        spacing: 8

        SearchField {
            id: search

            Layout.fillWidth: true

            placeholderText:
                "Search clipboard..."

            onNavigateDown:
                root.moveSelection(1)

            onNavigateUp:
                root.moveSelection(-1)

            // These three are unreachable. SearchField's own TextInput handles
            // down, up and escape and sets event.accepted on all three, which
            // ends key propagation before it reaches this item -- so the
            // onNavigateDown/onNavigateUp above are what actually run, and
            // these never do. They were in ClipboardHistory.qml before the
            // extraction and are kept rather than dropped: SearchField is not
            // this surface's file, and a copy of its keyboard contract here is
            // cheaper than a silent dependency on somebody else's.
            Keys.onDownPressed:
                root.moveSelection(1)

            Keys.onUpPressed:
                root.moveSelection(-1)

            Keys.onEscapePressed:
                UiState.closeAll()

            onAccepted:
                root.accepted()

            onTextChanged: {
                Clipboard.query = text
                root.queryEdited()
            }
        }

        Rectangle {
            Layout.preferredHeight: 32

            Layout.preferredWidth:
                clearText.implicitWidth + 16

            radius: 16

            color:
                clearHover.hovered
                    ? Theme.withAlpha(Theme.colors.danger, 0.15)
                    : "transparent"

            visible:
                Clipboard.entries.length > 0

            StyledText {
                id: clearText

                anchors.centerIn: parent

                font.pixelSize: 12
                font.weight: Font.Medium

                textColor:
                    Theme.colors.danger

                text: "Clear all"
            }

            HoverHandler {
                id: clearHover

                cursorShape:
                    Qt.PointingHandCursor
            }

            TapHandler {
                onTapped:
                    Clipboard.wipe()
            }
        }
    }
}
