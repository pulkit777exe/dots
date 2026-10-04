import QtQuick
import "../services"

// The bar's geometry for ONE monitor, resolved in one place.
//
// Every number the three island regions draw with comes from here, and
// every one of them is the per-monitor value rather than the global one:
// a BarConfigMonitors instance layers monitors/<name>.json over BarConfig,
// so a monitor that lowers barHeight gets a proportionally smaller collapsed
// radius (see effectiveCollapsedRadius) and a dot that still fits inside it.
//
// This is a QtObject rather than an Item, so it adds no scene graph node.
// It exists so the resolution lives in exactly one file. Spread across the
// three regions as ten separate properties each, adding a per-monitor key
// would mean editing four files and hoping they stayed in step; here it is
// one declaration, and a region that needs a new number asks for it.
//
// The override reader is a child of this object, built here, and handed this
// monitor's name as an argument -- not asked for it afterwards. It used to be
// a `pragma Singleton` that this file called into from
// `Component.onCompleted: BarConfigMonitors.loadFor(screenName)`, which was
// last-writer-wins: one Island is built per screen, so every screen wrote to
// the one copy and they all read whichever wrote last. See the header comment
// in services/BarConfigMonitors.qml.
QtObject {
    id: root

    // Which monitor these values are for, e.g. "eDP-1". One Island is
    // built per screen, so each instance is handed its own screen's name by
    // shell.qml and resolves monitors/<name>.json for itself.
    property string screenName: ""

    // This monitor's overrides, as its own object. A `readonly property`
    // rather than a bare child object because a QtObject has no default
    // property: `BarConfigMonitors { }` written inside one fails to compile
    // with "Cannot assign to non-existent default property". Same reason the
    // three regions below are handed `metrics` rather than reaching for it.

    // The binding is the whole fix. `screenName` is required and is filled
    // once, here, from this object's own name -- so the reader's file path
    // cannot be pointed at a different monitor after the fact, and two
    // screens cannot both believe they own one copy of it.
    readonly property BarConfigMonitors monitorOverrides: BarConfigMonitors {
        screenName: root.screenName
    }

    // Per-monitor geometry, falling back to the global BarConfig value for
    // any key this monitor's file does not name. The global values are
    // unchanged by an override -- these are reads, not writes -- so
    // removing the file restores exactly the previous bar.
    property bool notchMode: BarConfig.notchMode
    property real barHeight: monitorOverrides.value("barHeight", BarConfig.barHeight)
    property real collapsedWidth: monitorOverrides.value("collapsedWidth", BarConfig.collapsedWidth)
    property real gapFromEdge: monitorOverrides.value("gapFromScreenEdge", BarConfig.gapFromScreenEdge)
    property real expandedCornerRadius: monitorOverrides.value("expandedCornerRadius", BarConfig.expandedCornerRadius)
    property real collapsedCornerRadius: monitorOverrides.value("collapsedCornerRadius", BarConfig.collapsedCornerRadius)

    // The three below are per-monitor-overridable and currently read by no
    // region: they were resolved on Island.qml before this split and nothing
    // outside it ever read them either. They are kept, and declared rather
    // than dropped, so the set of keys an override can reach stays visible
    // here instead of being quietly narrowed by a refactor. Each is a read,
    // so nothing about the bar's behaviour depends on them.
    property real notchFlare: monitorOverrides.value("notchFlare", BarConfig.notchFlare)
    property real expandedHeight: monitorOverrides.value("expandedHeight", BarConfig.expandedHeight)
    property real minimumExpandedWidth: monitorOverrides.value("minimumExpandedWidth", BarConfig.minimumExpandedWidth)

    // BarConfig computes this from the global values, so it is recomputed
    // here from the resolved ones. A monitor that lowers barHeight must get
    // a proportionally smaller collapsed radius, or the pill is taller than
    // the dot it sits in and clips.
    readonly property real effectiveCollapsedRadius: Math.min(collapsedCornerRadius, barHeight / 2)

    // Where the bar sits down the screen. In notch mode it is flush with the
    // top edge, because the notch itself is the top edge; otherwise it floats
    // gapFromEdge below it. Read by all three regions.
    readonly property real topOffset: notchMode ? 0 : gapFromEdge

    // The gap between the centre panel and each dot when they are all
    // collapsed. Also the resting distance between two dots, since both dots
    // hang off the centre panel's edge by this much.
    readonly property real dotSpacing: 10
}
