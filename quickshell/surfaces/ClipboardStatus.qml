import QtQuick

import "../components"
import "../services"

// ClipboardStatus.qml -- the line the clipboard panel shows when it has no
// list to show.
//
// Three reasons there is nothing to draw and only one of them is ever on
// screen: cliphist is not installed, the history is empty, or the query
// filtered every entry out. The panel carried two StyledTexts for this -- one
// for "empty or no match", one for "cliphist is missing" -- and the two
// conditions are mutually exclusive, so there was never a moment when both
// were visible. One component, three sentences.
//
// Which of the three applies is Clipboard's to know, so this file asks
// Clipboard instead of taking a message: a caller handed the right sentence
// would still have to re-derive the same three-way condition to decide
// whether to show the line at all, and the two would drift apart.
//
// Nothing here is laid out. Width, margins and centring belong to the
// panel's ColumnLayout, which is what puts this between the header and the
// list -- an invisible item in a layout costs no height, so the panel is
// exactly as tall with entries as without.

StyledText {
    font.pixelSize: 13

    horizontalAlignment:
        Text.AlignHCenter

    visible:
        !Clipboard.available ||
        Clipboard.filteredEntries.length === 0

    text:
        !Clipboard.available
            ? "cliphist is not installed or available."
            : (
                Clipboard.entries.length === 0
                    ? "Clipboard is empty"
                    : "No matching items found"
              )

    textColor:
        !Clipboard.available
            ? Theme.colors.danger
            : Theme.withAlpha(Theme.colors.text, 0.5)
}
