import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../components"
import "../services"
import "settings"

// ControlCenter — matches Reference images exactly with SOLID premium dark backgrounds.
// Home: Wi-Fi, Focus, Lock, Bluetooth, Game Mode, Night Light,
//       Sound slider, Display slider, Notifications panel.
// Sub-views: Bluetooth (Connected, Saved, Nearby), Display (per-monitor), Wi-Fi.

Surface {
    id: root

    focus: UiState.controlCenterOpen
    Keys.onEscapePressed: root.view = "home"

    readonly property color accent: Theme.colors.accent
    readonly property color accentText: Theme.colors.accentText

    // Solid palette — shared with every other surface via Solid.qml so the
    // panel chrome has a single definition.
    readonly property color bgSurface: Solid.bgSurface
    readonly property color bgCard: Solid.bgCard
    readonly property color bgCardHover: Solid.bgCardHover
    readonly property color bgCardActive: Solid.bgCardActive
    readonly property color bgItem: Solid.bgItem
    readonly property color bgItemHover: Solid.bgItemHover
    readonly property color bgSliderTrack: Solid.bgSliderTrack

    width: 460
    cornerRadius: Solid.radiusPanel
    backgroundColor: root.bgSurface
    borderColor: Solid.borderSubtle
    borderWidth: 1
    shadow: true

    // ── Wi-Fi password flow ──────────────────────────────────────
    // Tries a plain connect first (covers networks NetworkManager
    // already has saved credentials for); only prompts for a
    // password if that attempt specifically fails because one is
    // needed. See WifiPasswordDialog.qml — it existed already but
    // was never wired to anything, so secured networks could never
    // actually be joined from this UI.
    property string pendingWifiSsid: ""
    property string pendingWifiError: ""
    property bool pendingWifiConnecting: false

    function attemptWifiConnect(ssid, secured) {
        root.pendingWifiConnecting = false
        Wifi.connectWireless(ssid, "", null, (result) => {
            if (result.success) return
            if (result.needsPassword || secured) {
                root.pendingWifiSsid = ssid
                root.pendingWifiError = ""
            }
        })
    }

    function submitWifiPassword(password) {
        if (!root.pendingWifiSsid) return
        root.pendingWifiConnecting = true
        Wifi.connectWireless(root.pendingWifiSsid, password, null, (result) => {
            root.pendingWifiConnecting = false
            if (result.success) {
                root.pendingWifiSsid = ""
                root.pendingWifiError = ""
            } else {
                root.pendingWifiError = result.needsPassword
                    ? "Incorrect password — try again."
                    : "Couldn't connect. Try again."
            }
        })
    }

    // ── Navigation state ─────────────────────────────────────────
    property string view: "home"

    // Reset to home whenever CC is closed
    Connections {
        target: UiState
        function onControlCenterOpenChanged() {
            if (!UiState.controlCenterOpen) root.view = "home"
        }
    }

    // ── Implicit height follows active sub-view ──────────────────
    implicitHeight: {
        if (view === "bluetooth") return btPage.implicitHeight + 28
        if (view === "display")   return dispPage.implicitHeight + 28
        if (view === "wifi")      return wifiPage.implicitHeight + 28
        return homePage.implicitHeight + 28
    }
    Behavior on implicitHeight {
        enabled: !MotionConfig.reduceMotion
        SpringAnimation { spring: 4.2; damping: MotionConfig.springDamping; mass: 0.85 }
    }

    // ═══════════════════════════════════════════════════════════════
    // HOME PAGE  (Reference 1)
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: homePage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        spacing: 10
        visible: root.view === "home"

        // ── Row 1: Wi-Fi · Focus · Lock ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // ── Wi-Fi pill ──────────────────────────────────────
            CcPill {
                Layout.fillWidth: true
                active: Wifi.enabled && Wifi.connected
                icon: Wifi.enabled && Wifi.connected
                    ? (Wifi.strength >= 75 ? "wifi"
                     : Wifi.strength >= 40 ? "wifi_2_bar" : "wifi_1_bar")
                    : "wifi_off"
                label: "Wi-Fi"
                sublabel: Wifi.enabled ? (Wifi.connected ? Wifi.ssid : "Not connected") : "Off"
                onClicked: {
                    Wifi.refreshStatus(); Wifi.scan()
                    root.view = "wifi"
                }
            }

            // ── Focus / DND pill ────────────────────────────────
            CcPill {
                Layout.preferredWidth: 130
                active: Notifications.dnd
                icon: "do_not_disturb_on"
                label: "Focus"
                sublabel: Notifications.dnd ? "On" : "Off"
                onClicked: Notifications.dnd = !Notifications.dnd
            }

            // ── Lock icon button ────────────────────────────────
            CcIconBtn {
                icon: "lock"
                onClicked: {
                    Quickshell.execDetached(["hyprlock"])
                    UiState.closeAll()
                }
            }
        }

        // ── Row 2: Bluetooth · Game Mode · Night Light ──────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // ── Bluetooth pill ──────────────────────────────────
            CcPill {
                Layout.fillWidth: true
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
                    root.view = "bluetooth"
                }
            }

            // ── Game Mode pill ──────────────────────────────────
            CcPill {
                id: gamePill
                Layout.preferredWidth: 130
                property bool on: false
                active: on
                icon: "sports_esports"
                label: "Game Mode"
                sublabel: on ? "On" : "Off"
                onClicked: {
                    on = !on
                    if (on) PowerProfile.setProfile("performance")
                    else PowerProfile.setProfile("balanced")
                }
            }

            // ── Night Light icon button ─────────────────────────
            CcIconBtn {
                icon: NightLight.enabled ? "dark_mode" : "nightlight"
                active: NightLight.enabled
                onClicked: NightLight.toggle()
            }
        }

        // ── Sound slider card ────────────────────────────────────
        SliderCard {
            Layout.fillWidth: true
            cardLabel: "Sound"
            sliderIcon: Volume.muted ? "volume_off" : (Volume.volumePercent > 50 ? "volume_up" : "volume_down")
            sliderValue: Volume.muted ? 0 : Volume.volumePercent / 100
            onSliderMoved: (f) => Volume.setVolume(f * 100)
            onSliderScrolled: (delta) => Volume.setVolume(Math.max(0, Math.min(100, Volume.volumePercent + delta * 5)))
            chevronVisible: false
        }

        // ── Display slider card ──────────────────────────────────
        SliderCard {
            Layout.fillWidth: true
            cardLabel: "Display"
            sliderIcon: "brightness_5"
            sliderValue: Math.max(0.04, Brightness.level / 100)
            onSliderMoved: (f) => Brightness.setBrightness(Math.round(f * 100))
            onSliderScrolled: (delta) => Brightness.step(delta * 5)
            onChevronClicked: root.view = "display"
            chevronVisible: true
        }

        // ── Notifications panel ──────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(70, notifInner.implicitHeight + 28)
            radius: 16
            color: root.bgCard
            border.color: "#282828"
            border.width: 1

            ColumnLayout {
                id: notifInner
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                spacing: 8

                // ── Header row ──────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "Notifications"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: "#999999"
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        visible: Notifications.active.length > 0
                        text: "Clear all"
                        font.pixelSize: 12
                        color: root.accent
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Notifications.clearAll() }
                    }
                }

                // ── Empty state ──────────────────────────────────
                StyledText {
                    visible: Notifications.active.length === 0
                    text: "No notifications"
                    font.pixelSize: 13
                    color: "#555555"
                }

                // ── Notification list ────────────────────────────
                // Capped at `notifHistoryHeight` and scrollable beyond
                // that, rather than growing (and pushing everything
                // below it down) without limit.
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(notifListInner.implicitHeight, ConfigStore.notifHistoryHeight)
                    visible: Notifications.active.length > 0
                    contentWidth: width
                    contentHeight: notifListInner.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: notifListInner
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: Notifications.active
                            delegate: NotifRow {
                                required property var modelData
                                Layout.fillWidth: true
                                notif: modelData
                                onDismissed: Notifications.dismiss(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════════
    // BLUETOOTH PAGE  (Reference 2)
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: btPage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        spacing: 0
        visible: root.view === "bluetooth"

        // ── Sticky mini-header ───────────────────────────────────
        MiniHeader {
            Layout.fillWidth: true
            onBack: root.view = "home"
        }

        Item { Layout.preferredHeight: 12 }

        // ── Bluetooth title row ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            IconButton {
                icon: "arrow_back"
                size: 32
                iconSize: 16
                iconColor: "#CCCCCC"
                onClicked: root.view = "home"
            }

            StyledText {
                text: "Bluetooth"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: "#FFFFFF"
            }

            Item { Layout.fillWidth: true }

            Toggle {
                checked: Bluetooth.enabled
                accentColor: root.accent
                onToggled: Bluetooth.toggle()
            }
        }

        Item { Layout.preferredHeight: 14 }

        // ── Connected devices ─────────────────────────────────────
        Item {
            id: btConnectedWrap
            Layout.fillWidth: true
            implicitHeight: btConnectedCol.implicitHeight
            visible: Bluetooth.devices.filter(d => d.connected).length > 0

            ColumnLayout {
                id: btConnectedCol
                width: parent.width
                spacing: 6

                SectionLabel { text: "Connected" }

                Repeater {
                    model: Bluetooth.devices.filter(d => d.connected)
                    BtDeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        device: modelData
                        onConnect: Bluetooth.connectDevice(modelData.mac)
                        onDisconnect: Bluetooth.disconnectDevice(modelData.mac)
                        onPair: Bluetooth.pair(modelData.mac)
                    }
                }
            }
        }

        Item { Layout.preferredHeight: btConnectedWrap.visible ? 12 : 0 }

        // ── Saved / Paired ───────────────────────────────────────
        Item {
            id: btSavedWrap
            Layout.fillWidth: true
            implicitHeight: btSavedCol.implicitHeight
            visible: Bluetooth.devices.filter(d => d.paired && !d.connected).length > 0

            ColumnLayout {
                id: btSavedCol
                width: parent.width
                spacing: 6

                SectionLabel { text: "Saved" }

                Repeater {
                    model: Bluetooth.devices.filter(d => d.paired && !d.connected)
                    BtDeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        device: modelData
                        onConnect: Bluetooth.connectDevice(modelData.mac)
                        onDisconnect: Bluetooth.disconnectDevice(modelData.mac)
                        onPair: Bluetooth.pair(modelData.mac)
                    }
                }
            }
        }

        Item { Layout.preferredHeight: btSavedWrap.visible ? 12 : 0 }

        // ── Nearby ───────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Bluetooth.enabled

            RowLayout {
                Layout.fillWidth: true
                SectionLabel { text: "Nearby" }
                Item { Layout.fillWidth: true }
                RowLayout {
                    spacing: 6
                    visible: Bluetooth.scanning
                    Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: root.accent }
                    StyledText { text: "Scanning"; font.pixelSize: 11; color: "#888888" }
                }
            }

            Repeater {
                model: Bluetooth.devices.filter(d => !d.paired)
                BtDeviceRow {
                    required property var modelData
                    Layout.fillWidth: true
                    device: modelData
                    onConnect: Bluetooth.connectDevice(modelData.mac)
                    onDisconnect: Bluetooth.disconnectDevice(modelData.mac)
                    onPair: Bluetooth.pair(modelData.mac)
                }
            }
        }

        Item { Layout.preferredHeight: 4 }
    }


    // ═══════════════════════════════════════════════════════════════
    // DISPLAY PAGE  (Reference 3)
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: dispPage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        spacing: 0
        visible: root.view === "display"

        // ── Sticky mini-header ───────────────────────────────────
        MiniHeader {
            Layout.fillWidth: true
            onBack: root.view = "home"
        }

        Item { Layout.preferredHeight: 12 }

        // ── Display title row ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            IconButton {
                icon: "arrow_back"
                size: 32
                iconSize: 16
                iconColor: "#CCCCCC"
                onClicked: root.view = "home"
            }

            StyledText {
                text: "Display"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: "#FFFFFF"
            }

            Item { Layout.fillWidth: true }
        }

        Item { Layout.preferredHeight: 14 }

        // ── Per-monitor brightness cards ──────────────────────────
        Repeater {
            model: Brightness.monitors
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10

                MonitorCard {
                    Layout.fillWidth: true
                    monitorModel: modelData
                }

                Item { Layout.preferredHeight: 4 }
            }
        }

        // ── Night Light solid card ────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 14
            color: root.bgCard
            border.color: "#282828"
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 10
                    color: NightLight.enabled ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : "#2c2c2c"

                    Icon {
                        anchors.centerIn: parent
                        icon: "nightlight"
                        size: 18
                        iconColor: NightLight.enabled ? root.accent : "#AAAAAA"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText { text: "Night Light"; font.pixelSize: 13; font.weight: Font.Medium; color: "#FFFFFF" }
                    StyledText { text: NightLight.enabled ? "On" : "Off"; font.pixelSize: 11; color: "#777777" }
                }

                Toggle {
                    checked: NightLight.enabled
                    accentColor: root.accent
                    onToggled: NightLight.toggle()
                }
            }
        }

        Item { Layout.preferredHeight: 4 }
    }


    // ═══════════════════════════════════════════════════════════════
    // WIFI PAGE (Solid cards list)
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: wifiPage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        spacing: 0
        visible: root.view === "wifi"

        MiniHeader {
            Layout.fillWidth: true
            onBack: root.view = "home"
        }

        Item { Layout.preferredHeight: 12 }

        RowLayout {
            Layout.fillWidth: true
            IconButton {
                icon: "arrow_back"; size: 32; iconSize: 16; iconColor: "#CCCCCC"
                onClicked: root.view = "home"
            }
            StyledText { text: "Wi-Fi"; font.pixelSize: 17; font.weight: Font.DemiBold; color: "#FFFFFF" }
            Item { Layout.fillWidth: true }
            Toggle {
                checked: Wifi.enabled
                accentColor: root.accent
                onToggled: Wifi.toggle()
            }
        }

        Item { Layout.preferredHeight: 14 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Wifi.networks
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 48
                    radius: 12
                    color: modelData.active ? root.bgCardActive : (wifiRowHover.hovered ? root.bgItemHover : root.bgItem)
                    border.color: modelData.active ? root.accent : "#2c2c2c"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                    HoverHandler { id: wifiRowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.attemptWifiConnect(modelData.ssid, modelData.secured) }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        Icon { icon: "wifi"; size: 16; iconColor: modelData.active ? root.accent : "#AAAAAA" }
                        StyledText { Layout.fillWidth: true; text: modelData.ssid; font.pixelSize: 13; color: "#FFFFFF"; elide: Text.ElideRight }
                        StyledText { text: modelData.strength + "%"; font.pixelSize: 11; color: "#888888" }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 6 }
    }

    // ── Wi-Fi password overlay ────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: root.pendingWifiSsid.length > 0
        z: 1000

        Scrim {
            anchors.fill: parent
            dismissOnClick: true
            onDismissed: {
                root.pendingWifiSsid = ""
                root.pendingWifiError = ""
            }
        }

        WifiPasswordDialog {
            id: pwDialog
            anchors.centerIn: parent
            connecting: root.pendingWifiConnecting
            onSubmitted: (password) => root.submitWifiPassword(password)
            onCancelled: {
                root.pendingWifiSsid = ""
                root.pendingWifiError = ""
            }
        }
    }

    // open()/re-open() are imperative (they also reset the typed
    // password + refocus the field) so ssid/errorText are driven
    // from here rather than as plain property bindings on
    // WifiPasswordDialog — a declarative binding on a property that
    // open() also assigns to would just get silently dropped after
    // the first call.
    onPendingWifiSsidChanged: {
        if (pendingWifiSsid.length > 0) pwDialog.open(pendingWifiSsid, pendingWifiError)
    }
    onPendingWifiErrorChanged: {
        if (pendingWifiSsid.length > 0 && pendingWifiError.length > 0) pwDialog.open(pendingWifiSsid, pendingWifiError)
    }


    // ═══════════════════════════════════════════════════════════════
    // PRIVATE SOLID COMPONENTS
    // ═══════════════════════════════════════════════════════════════

    // ── CcPill — solid pill toggle ────────────────────────────────
    component CcPill: Rectangle {
        id: pill
        height: 58
        radius: 16
        property bool active: false
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        signal clicked()

        color: active
            ? root.bgCardActive
            : (pillHover.hovered ? root.bgCardHover : root.bgCard)
        border.color: active ? root.accent : "#282828"
        border.width: 1
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

        scale: pillTap.pressed ? 0.97 : 1.0
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

        HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: pillTap; onTapped: pill.clicked() }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 11
                color: pill.active ? root.accent : "#2a2a2a"
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                Icon {
                    anchors.centerIn: parent
                    icon: pill.icon
                    size: 19
                    iconColor: pill.active ? root.accentText : "#DDDDDD"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    text: pill.label
                    font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF"
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                StyledText {
                    text: pill.sublabel
                    font.pixelSize: 11; color: "#888888"
                    elide: Text.ElideRight; Layout.fillWidth: true
                    visible: text.length > 0
                }
            }
        }
    }

    // ── CcIconBtn — solid small button (Lock, Night Light) ────────
    component CcIconBtn: Rectangle {
        id: iconBtn
        width: 58; height: 58; radius: 16
        property string icon: ""
        property bool active: false
        signal clicked()

        color: active
            ? root.bgCardActive
            : (iconBtnHover.hovered ? root.bgCardHover : root.bgCard)
        border.color: active ? root.accent : "#282828"
        border.width: 1
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

        scale: iconBtnTap.pressed ? 0.95 : 1.0
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

        HoverHandler { id: iconBtnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: iconBtnTap; onTapped: iconBtn.clicked() }

        Icon {
            anchors.centerIn: parent
            icon: iconBtn.icon
            size: 20
            iconColor: iconBtn.active ? root.accent : "#DDDDDD"
        }
    }

    // ── SliderCard — solid Sound / Display slider card ────────────
    component SliderCard: Rectangle {
        id: sc
        height: 78; radius: 16
        color: root.bgCard
        border.color: "#282828"
        border.width: 1

        property string cardLabel: ""
        property string sliderIcon: ""
        property real sliderValue: 0.5
        property bool chevronVisible: false
        signal sliderMoved(real fraction)
        signal sliderScrolled(int delta)
        signal chevronClicked()

        ColumnLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                StyledText { text: sc.cardLabel; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                Item { Layout.fillWidth: true }
                Icon {
                    visible: sc.chevronVisible
                    icon: "chevron_right"; size: 16; iconColor: "#888888"
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sc.chevronClicked() }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.bgSliderTrack
                    clip: true

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, sc.sliderValue)))
                        radius: parent.radius
                        color: root.accent
                        Behavior on width {
                            enabled: !sliderMouse.pressed && !MotionConfig.reduceMotion
                            SpringAnimation { spring: 3.6; damping: MotionConfig.springDamping; mass: 0.9 }
                        }
                    }

                    Icon {
                        anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                        icon: sc.sliderIcon; size: 16; iconColor: "#111111"
                    }
                }

                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function set(mx) {
                        sc.sliderMoved(Math.max(0, Math.min(1, mx / width)))
                    }
                    onPressed: (e) => set(e.x)
                    onPositionChanged: (e) => { if (pressed) set(e.x) }
                    onWheel: (e) => sc.sliderScrolled(e.angleDelta.y > 0 ? 1 : -1)
                }
            }
        }
    }

    // ── MiniHeader — solid mini bar for sub-pages ─────────────────
    component MiniHeader: RowLayout {
        spacing: 8
        signal back()

        Rectangle {
            Layout.preferredWidth: 140; Layout.preferredHeight: 40; radius: 12
            color: root.bgCard
            border.color: "#282828"
            border.width: 1
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                spacing: 8
                Rectangle {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 8
                    color: (Wifi.enabled && Wifi.connected) ? root.accent : "#2c2c2c"
                    Icon {
                        anchors.centerIn: parent; icon: "wifi"; size: 14
                        iconColor: (Wifi.enabled && Wifi.connected) ? root.accentText : "#AAAAAA"
                    }
                }
                StyledText {
                    text: Wifi.connected ? Wifi.ssid : "Wi-Fi"
                    font.pixelSize: 11; color: "#DDDDDD"; elide: Text.ElideRight; Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12
            color: root.bgCard
            border.color: "#282828"
            border.width: 1
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                spacing: 8
                Rectangle {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 8
                    color: Notifications.dnd ? root.accent : "#2c2c2c"
                    Icon {
                        anchors.centerIn: parent; icon: "do_not_disturb_on"; size: 14
                        iconColor: Notifications.dnd ? root.accentText : "#AAAAAA"
                    }
                }
                StyledText { text: "Focus"; font.pixelSize: 11; color: "#DDDDDD" }
            }
        }

        Rectangle {
            Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 12
            color: root.bgCard
            border.color: "#282828"
            border.width: 1
            Icon { anchors.centerIn: parent; icon: "lock"; size: 15; iconColor: "#AAAAAA" }
        }
    }

    // ── SectionLabel ──────────────────────────────────────────────
    component SectionLabel: StyledText {
        font.pixelSize: 12
        font.weight: Font.Medium
        color: "#888888"
    }

    // ── BtDeviceRow — solid Bluetooth row ─────────────────────────
    component BtDeviceRow: Rectangle {
        id: bdr
        height: 54; radius: 13
        property var device: ({})
        signal connect()
        signal disconnect()
        signal pair()

        color: bdrHover.hovered ? root.bgItemHover : root.bgItem
        border.color: bdr.device.connected ? root.accent : "#282828"
        border.width: 1
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
        HoverHandler { id: bdrHover }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 10
                color: bdr.device.connected ? root.accent : "#2e2e2e"
                Icon {
                    anchors.centerIn: parent
                    icon: bdr.device.connected ? "headphones" : "bluetooth"
                    size: 18
                    iconColor: bdr.device.connected ? root.accentText : "#AAAAAA"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    text: bdr.device.name || bdr.device.mac
                    font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF"
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                StyledText {
                    text: bdr.device.connected ? "Connected" : (bdr.device.paired ? "Saved" : "Not paired")
                    font.pixelSize: 11; color: bdr.device.connected ? root.accent : "#777777"
                }
            }

            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: actionLabel.implicitWidth + 22
                radius: 8
                color: bdr.device.connected ? "#2a2a2a" : root.accent

                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        if (bdr.device.connected) bdr.disconnect()
                        else if (bdr.device.paired) bdr.connect()
                        else bdr.pair()
                    }
                }

                StyledText {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: bdr.device.connected ? "Disconnect"
                        : (bdr.device.paired ? "Connect" : "Pair")
                    font.pixelSize: 12; font.weight: Font.DemiBold
                    color: bdr.device.connected ? "#DDDDDD" : root.accentText
                }
            }
        }
    }

    // ── NotifRow — solid notification card ────────────────────────
    component NotifRow: Rectangle {
        id: nr
        height: 64; radius: 12
        property var notif: ({})
        signal dismissed()

        color: root.bgItem
        border.color: "#282828"
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                StyledText {
                    anchors.centerIn: parent
                    text: (nr.notif.appName || "?").charAt(0).toUpperCase()
                    font.pixelSize: 14; font.weight: Font.Bold; color: root.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText { text: nr.notif.appName || ""; font.pixelSize: 10; color: "#777777" }
                StyledText { text: nr.notif.summary || ""; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF"; elide: Text.ElideRight; Layout.fillWidth: true }
                StyledText { text: nr.notif.body || ""; font.pixelSize: 11; color: "#888888"; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 1 }
            }

            Item {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                HoverHandler { id: xHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: nr.dismissed() }
                Icon { anchors.centerIn: parent; icon: "close"; size: 14; iconColor: "#777777" }
            }
        }
    }

    // ── MonitorCard — solid per-display brightness + scale card ───
    component MonitorCard: Rectangle {
        id: mc
        radius: 16
        property var monitorModel: null
        implicitHeight: mcCol.implicitHeight + 24
        color: root.bgCard
        border.color: "#282828"
        border.width: 1

        readonly property real brightness: monitorModel ? monitorModel.brightness : 0
        readonly property string monName: monitorModel ? monitorModel.modelData.name : ""
        readonly property string monDesc: monitorModel ? (
            monitorModel.modelData.width + "×" + monitorModel.modelData.height +
            "  ·  " + Math.round(monitorModel.modelData.refreshRate) + " Hz"
        ) : ""

        ColumnLayout {
            id: mcCol
            anchors { fill: parent; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 10
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                    Icon { anchors.centerIn: parent; icon: "monitor"; size: 18; iconColor: root.accent }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText { text: mc.monName; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                    StyledText { text: mc.monDesc; font.pixelSize: 11; color: "#777777" }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.bgSliderTrack
                    clip: true

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, mc.brightness)))
                        radius: parent.radius
                        color: root.accent
                        Behavior on width {
                            enabled: !brightMouse.pressed && !MotionConfig.reduceMotion
                            SpringAnimation { spring: 3.6; damping: MotionConfig.springDamping; mass: 0.9 }
                        }
                    }

                    Icon {
                        anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                        icon: "brightness_5"; size: 16; iconColor: "#111111"
                    }

                    StyledText {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: Math.round(mc.brightness * 100) + "%"
                        font.pixelSize: 11
                        color: mc.brightness > 0.5 ? "#111111" : "#FFFFFF"
                    }
                }

                MouseArea {
                    id: brightMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function set(mx) {
                        if (mc.monitorModel)
                            mc.monitorModel.setBrightness(Math.max(0.01, Math.min(1, mx / width)))
                    }
                    onPressed: (e) => set(e.x)
                    onPositionChanged: (e) => { if (pressed) set(e.x) }
                    onWheel: (e) => {
                        if (mc.monitorModel)
                            mc.monitorModel.setBrightness(mc.brightness + (e.angleDelta.y > 0 ? 0.05 : -0.05))
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [1.0, 1.25, 1.5, 1.75, 2.0]

                    Rectangle {
                        required property real modelData
                        readonly property bool selected: mc.monitorModel &&
                            Math.abs(mc.monitorModel.modelData.scale - modelData) < 0.05
                        height: 30
                        width: scaleLabel.implicitWidth + 20
                        radius: 8
                        color: selected ? root.accent : root.bgItem
                        border.color: selected ? root.accent : "#2c2c2c"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                Quickshell.execDetached([
                                    "hyprctl", "keyword", "monitor",
                                    mc.monName + ",preferred,auto," + modelData
                                ])
                            }
                        }

                        StyledText {
                            id: scaleLabel
                            anchors.centerIn: parent
                            text: modelData + "x"
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: selected ? root.accentText : "#AAAAAA"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38; radius: 10
                color: root.bgItem
                border.color: "#282828"
                border.width: 1
                HoverHandler { cursorShape: Qt.PointingHandCursor }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    StyledText { text: "Resolution"; font.pixelSize: 12; color: "#AAAAAA" }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: mc.monitorModel
                            ? (mc.monitorModel.modelData.width + "×" +
                               mc.monitorModel.modelData.height + " @ " +
                               Math.round(mc.monitorModel.modelData.refreshRate) + " Hz")
                            : ""
                        font.pixelSize: 12; color: "#888888"
                    }
                    Icon { icon: "chevron_right"; size: 14; iconColor: "#666666" }
                }
            }
        }
    }
}