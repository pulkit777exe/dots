import QtQuick
import QtQuick.Layouts
import "../services"

// ControlPreview
// Renders one Control Center control at whatever size the arranger has placed
// it, from live service state -- the arranger's canvas is a picture of the
// real panel, not a mock-up, so anything that can change in the popover
// changes here too.
//
// Sizes are expressed in grid cells and resolved by the caller; this component
// only ever fills whatever box it is given. Which of the shapes a control takes
// is decided by its type, not by its span: a 1x1 is a bare disc, a wide pill is
// a labelled pill, and sound / display / notifications keep their own layouts
// at any span.
//
// The four shapes are declared as inline components and then instantiated as
// ordinary children gated on `visible`, rather than picked through a Loader's
// sourceComponent. QML has no `return Type { ... }` form, so a switch inside a
// JS binding cannot build a typed inline component -- that is a parse error at
// the brace, not a runtime one.
Item {
    id: root

    property string controlType: ""
    property int colSpan: 1
    property int rowSpan: 1
    // True when the arranger has this control selected: draws the teal ring
    // and the remove badge.
    property bool selected: false

    // ---- The four shapes -------------------------------------------------

    component StatusPill: Item {
        id: pill
        property string title: ""
        property string subtitle: ""
        property string iconName: ""
        // Named isOn, not on: `on` is QML's signal-handler keyword, so a
        // property called `on` does not parse -- `on:` reads as the start of a
        // handler declaration and the parser then wants an identifier.
        property bool isOn: false
        property bool showSubtitle: true

        implicitHeight: 52
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.055)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 16
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                // Filled accent when on, a flat wash when off -- the same
                // treatment the settings nav uses at 44%.
                color: pill.isOn ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.07)

                Icon {
                    anchors.centerIn: parent
                    icon: pill.iconName
                    size: 19
                    iconColor: pill.isOn ? "#0B1512" : Qt.rgba(1, 1, 1, 0.75)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: pill.title
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: "#F6E2CB"
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: pill.showSubtitle
                    text: pill.subtitle
                    font.pixelSize: 11
                    textColor: Qt.rgba(1, 1, 1, 0.55)
                    elide: Text.ElideRight
                }
            }
        }
    }

    component DiscButton: Item {
        id: disc
        property string iconName: ""
        property bool isOn: false
        implicitWidth: 52
        implicitHeight: 52
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: disc.isOn ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.055)
        }
        Icon {
            anchors.centerIn: parent
            icon: disc.iconName
            size: 21
            iconColor: disc.isOn ? "#0B1512" : Qt.rgba(1, 1, 1, 0.8)
        }
    }

    // A full-width drill-down: title row with a chevron, then a slider.
    component SliderCard: Item {
        id: card
        property string title: ""
        property string iconName: ""
        property real fraction: 0
        property string chipText: ""
        property bool chipOn: true
        implicitHeight: 68

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.055)
        }

        StyledText {
            id: titleText
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 11
            text: card.title
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: "#F6E2CB"
        }

        Icon {
            anchors.right: parent.right
            anchors.verticalCenter: titleText.verticalCenter
            anchors.rightMargin: 14
            icon: "chevron_right"
            size: 16
            iconColor: Qt.rgba(1, 1, 1, 0.45)
        }

        Item {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            height: 22

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.11)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(1, card.fraction))
                height: 6
                radius: 3
                color: Theme.colors.accent
            }
            Icon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: card.iconName
                size: 15
                iconColor: Theme.colors.accent
            }
            // The chip rides on the fill, exactly as the reference shows the
            // "Night Light" pill sitting inside the Sound card's slider.
            Rectangle {
                visible: card.chipText.length > 0
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width,
                                         parent.width * card.fraction - width / 2))
                width: chipLabel.implicitWidth + 26
                height: 22
                radius: 11
                color: card.chipOn ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.12)
                StyledText {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: card.chipText
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: card.chipOn ? "#0B1512" : "#F6E2CB"
                }
            }
        }
    }

    component NotificationList: Item {
        id: list
        // Two entries at most: the arranger's cell is 52px tall per row, so a
        // taller list would push the grid's aspect away from the popover's.
        readonly property var shown: Notifications.active.slice(0, 2)
        implicitHeight: 40 + Math.max(1, shown.length) * 64

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.055)
        }

        StyledText {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 13
            text: "Notifications"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: "#F6E2CB"
        }

        StyledText {
            anchors.top: head.top
            anchors.right: parent.right
            anchors.rightMargin: 16
            text: "Clear all"
            font.pixelSize: 12
            textColor: Qt.rgba(1, 1, 1, 0.55)
        }

        Column {
            anchors.top: head.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            // One null placeholder when the stack is empty, so the card keeps
            // its height instead of collapsing to a bare header.
            Repeater {
                model: list.shown.length ? list.shown : [null]

                delegate: Rectangle {
                    id: notifRow
                    required property var modelData

                    readonly property string sender: modelData
                        ? (modelData.appName || modelData.app || "notify-send") : "notify-send"
                    readonly property string summary: modelData
                        ? (modelData.summary || modelData.title || "") : "All caught up"
                    readonly property string body: modelData ? (modelData.body || "") : ""

                    width: parent.width
                    height: 56
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.035)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: Qt.alpha(Theme.colors.accent, 0.18)
                            StyledText {
                                anchors.centerIn: parent
                                text: notifRow.sender.slice(0, 1).toUpperCase()
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.colors.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: notifRow.sender
                                font.pixelSize: 10
                                textColor: Qt.rgba(1, 1, 1, 0.5)
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: notifRow.summary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#F6E2CB"
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: notifRow.body
                                font.pixelSize: 11
                                textColor: Qt.rgba(1, 1, 1, 0.55)
                                elide: Text.ElideRight
                            }
                        }

                        Icon {
                            icon: "close"
                            size: 14
                            iconColor: Qt.rgba(1, 1, 1, 0.4)
                        }
                    }
                }
            }
        }
    }

    // ---- One instance per shape, gated on the control's type -------------

    StatusPill {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "wifi"
        title: "Wi-Fi"; iconName: "wifi"; isOn: Wifi.connected
        subtitle: Wifi.connected ? (Wifi.ssid || "Connected") : "Off"
    }

    StatusPill {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "bluetooth"
        title: "Bluetooth"; iconName: "bluetooth"; isOn: Bluetooth.enabled
        subtitle: Bluetooth.enabled ? (Bluetooth.connectedName || "On") : "Off"
    }

    StatusPill {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "focus"
        title: "Focus"; iconName: "do_not_disturb_on"; isOn: Notifications.dnd
        subtitle: Notifications.dnd ? "On" : "Off"
    }

    StatusPill {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "gameMode"
        title: "Game Mode"; iconName: "sports_esports"
        isOn: PowerProfile.active === "performance"
        subtitle: PowerProfile.active === "performance" ? "On" : "Off"
    }

    StatusPill {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "nowPlaying"
        title: Media.hasPlayer ? (Media.title || "Now Playing") : "Nothing playing"
        iconName: "music_note"
        isOn: Media.hasPlayer
        subtitle: Media.artist || "Now Playing"
    }

    StatusPill {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "clipboard"
        title: "Clipboard"; iconName: "content_paste"
        isOn: Clipboard.entries.length > 0
        subtitle: Clipboard.entries.length + (Clipboard.entries.length === 1 ? " entry" : " entries")
    }

    DiscButton {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "lock"
        iconName: "lock"
    }

    DiscButton {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "nightLight"
        iconName: "dark_mode"
        isOn: NightLight.enabled
    }

    DiscButton {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "idleInhibit"
        iconName: "coffee"
        isOn: IdleInhibit.active
    }

    DiscButton {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "battery"
        iconName: Battery.charging ? "battery_charging_full" : "battery_std"
        isOn: Battery.available
    }

    SliderCard {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "sound"
        title: "Sound"
        iconName: Volume.iconName || "volume_up"
        // Volume exposes `volume` (0..1) and `volumePercent`; there is no
        // `level`. The reference's Sound card fills its slider from this.
        fraction: Volume.volume
        chipText: "Night Light"
        chipOn: NightLight.enabled
    }

    SliderCard {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "display"
        title: "Display"
        iconName: "brightness_high"
        fraction: Brightness.available ? Brightness.level / 100 : 0
    }

    NotificationList {
        // Fill the slot the arranger gives this control. Without it the
        // shape fell back to its implicit size, and StatusPill and
        // SliderCard declare only an implicitHeight -- so they rendered
        // 0px wide and the icon disc sat on top of the title instead of
        // beside it. DiscButton happened to look right only because its
        // 52x52 implicit size is close to a 1x1 cell.
        anchors.fill: parent
        visible: root.controlType === "notifications"
    }

    // ---- Selection chrome (the arranger's, not the control's) -----------

    Rectangle {
        anchors.fill: parent
        radius: Math.min(parent.height / 2, parent.width / 2)
        color: "transparent"
        border.width: root.selected ? 1.5 : 0
        border.color: Theme.colors.accent
        visible: root.selected
    }

    // The remove affordance, on the selected control's top-left, half outside
    // so it reads as a badge rather than a button sitting inside the control.
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
            iconColor: "#FFFFFF"
        }
    }
}
