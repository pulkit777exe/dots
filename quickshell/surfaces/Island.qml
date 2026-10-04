import QtQuick
import "../services"

// The bar window's contents: three panels laid out across the top.
//
// This file is the layout and nothing else. It resolves nothing, draws
// nothing, and decides no sizes of its own beyond where each region sits and
// how tall the window has to be for them. The three regions are:
//
//   IslandLeftDot       album art at rest, media player when expanded
//   IslandCenterPanel   the notch at rest, every surface that opens in it
//   IslandRightDot      battery and wifi at rest, control centre when expanded
//
// and the geometry they share is resolved once, per monitor, in
// IslandMetrics.qml.
//
// The one piece of knowledge this file owns that the regions cannot: the
// dots hang off the CENTRE panel's edges, so it measures the centre panel and
// hands its x and width to the two dots. That is why the centre is declared
// before them -- it has to exist before anything can read its geometry.
//
// Sibling order here is not meaningful to painting. Each region draws one
// opaque Surface and they never overlap at rest; when one expands it grows
// toward the centre panel rather than over it.
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

    // shell.qml's input mask is built from these three Regions, so each has
    // to be the region root itself -- the Region follows that item's
    // position and size, and a Region pointed at anything inside it would
    // mask the wrong rectangle. They are aliases rather than extra Items so
    // the thing masked is provably the thing drawn.
    property alias leftSurfaceItem: leftDot
    property alias centerSurfaceItem: centerPanel
    property alias rightSurfaceItem: rightDot

    // How tall the bar window has to be for whichever region is tallest,
    // measured from its y, plus slack. Derived from the regions rather than
    // kept as a number: the control centre's sound view is far taller than
    // the resting bar, and a kept height clipped its last rows with nothing
    // logged. A region that grows taller now takes the window with it.
    implicitHeight: Math.max(
        leftDot.height + leftDot.y,
        Math.max(centerPanel.height + centerPanel.y,
                 rightDot.height + rightDot.y)) + 20

    IslandCenterPanel {
        id: centerPanel
        metrics: islandMetrics
        // Read by the settings page's height clamp, which is per screen
        // because one panel is built per output.
        screenName: root.screenName
    }

    IslandLeftDot {
        id: leftDot
        metrics: islandMetrics
        // The bar window's width, not this region's: the expanded panel
        // clamps itself against the window, and this region resizes to the
        // panel, so reading its own width would make the clamp circular.
        availableWidth: root.width
        centerX: centerPanel.x
        centerIsOsd: centerPanel.isOsd
    }

    IslandRightDot {
        id: rightDot
        metrics: islandMetrics
        availableWidth: root.width
        // Both, because the centre panel is not a fixed width: an OSD widens
        // it to 275 in the middle of a keypress, and this dot has to move
        // with the panel's right edge.
        centerX: centerPanel.x
        centerWidth: centerPanel.width
        centerIsOsd: centerPanel.isOsd
    }

    Keys.onEscapePressed: UiState.closeAll()
    focus: UiState.anyOpen
    Keys.enabled: UiState.anyOpen
}
