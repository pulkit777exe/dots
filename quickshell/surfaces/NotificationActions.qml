import QtQuick

import "../components"

// NotificationActions.qml -- the row of action buttons under a toast.
//
// A notification's actions are named by whichever program sent it, so this file
// neither knows what they do nor decides whether to show them: it is handed
// the array the entry carried and reports an id back. What it does own is the
// one thing that is easy to get wrong twice -- `actions` is only sometimes an
// array. NotificationState.qml builds it, and a client that declared no
// actions, or a source that has not been through that builder at all, leaves
// it undefined, and `Repeater { model: undefined }` is a warning rather than an
// empty row. Hence the guard in one place, used by both the visibility and the
// model, instead of one in each.
//
// Flow rather than a RowLayout: the number of buttons is the sender's choice
// and D-Bus allows as many as it likes, so they wrap instead of overflowing a
// 449px toast.

Flow {
    id: root

    // Six is StyledButton's own height (36) plus the row above; Flow lays its
    // children out on one line and wraps below that, so this is a gap, not a
    // margin the caller has to add.
    spacing: 6

    property var actionList: []

    readonly property bool hasActions:
        Array.isArray(root.actionList) &&
        root.actionList.length > 0

    signal invoked(string actionId)

    visible: root.hasActions

    Repeater {
        // The same guard as `hasActions`, deliberately not the same expression:
        // visibility has to tolerate a non-array, the model cannot.
        model:
            Array.isArray(root.actionList)
                ? root.actionList
                : []

        delegate: StyledButton {
            required property var modelData

            text: modelData.label || ""

            // Ghost, because the toast is already the accent: a filled button
            // here would compete with the notification it belongs to.
            variant: "ghost"

            onClicked: root.invoked(modelData.id || "")
        }
    }
}
