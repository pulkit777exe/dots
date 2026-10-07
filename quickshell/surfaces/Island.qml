import QtQuick
import "../services"

// The bar window's contents: the island.
//
// This file is the layout and nothing else. It resolves nothing, draws
// nothing, and decides no sizes of its own beyond how tall the window has to
// be for the one panel it contains. There used to be three of them -- a
// centre notch with a dot either side -- and this file's one real job was
// measuring the centre and handing its x and width to the two dots, because
// they hung off its edges. With one surface there is nothing left to hand
// around, so what is left is the panel, its per-monitor geometry from
// IslandMetrics.qml, and the two pass-throughs shell.qml reads.
//
// Sibling order here is not meaningful to painting: there is one child.
Item {
    id: root

    // The screen this bar is on, e.g. "eDP-1". One Island is built per
    // screen, so each instance resolves its own monitors/<name>.json.
    //
    // Passed in from shell.qml rather than read from `modelData` here:
    // Island is nested inside the bar's PanelWindow, not a direct child of
    // the Variants model, so the model never reaches it. Declaring
    // `required property var modelData` to get at it produces "Required
    // property modelData was not initialized" on every screen and the bar
    // silently loses its per-monitor resolution.
    property string screenName: ""

    // Resolved once and shared. A QtObject, so it costs no scene graph node;
    // see IslandMetrics.qml for why the resolution lives in its own file.
    IslandMetrics {
        id: islandMetrics
        screenName: root.screenName
    }

    // shell.qml reads these three off the Island to size the window's
    // exclusive zone and to decide what fullscreen hides. They are declared
    // here rather than used through islandMetrics so that shell.qml does not
    // have to know the resolution lives one level down; they are pure
    // pass-throughs, and the single place the pass-throughs stop is if
    // shell.qml grows a fourth read.
    readonly property bool notchMode: islandMetrics.notchMode
    readonly property real barHeight: islandMetrics.barHeight
    readonly property real gapFromEdge: islandMetrics.gapFromEdge

    // shell.qml's input mask is built from this one Region, so it has to be
    // the region root itself -- the Region follows that item's position and
    // size, and a Region pointed at anything inside it would mask the wrong
    // rectangle. An alias rather than an extra Item so the thing masked is
    // provably the thing drawn.
    //
    // This used to be three aliases, one per region, which is exactly the
    // count you would expect: the mask has to cover every part of the bar
    // that takes a click, and three floating surfaces need three rectangles.
    // One island needs one.
    property alias surfaceItem: panel

    // How tall the bar window has to be, measured from the panel's y plus
    // slack. Derived from the panel rather than kept as a number: the control
    // centre's sound view is far taller than the resting bar, and a kept
    // height clipped its last rows with nothing logged. A panel that grows
    // taller now takes the window with it.
    implicitHeight: panel.height + panel.y + 20

    IslandPanel {
        id: panel
        metrics: islandMetrics
        // Read by the settings page's height clamp and by the workspace
        // indicator, both per screen because one panel is built per output.
        screenName: root.screenName
    }

    Keys.onEscapePressed: UiState.closeAll()
    focus: UiState.anyOpen
    Keys.enabled: UiState.anyOpen
}
