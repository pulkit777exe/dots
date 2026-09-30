pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    readonly property bool notchMode: data.notchMode
    readonly property real notchFlare: data.notchFlare
    readonly property real barHeight: data.barHeight
    readonly property real collapsedWidth: data.collapsedWidth
    readonly property real expandedHeight: data.expandedHeight
    readonly property real minimumExpandedWidth: data.minimumExpandedWidth
    readonly property real gapFromScreenEdge: data.gapFromScreenEdge

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    readonly property real expandedCornerRadius: data.expandedCornerRadius

    readonly property bool statusCircleEnabled: data.statusCircleEnabled
    readonly property bool albumArtCircleEnabled: data.albumArtCircleEnabled

    
    
    
    
    

    
    
    
    readonly property real innerPadding: data.innerPadding

    
    
    
    
    readonly property real collapsedCornerRadius: data.collapsedCornerRadius

    
    
    
    readonly property real stageLiftOnHover: data.stageLiftOnHover
    
    
    property real panelSlideIn: 22

    function setNotchMode(v) { data.notchMode = v; save(); }
    function setBarHeight(v) { data.barHeight = v; save(); }
    function setCollapsedWidth(v) { data.collapsedWidth = v; save(); }
    function setExpandedHeight(v) { data.expandedHeight = v; save(); }
    function setGapFromScreenEdge(v) { data.gapFromScreenEdge = v; save(); }
    function setExpandedCornerRadius(v) { data.expandedCornerRadius = v; save(); }
    function setStatusCircleEnabled(v) { data.statusCircleEnabled = v; save(); }
    function setAlbumArtCircleEnabled(v) { data.albumArtCircleEnabled = v; save(); }
    function setInnerPadding(v) { data.innerPadding = v; save(); }
    function setCollapsedCornerRadius(v) { data.collapsedCornerRadius = v; save(); }
    function setStageLiftOnHover(v) { data.stageLiftOnHover = v; save(); }

    
    
    
    readonly property real effectiveCollapsedRadius: Math.min(collapsedCornerRadius, barHeight / 2)

    
    
    property bool resolved: false

    
    
    
    function save() {
        if (!root.resolved) return;
        state.writeAdapter();
    }

    
    
    
    
    
    
    
    
    
    
    FileView {
        id: state
        path: Quickshell.statePath("bar-config.json")
        
        watchChanges: false
        printErrors: false
        onLoaded: root.resolved = true
        
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property bool notchMode: false
            property real notchFlare: 16
            property real barHeight: 33
            property real collapsedWidth: 90
            property real expandedHeight: 125
            property real minimumExpandedWidth: 440
            property real gapFromScreenEdge: 11
            property real expandedCornerRadius: 27
            property bool statusCircleEnabled: true
            property bool albumArtCircleEnabled: true
            property real innerPadding: 3
            property real collapsedCornerRadius: 20
            property real stageLiftOnHover: 7
        }
    }
}
