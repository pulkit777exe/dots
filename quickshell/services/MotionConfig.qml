pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    
    
    
    
    // User setting, or forced by the environment, or implied by low-spec.
    //
    // QUICKSHELL_REDUCE_MOTION=1 used to be accepted and then ignored:
    // DeviceProfile logged "reduce motion forced via env" and never set
    // anything, because reduceMotion lives here and nothing connected the
    // two. So the documented way to force it silently did nothing.
    //
    // DeviceProfile.lowSpec is folded in deliberately. Halving the shadow
    // blur and dropping cava to 15fps is pointless if every transition still
    // animates at full length, and a machine that needed low-spec is usually
    // the one least able to run the animations. `setReduceMotion` writes only
    // the user preference, so turning low-spec off later restores whatever
    // the user actually chose.
    readonly property bool reduceMotion:
        data.reduceMotion
        || Quickshell.env("QUICKSHELL_REDUCE_MOTION") === "1"
        || DeviceProfile.lowSpec
    readonly property real movementMs: data.movementMs        
    readonly property real fadeMs: data.fadeMs                
    readonly property real hoverMs: data.hoverMs              
    readonly property real bouncePercent: data.bouncePercent  

    
    
    
    readonly property real slideInMs: 260

    
    
    
    
    
    
    readonly property real springDamping: root.reduceMotion ? 1.0
        : Math.max(0.45, 0.75 - (root.bouncePercent / 100) * 0.35)

    function setReduceMotion(v) { data.reduceMotion = v; save(); }
    function setMovementMs(v) { data.movementMs = v; save(); }
    function setFadeMs(v) { data.fadeMs = v; save(); }
    function setHoverMs(v) { data.hoverMs = v; save(); }
    function setBouncePercent(v) { data.bouncePercent = v; save(); }

    
    
    
    
    
    
    
    
    function fade(scale) { return reduceMotion ? 0 : fadeMs * (scale || 1); }
    function hover(scale) { return reduceMotion ? 0 : hoverMs * (scale || 1); }
    
    
    
    
    
    
    
    
    
    function movement(scale) { return reduceMotion ? 0 : movementMs * (scale || 1); }

    function save() {
        
        
        
        
        if (!root.resolved) return;
        state.writeAdapter();
    }

    
    
    property bool resolved: false


    
    
    
    
    
    
    
    
    
    
    FileView {
        id: state
        path: Quickshell.statePath("motion-config.json")
        
        watchChanges: false
        printErrors: false
        onLoaded: root.resolved = true
        
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property bool reduceMotion: false
            property real movementMs: 400
            property real fadeMs: 200
            property real hoverMs: 150
            property real bouncePercent: 40
        }
    }
}
