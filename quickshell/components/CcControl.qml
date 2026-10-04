import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"


Item {
    id: cc

    CcTokens { id: ccColors }

    property string controlType: ""

    // Handed down to whichever body is loaded, so `originInRoot()` can map to
    // the panel rather than to this component or to the Loader above it.
    property Item panel


    signal drillRequested(string view, point origin)


    readonly property real cellHeight: {
        switch (controlType) {
        case "lock": case "nightLight": case "idleInhibit": case "battery":
            return 60
        case "sound": case "display":
            return 52
        case "notifications":
            return Math.max(176, notifGridInner.implicitHeight + 28)
        default:
            return 57
        }
    }


    readonly property bool isDisc: cellHeight === 60

    // One child instead of eleven. Each cell used to declare all eleven
    // and hide ten with `visible: cc.controlType === "..."`, so nine cells
    // built ninety controls to draw nine. cellHeight is already the height
    // each of these wanted, so the Loader hands it over and the bodies
    // below carry content only.
    Loader {
        x: cc.isDisc ? (cc.width - 60) / 2 : 0
        width: cc.isDisc ? 60 : cc.width
        height: cc.cellHeight
        sourceComponent: cc.body
    }

    readonly property Component body: {
        switch (controlType) {
        case "wifi": return wifiBody
        case "bluetooth": return bluetoothBody
        case "focus": return focusBody
        case "gameMode": return gameBody
        case "lock": return lockBody
        case "nightLight": return nightLightBody
        case "idleInhibit": return idleInhibitBody
        case "battery": return batteryBody
        case "sound": return soundBody
        case "display": return displayBody
        }
        return null
    }

    readonly property Component wifiBody: CcPill {
        id: pWifi
        panel: cc.panel
        active: Wifi.enabled && Wifi.connected
        icon: Wifi.enabled && Wifi.connected
            ? (Wifi.strength >= 75 ? "wifi"
             : Wifi.strength >= 40 ? "wifi_2_bar" : "wifi_1_bar")
            : "wifi_off"
        label: "Wi-Fi"
        sublabel: Wifi.enabled ? (Wifi.connected ? Wifi.ssid : "Not connected") : "Off"
        onClicked: {
            Wifi.refreshStatus(); Wifi.scan()
            cc.drillRequested("wifi", pWifi.originInRoot())
        }
    }
    readonly property Component bluetoothBody: CcPill {
        id: pBluetooth
        panel: cc.panel
        active: Bluetooth.enabled
        icon: Bluetooth.enabled
            ? (Bluetooth.connectedName ? "bluetooth_connected" : "bluetooth")
            : "bluetooth_disabled"
        label: "Bluetooth"
        sublabel: {
            if (!Bluetooth.enabled) return "Off"
            if (Bluetooth.connectedName) return Bluetooth.connectedName
            return "On"
        }
        onClicked: {
            Bluetooth.refresh(); Bluetooth.scan()
            cc.drillRequested("bluetooth", pBluetooth.originInRoot())
        }
    }
    readonly property Component focusBody: CcPill {
        active: Notifications.dnd
        icon: "do_not_disturb_on"
        label: "Focus"
        sublabel: Notifications.dnd ? "On" : "Off"
        onClicked: Notifications.dnd = !Notifications.dnd
    }
    readonly property Component gameBody: CcPill {
        id: pGame
        panel: cc.panel
        property bool on: false
        active: on
        icon: "toggle_off"
        label: "Game Mode"
        sublabel: on ? "On" : "Off"
        onClicked: {
            on = !on
            if (on) PowerProfile.setProfile("performance")
            else PowerProfile.setProfile("balanced")
        }
    }
    readonly property Component lockBody: CcIconButton {
        width: 60; height: 60
        icon: "lock"
        onClicked: { Quickshell.execDetached(["hyprlock"]); UiState.closeAll() }
    }
    readonly property Component nightLightBody: CcIconButton {
        width: 60; height: 60
        icon: NightLight.enabled ? "dark_mode" : "nightlight"
        active: NightLight.enabled
        onClicked: NightLight.toggle()
    }
    readonly property Component idleInhibitBody: CcIconButton {
        width: 60; height: 60
        icon: "coffee"
        active: IdleInhibit.active
        onClicked: IdleInhibit.toggle()
    }
    readonly property Component batteryBody: CcIconButton {
        width: 60; height: 60
        icon: Battery.charging ? "battery_charging_full" : "battery_std"
        active: Battery.available
        onClicked: {}
    }
    readonly property Component soundBody: CcSliderCard {
        id: scSound
        panel: cc.panel
        cardLabel: "Sound"
        sliderIcon: Volume.muted ? "volume_off"
            : (Volume.volumePercent > 50 ? "volume_up" : "volume_down")
        sliderValue: Volume.muted ? 0 : Volume.volumePercent / 100
        onSliderMoved: (f) => Volume.setVolume(f * 100)
        onSliderScrolled: (delta) =>
            Volume.setVolume(Math.max(0, Math.min(100, Volume.volumePercent + delta * 5)))
        onChevronClicked: cc.drillRequested("sound", scSound.originInRoot())
        chevronVisible: true
    }
    readonly property Component displayBody: CcSliderCard {
        id: scDisplay
        panel: cc.panel
        cardLabel: "Display"


        sliderIcon: "wb_sunny"
        sliderValue: Math.max(0.04, Brightness.level / 100)
        onSliderMoved: (f) => Brightness.setBrightness(Math.round(f * 100))
        onSliderScrolled: (delta) => Brightness.step(delta * 5)
        onChevronClicked: cc.drillRequested("display", scDisplay.originInRoot())
        chevronVisible: true
    }
    Rectangle {
        id: notifGrid
        visible: cc.controlType === "notifications"
        width: cc.width
        height: cc.height
        radius: 14
        color: ccColors.bgCard
        border.color: ccColors.borderColor
        border.width: 1

        ColumnLayout {
            id: notifGridInner
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: "Notifications"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: ccColors.textMedium
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    visible: Notifications.active.length > 0
                    text: "Clear all"
                    font.pixelSize: 12
                    color: Theme.colors.accent
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Notifications.clearAll() }
                }
            }

            StyledText {
                visible: Notifications.active.length === 0
                text: "No notifications"
                font.pixelSize: 13
                color: ccColors.textGhost
            }


            Item {
                id: notifListBox
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(notifGridList.implicitHeight,
                                                  ConfigStore.notifHistoryHeight)
                visible: Notifications.active.length > 0

                Flickable {
                    id: notifFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: notifGridList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: notifGridList
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: Notifications.active
                            delegate: CcNotifRow {
                                required property var modelData
                                Layout.fillWidth: true
                                notif: modelData
                                onDismissed: Notifications.dismiss(modelData.id)
                            }
                        }
                    }
                }

                SubtleScroll {
                    flickable: notifFlick
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
            }
        }
    }
}
