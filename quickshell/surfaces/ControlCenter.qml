import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
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

    // Solid palette. Values sampled from the reference screenshot: the panel
    // and the Sound/Display cards are the same warm near-black and are told
    // apart only by their hairline border, and the unfilled part of a slider
    // is markedly DARKER than the card it sits in, not lighter.
    readonly property color bgSurface: "#181614"
    readonly property color bgCard: "#181614"
    readonly property color bgCardHover: "#282828"
    readonly property color bgCardActive: "#24332c"
    readonly property color bgItem: "#272221"
    readonly property color bgItemHover: "#2e2e2e"
    readonly property color bgSliderTrack: "#0d0b0a"

    width: 460
    // Surface is an Item, so implicitHeight alone does not size it. Without
    // this the panel kept a fixed height and clipped the drill-down.
    height: implicitHeight
    cornerRadius: 24
    backgroundColor: root.bgSurface
    borderColor: "#262626"
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

    // ── Connected network readout ────────────────────────────────
    // The joined-network card shows the security type and signal beside the
    // SSID. Wifi.strength is the connected network's own signal, but the
    // security string only exists on the `networks` row that nmcli polling
    // produced — Wifi._syncState() rewrites that list with a
    // {ssid, strength, secured, active} shape and drops it. So the segment is
    // omitted when it is genuinely not exposed instead of being guessed at.
    readonly property var activeNetwork: {
        const nets = Wifi.networks || []
        // Prefer the active row matching the connected SSID; fall back to any
        // active row in case nmcli reported a different SSID casing.
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].active && nets[i].ssid === Wifi.ssid) return nets[i]
        }
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].active) return nets[i]
        }
        return null
    }

    readonly property string activeSecurity: {
        const s = root.activeNetwork && root.activeNetwork.security
            ? String(root.activeNetwork.security).trim()
            : ""
        // nmcli prints "--" for an open network.
        if (!s || s === "--" || s === "NONE") return ""
        return s
    }

    readonly property string activeMeta: {
        const parts = ["Connected"]
        if (root.activeSecurity.length > 0) parts.push(root.activeSecurity)
        if (Wifi.strength > 0) parts.push(Wifi.strength + "% signal")
        return parts.join(" · ")
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

    // ── Fixed height ─────────────────────────────────────────────
    // The panel does NOT resize per view. It used to derive its height from
    // the active page and spring between sizes, which made it visibly
    // readjust every time a page loaded its async content (Bluetooth scan,
    // PipeWire enumeration) and left it stuck at the wrong size when that
    // content arrived late.
    //
    // A constant height means the drill-downs all open into the same box.
    // Long lists scroll inside it rather than growing the panel.
    readonly property int panelHeight: 460
    implicitHeight: panelHeight


    // ═══════════════════════════════════════════════════════════════
    // HOME PAGE  (Reference 1)
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: homePage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        spacing: 10
        // Stays visible while a drill-down is open: the reference keeps the
        // first pill row showing above the inset card, which then covers the
        // rest of the home.
        visible: true

        // ── Row 1: Wi-Fi · Focus · Lock ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

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
                // Equal width to the Wi-Fi pill: the reference lays out two
                // identical pills plus the circular button. A fixed 130 here
                // made Focus visibly narrower than its neighbour.
                Layout.fillWidth: true
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
            spacing: 10

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
                Layout.fillWidth: true
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
            onChevronClicked: root.view = "sound"
            chevronVisible: true
        }

        // ── Display slider card ──────────────────────────────────
        SliderCard {
            Layout.fillWidth: true
            cardLabel: "Display"
            sliderIcon: "brightness_7"
            sliderValue: Math.max(0.04, Brightness.level / 100)
            onSliderMoved: (f) => Brightness.setBrightness(Math.round(f * 100))
            onSliderScrolled: (delta) => Brightness.step(delta * 5)
            onChevronClicked: root.view = "display"
            chevronVisible: true
        }

        // ── Notifications panel ──────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            // The reference keeps a tall, fixed notifications area with
            // slack below the last card, so the overall panel keeps its
            // proportions whether or not anything has arrived. Minimum 176
            // rather than the old 70.
            Layout.preferredHeight: Math.max(176, notifInner.implicitHeight + 28)
            radius: 14
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


    // ── Drill-down card ────────────────────────────────────────────
    // The sub-pages are inset cards that float over the home page rather
    // than replacing it, matching the reference: the home's first pill row
    // stays visible above and the panel edges show either side. Declared
    // after homePage and before the sub-pages, so it paints over the home
    // and under the sub-page content.
    Rectangle {
        id: drillCard
        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        // Matches whichever page is open, so the card is exactly the page's
        // box. Both hang off the panel's bottom edge and grow upward in
        // proportion to content: a short page sits low, a tall one reaches
        // higher.
        height: root.view === "bluetooth" ? btPage.height
               : root.view === "display"   ? dispPage.height
               : root.view === "wifi"      ? wifiPage.height
               : root.view === "sound"     ? soundPage.height
               : 0
        y: root.panelHeight - 14 - height
        radius: 18
        color: root.bgSurface
        border.color: "#282828"
        border.width: 1
        visible: root.view !== "home"
    }

    // ═══════════════════════════════════════════════════════════════
    // BLUETOOTH PAGE  (Reference 2)
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: btPage
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        // Bottom-anchored: the popover hangs off the panel's bottom edge
        // and grows upward in proportion to its content, so a short page
        // sits low and a tall one reaches higher.
        height: Math.min(implicitHeight, root.panelHeight - 14)
        y: root.panelHeight - 14 - height
        spacing: 0
        visible: root.view === "bluetooth"


        Item { Layout.preferredHeight: 12 }

        // ── Sticky mini-header ───────────────────────────────────
        SubPageHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            toggleVisible: true
            toggleOn: Bluetooth.enabled
            onBack: root.view = "home"
            onToggled: { Bluetooth.toggle(); Bluetooth.refresh(); }
        }

        Item { Layout.preferredHeight: 12 }

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
                    CcBtRow {
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
                    CcBtRow {
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
                CcBtRow {
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
    // SOUND PAGE  (Reference 4)
    //
    // Output / Input / Apps, mirroring the reference. Device rows are
    // circular-badge + name, with the active one carrying an accent badge
    // and a check on the right. The page did not exist before: the Sound
    // card had no chevron because there was nowhere to go.
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: soundPage
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        // Bottom-anchored: the popover hangs off the panel's bottom edge
        // and grows upward in proportion to its content, so a short page
        // sits low and a tall one reaches higher.
        height: Math.min(implicitHeight, root.panelHeight - 14)
        y: root.panelHeight - 14 - height
        spacing: 0
        visible: root.view === "sound"


        Item { Layout.preferredHeight: 12 }

        // ── Sticky mini-header ───────────────────────────────────
        SubPageHeader {
            Layout.fillWidth: true
            title: "Sound"
            onBack: root.view = "home"
        }

        Item { Layout.preferredHeight: 10 }

        // ── Output ───────────────────────────────────────────────
        StyledText {
            text: "Output"
            font.pixelSize: 11
            color: "#777777"
        }
        Item { Layout.preferredHeight: 6 }

        Repeater {
            model: Volume.sinks
            delegate: CcDeviceRow {
                required property var modelData
                Layout.fillWidth: true
                label: Volume.displayName(modelData)
                icon: "speaker"
                selected: Volume.isDefaultSink(modelData)
                onPicked: Volume.setDefaultSink(modelData)
            }
        }

        Item { Layout.preferredHeight: 8 }

        // Output volume
        CcDeviceSlider {
            Layout.fillWidth: true
            icon: Volume.muted ? "volume_off" : "volume_up"
            value: Volume.muted ? 0 : Volume.volumePercent
            onMoved: (f) => Volume.setVolume(f * 100)
        }

        Item { Layout.preferredHeight: 12 }

        // ── Input ────────────────────────────────────────────────
        StyledText {
            text: "Input"
            font.pixelSize: 11
            color: "#777777"
        }
        Item { Layout.preferredHeight: 6 }

        Repeater {
            model: Volume.sources
            delegate: CcDeviceRow {
                required property var modelData
                Layout.fillWidth: true
                label: Volume.displayName(modelData)
                icon: "mic"
                selected: Volume.isDefaultSource(modelData)
                onPicked: Volume.setDefaultSource(modelData)
            }
        }

        Item { Layout.preferredHeight: 8 }

        // Input volume
        CcDeviceSlider {
            Layout.fillWidth: true
            icon: Volume.micMuted ? "mic_off" : "mic"
            value: Volume.micMuted ? 0 : Volume.micVolumePercent
            onMoved: (f) => Volume.setMicVolume(f * 100)
        }

        Item { Layout.preferredHeight: 12 }

        // ── Apps ─────────────────────────────────────────────────
        StyledText {
            text: "Apps"
            font.pixelSize: 11
            color: "#777777"
            visible: Volume.streams.length > 0
        }
        Item { Layout.preferredHeight: 6; visible: Volume.streams.length > 0 }

        Repeater {
            model: Volume.streams
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: Volume.displayName(modelData)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: "#DDDDDD"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Per-app stream volume. The node is tracked in the service
                // (PwObjectTracker) so this stays live.
                CcDeviceSlider {
                    Layout.fillWidth: true
                    icon: "volume_up"
                    value: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
                    onMoved: (f) => {
                        if (!modelData.audio) return;
                        modelData.audio.muted = false;
                        modelData.audio.volume = Math.max(0, Math.min(1, f));
                    }
                }
            }
        }

        // No PipeWire, or nothing enumerated yet.
        StyledText {
            Layout.fillWidth: true
            visible: Volume.sinks.length === 0 && Volume.sources.length === 0
            text: Pipewire.ready ? "No audio devices found" : "Waiting for PipeWire…"
            font.pixelSize: 12
            color: "#777777"
            horizontalAlignment: Text.AlignHCenter
        }

        Item { Layout.preferredHeight: 4 }
    }


    // ═══════════════════════════════════════════════════════════════
    // DISPLAY PAGE  (Reference 3)
    // ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        id: dispPage
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        // Bottom-anchored: the popover hangs off the panel's bottom edge
        // and grows upward in proportion to its content, so a short page
        // sits low and a tall one reaches higher.
        height: Math.min(implicitHeight, root.panelHeight - 14)
        y: root.panelHeight - 14 - height
        spacing: 0
        visible: root.view === "display"


        Item { Layout.preferredHeight: 12 }

        // ── Sticky mini-header ───────────────────────────────────
        SubPageHeader {
            Layout.fillWidth: true
            title: "Display"
            onBack: root.view = "home"
        }

        Item { Layout.preferredHeight: 12 }

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
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        // Bottom-anchored: the popover hangs off the panel's bottom edge
        // and grows upward in proportion to its content, so a short page
        // sits low and a tall one reaches higher.
        height: Math.min(implicitHeight, root.panelHeight - 14)
        y: root.panelHeight - 14 - height
        spacing: 0
        visible: root.view === "wifi"


        Item { Layout.preferredHeight: 12 }

        SubPageHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            toggleVisible: true
            toggleOn: Wifi.enabled
            onBack: root.view = "home"
            onToggled: Wifi.toggle()
        }

        Item { Layout.preferredHeight: 12 }

        Item { Layout.preferredHeight: 14 }

        // ── Connected network ──────────────────────────────────────
        // The joined network gets its own card rather than sitting at the top
        // of a flat list: accent badge + SSID + "Connected · WPA2 · 78%
        // signal" readout, with a BORDERED Disconnect pill on the right.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 13
            color: root.bgItem
            border.color: root.accent
            border.width: 1
            visible: Wifi.connected

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: width / 2
                    color: root.accent

                    Icon {
                        anchors.centerIn: parent
                        icon: "wifi"
                        size: 20
                        iconColor: root.accentText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: Wifi.ssid
                        font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF"
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    StyledText {
                        text: root.activeMeta
                        font.pixelSize: 11; color: "#777777"
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }

                // Hairline pill, not a filled button — the reference's
                // Disconnect is accent text inside a rounded outline.
                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: wifiDisconnectLabel.implicitWidth + 24
                    radius: height / 2
                    color: "transparent"
                    border.color: "#282828"
                    border.width: 1
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { Wifi.disconnect() } }

                    StyledText {
                        id: wifiDisconnectLabel
                        anchors.centerIn: parent
                        text: "Disconnect"
                        font.pixelSize: 11
                        color: root.accent
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 14 }

        // ── Networks header ────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText { text: "Networks"; font.pixelSize: 11; color: "#777777" }
            Item { Layout.fillWidth: true }
            RowLayout {
                spacing: 6
                visible: Wifi.scanning
                Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: root.accent }
                StyledText { text: "Scanning"; font.pixelSize: 11; color: "#777777" }
            }
        }

        Item { Layout.preferredHeight: 6 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                // The joined network lives in the card above, so it is not
                // repeated in this list.
                model: Wifi.networks.filter(n => !n.active)
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 48
                    radius: 12
                    color: wifiRowHover.hovered ? root.bgItemHover : root.bgItem
                    border.color: "#2c2c2c"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                    HoverHandler { id: wifiRowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.attemptWifiConnect(modelData.ssid, modelData.secured) }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        Icon { icon: "wifi"; size: 16; iconColor: "#AAAAAA" }
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
        height: 52
        radius: 15
        property bool active: false
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        signal clicked()

        // Every pill is the same near-black in the reference — the active
        // state is carried by the circular icon badge, not by tinting the
        // whole pill. (CcIconBtn below keeps its accent fill, because the
        // reference's active moon button really is a solid accent circle.)
        color: pillHover.hovered ? root.bgCardHover : root.bgCard
        border.color: "#282828"
        border.width: 1
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

        scale: pillTap.pressed ? 0.97 : 1.0
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

        HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: pillTap; onTapped: pill.clicked() }

        RowLayout {
            anchors { fill: parent; leftMargin: 9; rightMargin: 11 }
            spacing: 9

            // Circular icon badge — measured off the reference at 36px with a
            // symmetric width taper, so a circle, not a rounded square.
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: width / 2
                color: pill.active ? root.accent : "#2a2a2a"
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                Icon {
                    anchors.centerIn: parent
                    icon: pill.icon
                    size: 18
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
        // Circular, 52px — the reference's lock/moon buttons measure 52px
        // across with the same symmetric taper as the badges.
        width: 52; height: 52; radius: width / 2
        property string icon: ""
        property bool active: false
        signal clicked()

        color: active
            ? root.bgCardActive
            : (iconBtnHover.hovered ? root.bgCardHover : root.bgCard)
        border.color: "#282828"
        border.width: 1
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

        scale: iconBtnTap.pressed ? 0.95 : 1.0
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 } }

        HoverHandler { id: iconBtnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: iconBtnTap; onTapped: iconBtn.clicked() }

        Icon {
            anchors.centerIn: parent
            icon: iconBtn.icon
            size: 19
            iconColor: iconBtn.active ? root.accent : "#DDDDDD"
        }
    }

    // ── SubPageHeader — back chevron + title (+ optional toggle) ──
    // The reference sub-pages open with a "< Title" bar; the Wi-Fi and
    // Bluetooth pages also carry a toggle on the right. This replaces
    // MiniHeader, which was a hardcoded wifi/focus/lock status strip
    // rather than a title bar, so sub-pages had no title at all.
    component SubPageHeader: RowLayout {
        id: sph
        property string title: ""
        property string icon: ""
        property bool toggleVisible: false
        property bool toggleOn: false
        signal back()
        signal toggled()

        spacing: 10

        // Back
        Rectangle {
            id: backBtn
            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: width / 2
            color: backHover.hovered ? root.bgItemHover : root.bgItem
            border.color: "#282828"
            border.width: 1
            HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: sph.back() }
            Icon {
                anchors.centerIn: parent
                icon: "chevron_left"
                size: 18
                iconColor: "#DDDDDD"
            }
        }

        StyledText {
            text: sph.title
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: "#FFFFFF"
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Toggle {
            visible: sph.toggleVisible
            checked: sph.toggleOn
            onToggled: sph.toggled()
        }
    }

    // ── CcDeviceRow — one selectable audio device ────────────────
    // Circular badge + name, with the active device getting the accent
    // badge and a check on the right.
    component CcDeviceRow: Rectangle {
        id: devRow
        property string label: ""
        property string icon: "speaker"
        property bool selected: false
        signal picked()

        Layout.preferredHeight: 40
        radius: 12
        color: devHover.hovered ? root.bgItemHover : root.bgItem
        border.color: "#282828"
        border.width: 1

        HoverHandler { id: devHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: devRow.picked() }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: width / 2
                color: devRow.selected ? root.accent : "#2c2c2c"
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                Icon {
                    anchors.centerIn: parent
                    icon: devRow.icon
                    size: 14
                    iconColor: devRow.selected ? root.accentText : "#AAAAAA"
                }
            }

            StyledText {
                text: devRow.label
                font.pixelSize: 12
                color: "#FFFFFF"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Icon {
                visible: devRow.selected
                icon: "check"
                size: 15
                iconColor: root.accent
            }
        }
    }

    // ── CcDeviceSlider — slider with a leading glyph and a % readout ─
    component CcDeviceSlider: Rectangle {
        id: devSlider
        property string icon: "volume_up"
        property real value: 0
        signal moved(real fraction)

        Layout.preferredHeight: 32
        radius: 12
        color: root.bgItem
        border.color: "#282828"
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
            spacing: 10

            Icon {
                icon: devSlider.icon
                size: 15
                iconColor: "#DDDDDD"
            }

            // Track
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 14

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.bgSliderTrack

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: Math.max(0, Math.min(1, devSlider.value / 100)) * parent.width
                        radius: parent.radius
                        color: root.accent
                        Behavior on width {
                            enabled: !devMouse.pressed && !MotionConfig.reduceMotion
                            SpringAnimation { spring: 3.6; damping: MotionConfig.springDamping; mass: 0.9 }
                        }
                    }
                }

                MouseArea {
                    id: devMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function set(mx) { devSlider.moved(Math.max(0, Math.min(1, mx / width))); }
                    onPressed: (e) => set(e.x)
                    onPositionChanged: (e) => { if (pressed) set(e.x); }
                    onWheel: (e) => e.accept()
                }
            }

            StyledText {
                text: Math.round(devSlider.value) + "%"
                font.pixelSize: 11
                color: "#999999"
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ── SliderCard — solid Sound / Display slider card ────────────
    component SliderCard: Rectangle {
        id: sc
        // Reference cards measure 52px tall with a 23px slider bar inside.
        height: 52; radius: 14
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
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 7; bottomMargin: 7 }
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                StyledText { text: sc.cardLabel; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                Item { Layout.fillWidth: true }
                Icon {
                    visible: sc.chevronVisible
                    icon: "chevron_right"; size: 15; iconColor: "#888888"
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sc.chevronClicked() }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 23

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
                        icon: sc.sliderIcon; size: 14; iconColor: "#111111"
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

    // ── CcBtRow — solid two-line Bluetooth row ───────────────────
    // The reference row is a circular badge, a two-line block (name over
    // state) and a PLAIN-TEXT action in the accent colour — not a filled
    // button. Shared by the Connected / Saved / Nearby sections rather than
    // inlined three times.
    component CcBtRow: Rectangle {
        id: cbr
        property var device: ({})
        signal connect()
        signal disconnect()
        signal pair()

        Layout.preferredHeight: 46
        radius: 12
        color: cbrHover.hovered ? root.bgItemHover : root.bgItem
        border.color: cbr.device.connected ? root.accent : "#282828"
        border.width: 1
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

        HoverHandler { id: cbrHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (cbr.device.connected) cbr.disconnect()
                else if (cbr.device.paired) cbr.connect()
                else cbr.pair()
            }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: width / 2
                color: cbr.device.connected ? root.accent : "#2c2c2c"
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                Icon {
                    anchors.centerIn: parent
                    // A paired device is (in the reference) audio; an
                    // unpaired one only ever has the bluetooth rune.
                    icon: cbr.device.paired ? "headphones" : "bluetooth"
                    size: 15
                    iconColor: cbr.device.connected ? root.accentText : "#AAAAAA"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    text: cbr.device.name || cbr.device.mac
                    font.pixelSize: 12; color: "#FFFFFF"
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                StyledText {
                    text: cbr.device.connected ? "Connected" : (cbr.device.paired ? "Saved" : "Not paired")
                    font.pixelSize: 11; color: "#777777"
                }
            }

            // Text action, deliberately not a button: the reference draws no
            // background or border behind it.
            StyledText {
                text: cbr.device.connected ? "Disconnect" : (cbr.device.paired ? "Connect" : "Pair")
                font.pixelSize: 11
                color: root.accent
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

        // There is no Hyprland focused-output feed wired into this config, so
        // "focused" is the service's own active monitor — getMonitor("active")
        // is what global brightness changes, the OSD and BrightnessMonitor's
        // own activity check all resolve to. Matched by output name, which is
        // how Brightness.getMonitor() identifies monitors itself.
        readonly property var activeMonitor: Brightness.getMonitor("active")
        readonly property bool focused: !!monitorModel && !!activeMonitor
            && activeMonitor.modelData.name === monitorModel.modelData.name

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

                StyledText {
                    visible: mc.focused
                    text: "focused"
                    font.pixelSize: 10
                    color: root.accent
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