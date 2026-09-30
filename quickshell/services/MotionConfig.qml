pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    
    
    
    
    readonly property bool reduceMotion: data.reduceMotion
    readonly property real movementMs: data.movementMs        
    readonly property real fadeMs: data.fadeMs                
    readonly property real hoverMs: data.hoverMs              
    readonly property real bouncePercent: data.bouncePercent  

    
    
    
    readonly property real slideInMs: 260

    
    
    
    
    
    
    readonly property real springDamping: root.reduceMotion ? 1.0
        : Math.max(0.25, 0.7 - (root.bouncePercent / 100) * 0.4)

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
