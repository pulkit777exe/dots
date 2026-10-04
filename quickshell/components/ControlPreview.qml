import QtQuick
import "../services"

// Renders one slot of the Control Center layout editor: the live-looking
// preview of a control, plus the selection ring and remove badge drawn over
// it when the editor has it selected.
//
// This is a leaf. It knows a control's `type` string and nothing about the
// layout that placed it -- it never reads ControlCenterLayout, never imports
// the editor, and is used by exactly one caller. All it does is dispatch the
// type string to one of the Preview* primitives and bind that primitive's
// properties to the relevant service singleton. Adding a control means adding
// a catalogue entry in ControlCenterLayout plus one stanza here.
Item {
    id: root

    property string controlType: ""

    // The editor passes the slot's spans so the preview could shape itself to
    // the cell it occupies. Nothing here reads them yet: every Preview*
    // primitive sizes itself from its own implicit size and is then stretched
    // by the editor's `anchors.fill`. Kept because the editor's API promises
    // them, not because they are load-bearing.
    property int colSpan: 1
    property int rowSpan: 1

    property bool selected: false

    PreviewStatusPill {
        anchors.fill: parent
        visible: root.controlType === "wifi"
        title: "Wi-Fi"; iconName: "wifi"; isOn: Wifi.connected
        subtitle: Wifi.connected ? (Wifi.ssid || "Connected") : "Off"
    }

    PreviewStatusPill {
        anchors.fill: parent
        visible: root.controlType === "bluetooth"
        title: "Bluetooth"; iconName: "bluetooth"; isOn: Bluetooth.enabled
        subtitle: Bluetooth.enabled ? (Bluetooth.connectedName || "On") : "Off"
    }

    PreviewStatusPill {
        anchors.fill: parent
        visible: root.controlType === "focus"
        title: "Focus"; iconName: "do_not_disturb_on"; isOn: Notifications.dnd
        subtitle: Notifications.dnd ? "On" : "Off"
    }

    PreviewStatusPill {
        anchors.fill: parent
        visible: root.controlType === "gameMode"
        title: "Game Mode"; iconName: "sports_esports"
        isOn: PowerProfile.active === "performance"
        subtitle: PowerProfile.active === "performance" ? "On" : "Off"
    }

    PreviewStatusPill {
        anchors.fill: parent
        visible: root.controlType === "nowPlaying"
        title: Media.hasPlayer ? (Media.title || "Now Playing") : "Nothing playing"
        iconName: "music_note"
        isOn: Media.hasPlayer
        subtitle: Media.artist || "Now Playing"
    }

    PreviewStatusPill {
        anchors.fill: parent
        visible: root.controlType === "clipboard"
        title: "Clipboard"; iconName: "content_paste"
        isOn: Clipboard.entries.length > 0
        subtitle: Clipboard.entries.length + (Clipboard.entries.length === 1 ? " entry" : " entries")
    }

    PreviewDiscButton {
        anchors.fill: parent
        visible: root.controlType === "lock"
        iconName: "lock"
    }

    PreviewDiscButton {
        anchors.fill: parent
        visible: root.controlType === "nightLight"
        iconName: "dark_mode"
        isOn: NightLight.enabled
    }

    PreviewDiscButton {
        anchors.fill: parent
        visible: root.controlType === "idleInhibit"
        iconName: "coffee"
        isOn: IdleInhibit.active
    }

    PreviewDiscButton {
        anchors.fill: parent
        visible: root.controlType === "battery"
        iconName: Battery.charging ? "battery_charging_full" : "battery_std"
        isOn: Battery.available
    }

    PreviewSliderCard {
        anchors.fill: parent
        visible: root.controlType === "sound"
        title: "Sound"
        iconName: Volume.iconName || "volume_up"
        fraction: Volume.volume
        chipText: "Night Light"
        chipOn: NightLight.enabled
    }

    PreviewSliderCard {
        anchors.fill: parent
        visible: root.controlType === "display"
        title: "Display"
        iconName: "brightness_high"
        fraction: Brightness.available ? Brightness.level / 100 : 0
    }

    PreviewNotificationList {
        anchors.fill: parent
        visible: root.controlType === "notifications"
    }

    // Selection chrome, drawn last so it sits over whatever preview the type
    // string selected. The ring is a rounded-rect border rather than a plain
    // one because a status pill's own radius follows the cell's short axis,
    // and the ring has to trace the same shape.
    Rectangle {
        anchors.fill: parent
        radius: Math.min(parent.height / 2, parent.width / 2)
        color: "transparent"
        border.width: root.selected ? 1.5 : 0
        border.color: Theme.colors.accent
        visible: root.selected
    }

    // Deliberately outside the top-left corner rather than inside it, so the
    // badge reads as belonging to the slot rather than to the preview.
    Rectangle {
        visible: root.selected
        width: 20; height: 20; radius: 10
        color: Theme.colors.danger
        x: -10
        y: -10
        z: 2

        Icon {
            anchors.centerIn: parent
            icon: "remove"
            size: 13
            // The "remove" badge's cross sits on `Theme.colors.danger`. The
            // palette key for a glyph drawn on a saturated fill is `accentText`
            // -- the same one CcTokens calls `onAccent` -- so this is #101010
            // rather than the #FFFFFF it was.
            iconColor: Theme.colors.accentText
        }
    }
}
