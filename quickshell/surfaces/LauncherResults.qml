import QtQuick

import "../components"
import "../services"

// LauncherResults.qml -- the results list: how many rows fit, the highlight
// that slides behind them, the rows, and the hover that overrides the
// highlight.
//
// Everything about *when* this list changes stays in Launcher.qml -- the
// debounce, the crossfade, the selectedIndex that the arrow keys walk, and the
// AppLauncher query behind all of it. This file is handed a list and an index
// and reports which row was hovered and which was clicked; it never asks
// AppLauncher a question and never calls UiState. That is the seam worth
// having: the selection logic was previously interleaved with the row drawing,
// and the drawing was the half nobody could test.
//
// An Item, not the Flickable, on purpose. The row count decides the height, and
// Launcher.qml animates that height when the result count changes -- a
// Flickable root would own its own height and there would be nothing left to
// animate. So the Flickable fills this, and `implicitHeight` is the request.

Item {
    id: root

    // `AppLauncher.results`, passed in. Nothing here reads it directly, which
    // is what makes this file renderable by a preview that has no launcher.
    property var results: []

    property int selectedIndex: 0
    property int hoverIndex: -1

    // -1 means "the pointer left the list", which is what restores the
    // keyboard's highlight.
    signal rowHovered(int index)
    signal rowActivated(int index)

    readonly property real rowHeight: ConfigStore.launcherRowHeight

    // Both minimums matter and for different reasons: a count of 0 gives an
    // empty list, and a rowsBeforeScrolling of 0 would give an invisible one.
    // `max(1, count)` on the scroll height is the same guard for the
    // Flickable, which is why the two are not one property.
    readonly property int visibleRowCount:
        Math.min(
            Math.max(1, root.results.length),
            Math.max(1, ConfigStore.launcherRowsBeforeScrolling)
        )

    implicitHeight: visibleRowCount * rowHeight

    clip: true

    // Animated by Launcher.qml's search transition, which reaches in from
    // outside rather than being duplicated here. Declared so the property is
    // this file's to document.
    opacity: 1

    Flickable {
        id: flick

        anchors.fill: parent

        clip: true
        boundsBehavior: Flickable.StopAtBounds

        contentWidth: width
        contentHeight:
            Math.max(1, root.results.length) * root.rowHeight

        // z: 0 against the rows' z: 1. The highlight is a child of the
        // Flickable's contentItem, so it scrolls with the list; the explicit
        // ordering is what puts it behind a ListRow that paints an opaque
        // background.
        Rectangle {
            id: selectionSurface

            z: 0

            x: 0

            width: flick.width
            height: root.rowHeight

            y: targetIndex * root.rowHeight

            radius: 12

            // Hover wins over the keyboard, and clearing hover falls back to
            // it. One expression rather than two watchers: a row under the
            // pointer that is not the selected one still lights up.
            property int targetIndex:
                root.hoverIndex >= 0
                    ? root.hoverIndex
                    : root.selectedIndex

            color: Theme.colors.surfaceAlt

            visible: root.results.length > 0

            Behavior on y {
                enabled: !MotionConfig.reduceMotion

                NumberAnimation {
                    duration: MotionConfig.movement(0.425)
                    easing.type: Easing.OutCubic
                }
            }

            // The accent bar on the leading edge. 3 wide, 22 tall, 2 in: the
            // row is 46 by default, so it is a marker rather than a border.
            Rectangle {
                width: 3
                height: 22

                radius: 2

                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter

                color: Theme.colors.accent
            }
        }

        Repeater {
            model: root.results

            // `root` here is this file, not Launcher: an inline delegate can
            // see the ids of the file that declares it, so moving the row out
            // of Launcher.qml is what lets these bindings be checked at all
            // (qmllint flagged every one of them as unqualified access while
            // they reached across the panel).
            delegate: ListRow {
                id: row

                required property int index
                required property var modelData

                z: 1

                x: 0
                y: index * root.rowHeight

                width: root.width
                height: root.rowHeight

                icon: modelData.icon
                iconSource: modelData.iconSource || ""

                title: modelData.title
                subtitle: modelData.subtitle

                selected: index === root.selectedIndex

                // The panel's own appear animation already fades the whole
                // list in; a second staggered fade per row on top of it is
                // 46ms x 6 of motion for nothing.
                animateAppearance: false

                onHovered: root.rowHovered(index)

                // The index is reported rather than applied here: setting
                // selectedIndex is the panel's business, because it is the
                // same index the arrow keys move and the same one
                // activateSelection() reads.
                onClicked: root.rowActivated(index)
            }
        }

        // Covers the gaps between rows and the empty space below the last one.
        // A HoverHandler rather than per-row hover because ListRow's own
        // handler only fires over the row's painted area.
        HoverHandler {
            onHoveredChanged: {
                if (!hovered)
                    root.rowHovered(-1)
            }
        }
    }
}
