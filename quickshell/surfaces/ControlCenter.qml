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

    // Sampled off the Display/Sound drill-down captures. The drill-downs
    // nest one level deeper than the home page does: a #181614 popover
    // inset inside the black panel, holding #272221 cards. The home page
    // puts its cards straight on the panel, which is why bgCard is left
    // as it was.
    readonly property color bgBadgeDim: "#413a37"
    readonly property color bgPill: "#342e29"
    // The track inside a #272221 card reads a shade lighter than the one
    // on the home page's #181614 cards; the home page value is untouched.
    readonly property color bgSliderTrackCard: "#141211"
    // Text tones, sampled rather than guessed.
    readonly property color textDim: "#7a7a7a"
    readonly property color textFaint: "#8a8a8a"

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

    // Two-way with UiState.ccView, so the drill-down can be opened without a
    // click. Reads back on every change so the two cannot drift.
    onViewChanged: if (UiState.ccView !== root.view) UiState.ccView = root.view
    Connections {
        target: UiState
        function onCcViewChanged() {
            if (UiState.ccView !== root.view) root.view = UiState.ccView;
        }
    }
    Component.onCompleted: root.view = UiState.ccView

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
    //
    // 514, matching Island.qml's rightDotWrap width. See the note there: the
    // reference panel is x 703..1216 by y 53..566, square at 514, inset 14px
    // inside. The "484 square" previously recorded here was the inner card,
    // measured on both axes.
    // The reference's panel is square on the home page and TALLER on the two
    // content-heavy drill-downs, so the height is a function of the open view
    // rather than one constant. Measured off 1:1 crops of the same session:
    //   home     514  (2026-09-20_22-27-14.png, x 703..1216, y 53..566)
    //   display  564  (2026-09-20_22-26-57.png)
    //   sound    719  (2026-09-20_22-26-47.png)
    //
    // This is still deterministic: it depends only on which view is open, so
    // it cannot drift as content arrives, which is what the fixed-height
    // requirement was guarding against. Wi-Fi and Bluetooth keep the home
    // height because no reference capture of them exists in the batch.
    // The drill-down box, identical for every sub-page: from the bottom of
    // the home's first pill row down to the panel's bottom inset.
    //
    // It used to be bottom-anchored with a content-dependent height --
    // baseY was `panelHeight - 14 - height`, and each page's height came from
    // its own content -- so every page sat at a different height and the
    // card's top edge cut through the home wherever it happened to land. The
    // visible symptoms were a Bluetooth pill sliced in half behind the Wi-Fi
    // card, and the Sound card filling the panel edge to edge with "Apps"
    // cut off. One fixed box for all four pages also stops them each picking
    // a different height for the panel itself.
    // Whichever sub-page is showing, for the shared scroll indicator.
    readonly property Flickable activeFlick:
        view === "bluetooth" ? btFlick
        : view === "display"   ? dispFlick
        : view === "wifi"      ? wifiFlick
        : view === "sound"     ? soundFlick
        : null

    readonly property real drillTop: homePage.y + homePage.firstRowBottom
    readonly property real drillHeight: Math.max(140, root.panelHeight - 14 - root.drillTop)

    readonly property int panelHeight:
        view === "display" ? 564
        : view === "sound"   ? 719
        : 514
    implicitHeight: panelHeight

    // True while a sub-page is open. The drill card hides by collapsing its
    // height to 0 rather than by setting visible, so its reveal needs this
    // instead of `visible`.
    readonly property bool drillOpen: view !== "home"

    // Where a drill-down grows out of, in root coordinates. The Wi-Fi and
    // Bluetooth cells set this to their own centre when clicked, so the
    // popover unfolds from the cell you actually pressed. Defaults to the
    // middle of the panel, for when a page is opened without a cell.
    property point popoverOrigin: Qt.point(width / 2, 150)


    // ═══════════════════════════════════════════════════════════════
    // HOME PAGE  (Reference 1) -- laid out from ControlCenterLayout
    // ═══════════════════════════════════════════════════════════════
    //
    // This was a hand-written ColumnLayout: two fixed rows of pills, then
    // Sound, Display and Notifications, in that order, with no notion of a
    // position or a size. That cannot express what the Control Center arranger
    // (settings/pages/ControlCenterArranger.qml) edits, so the arranger was a
    // mock. The home now reads the same model the arranger writes.
    //
    // Rows are not a uniform height -- the reference's own numbers are 57 for a
    // pill, 60 for a disc and 52 for a slider card -- so each grid row takes
    // the tallest control that lands in it. Controls are absolutely positioned
    // rather than laid out by a Layout, because a placed control's cell is a
    // function of its col/row/colSpan, not of its neighbours.
    Item {
        id: homePage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }

        readonly property var layoutItems: ControlCenterLayout.items
        readonly property int cols: ControlCenterLayout.columns

        // A control's own column pitch, so cells land where the arranger's
        // grid says they do.
        readonly property real cellW: (width - (cols - 1) * 10) / cols
        // A function, not a property: `property real colX: (c) => ...` binds a
        // number to a function object, and every call then fails with
        // "Property 'colX' of object QQuickItem is not a function".
        function colX(c) { return c * (cellW + 10) }

        // Row tops, accumulated from each row's tallest control.
        //
        // A function rather than a `readonly property var` holding the array:
        // during initialisation that property is undefined, and every delegate
        // binding that read rowTops[row] threw "Cannot read property '4' of
        // undefined" before the array was ever built.
        function rowTops() {
            const tops = []
            let y = 0
            for (let r = 0; r < 64; r++) {
                tops.push(y)
                let tallest = 0
                for (const it of ControlCenterLayout.items) {
                    if (it.row !== r) continue
                    const h = rowHeightFor(it)
                    if (h > tallest) tallest = h
                }
                if (tallest === 0) break
                y += tallest + 10
            }
            return tops
        }

        function rowTop(r) {
            const t = rowTops()
            return t[r] !== undefined ? t[r] : 0
        }

        // Bottom of the first pill row, in homePage coordinates. The
        // drill-down card starts exactly here, so row 0 stays whole above it
        // instead of having its neighbour sliced in half.
        readonly property real firstRowBottom: {
            const t = rowTops()
            if (t.length < 2) return Math.min(height, 70)
            return t[1] - 5
        }

        // The height a single placed control wants, in px. Kept in step with
        // CcControl.cellHeight by construction -- both switch on the same list.
        function rowHeightFor(it) {
            switch (it.type) {
            case "lock": case "nightLight": case "idleInhibit": case "battery":
                return 60
            case "sound": case "display":
                return 52
            case "notifications":
                return homePage.notifHomeHeight
            default:
                return 57
            }
        }

        // Notifications keeps the reference's slack below the last card so the
        // panel keeps its proportions whether or not anything has arrived.
        readonly property int notifHomeHeight: Math.max(
            176, 14 * 2 + 8 * 2 + (Notifications.active.length > 0
                ? Math.min(64 * Notifications.active.length, ConfigStore.notifHistoryHeight)
                : 18))

        Repeater {
            model: homePage.layoutItems

            delegate: CcControl {
                id: placed
                required property var modelData

                readonly property real w: homePage.colX(modelData.colSpan) - 10
                readonly property real yTop: homePage.rowTop(modelData.row)

                controlType: modelData.type
                x: homePage.colX(modelData.col)
                y: yTop
                width: w
                height: placed.cellHeight

                onDrillRequested: (view, origin) => {
                    if (origin) root.popoverOrigin = origin;
                    root.view = view;
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
        // Set explicitly rather than by anchors, so x stays writable and the
        // reveal below can slide the box onto the clicked cell. Geometry is
        // identical to the anchors this replaces.
        // Match the inset of whichever page is open. Display and Sound are
        // 22px-inset sheets, Wi-Fi and Bluetooth are 10px; the card was 10px
        // for all four, so on Display and Sound the sheet sat on a card 24px
        // wider than itself, with 12px of bare card showing either side.
        readonly property real inset:
            (root.view === "display" || root.view === "sound") ? 22 : 10
        readonly property real baseX: parent.x + inset
        readonly property real baseY: root.drillTop
        width: parent.width - inset * 2
        // The same box the pages use, so the card is always exactly the
        // page's bounds and cannot drift off a page whose content resizes.
        height: root.drillHeight
        y: baseY + (1 - scale) * pivot.y


        // Grow out of the cell that was clicked.
        //
        // The pivot is done arithmetically because this Qt build exposes no
        // pixel transform origin: there is no transformOriginX/Y, no callable
        // setTransformOrigin(), and `transforms` is not assignable. Handing
        // transformOrigin an Item is no help either -- measured against a
        // forced scale of 0.5, the box still pivots on its own centre rather
        // than on the cell. So the origin is pinned to the top-left and the
        // pivot is applied by hand: scaling about a point P is identical to
        // scaling about (0,0) and then translating by (1 - scale) * P, and
        // that translation is folded into x and y.
        readonly property point pivot: Qt.point(
            Math.max(0, Math.min(width,  root.popoverOrigin.x - baseX)),
            Math.max(0, Math.min(height, root.popoverOrigin.y - baseY)))
        x: baseX + (1 - scale) * pivot.x
        transformOrigin: Item.TopLeft
        scale: root.drillOpen ? 1 : 0.82
        opacity: root.drillOpen ? 1 : 0
        Behavior on scale {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 6.5; damping: MotionConfig.springDamping; mass: 0.75 }
        }
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        radius: 18
        color: root.bgSurface
        border.color: "#282828"
        border.width: 1
        visible: root.view !== "home"
    }

    // ═══════════════════════════════════════════════════════════════
    // BLUETOOTH PAGE  (Reference 2)
    // ═══════════════════════════════════════════════════════════════
    Flickable {
        id: btFlick
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        // Set explicitly rather than by anchors, so x stays writable and the
        // reveal below can slide the box onto the clicked cell. Geometry is
        // identical to the anchors this replaces.
        readonly property real baseX: parent.x + 10
        readonly property real baseY: root.drillTop
        width: parent.width - 20
        // The shared drill-down box, not a content-derived one. The page
        // content still scrolls inside it, so a list taller than the box is
        // reachable rather than silently clipped.
        height: root.drillHeight
        y: baseY + (1 - scale) * pivot.y
        contentWidth: width
        contentHeight: btFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Nothing to scroll when the content fits: no travel, no grab.
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "bluetooth"

        // Grow out of the cell that was clicked.
        //
        // The pivot is done arithmetically because this Qt build exposes no
        // pixel transform origin: there is no transformOriginX/Y, no callable
        // setTransformOrigin(), and `transforms` is not assignable. Handing
        // transformOrigin an Item is no help either -- measured against a
        // forced scale of 0.5, the box still pivots on its own centre rather
        // than on the cell. So the origin is pinned to the top-left and the
        // pivot is applied by hand: scaling about a point P is identical to
        // scaling about (0,0) and then translating by (1 - scale) * P, and
        // that translation is folded into x and y.
        readonly property point pivot: Qt.point(
            Math.max(0, Math.min(width,  root.popoverOrigin.x - baseX)),
            Math.max(0, Math.min(height, root.popoverOrigin.y - baseY)))
        x: baseX + (1 - scale) * pivot.x
        transformOrigin: Item.TopLeft
        scale: btFlick.visible ? 1 : 0.82
        opacity: btFlick.visible ? 1 : 0
        Behavior on scale {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 6.5; damping: MotionConfig.springDamping; mass: 0.75 }
        }
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: btFlickContent
            width: btFlick.width
            spacing: 0
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
    }


    // ═══════════════════════════════════════════════════════════════
    // SOUND PAGE  (Reference 4)
    //
    // Output / Input / Apps, mirroring the reference. Device rows are
    // circular-badge + name, with the active one carrying an accent badge
    // and a check on the right. The page did not exist before: the Sound
    // card had no chevron because there was nowhere to go.
    // ═══════════════════════════════════════════════════════════════
    Flickable {
        id: soundFlick
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        // Set explicitly rather than by anchors, so x stays writable and the
        // reveal below can slide the box onto the clicked cell. Geometry is
        // identical to the anchors this replaces.
        // Same 22px inset sheet as the Display page — see dispFlick.
        readonly property real baseX: parent.x + 22
        readonly property real baseY: root.drillTop
        width: parent.width - 44
        // The shared drill-down box, not a content-derived one; the content
        // still scrolls inside it.
        height: root.drillHeight
        y: baseY + (1 - scale) * pivot.y
        contentWidth: width
        contentHeight: soundFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Nothing to scroll when the content fits: no travel, no grab.
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "sound"

        // Grow out of the cell that was clicked.
        //
        // The pivot is done arithmetically because this Qt build exposes no
        // pixel transform origin: there is no transformOriginX/Y, no callable
        // setTransformOrigin(), and `transforms` is not assignable. Handing
        // transformOrigin an Item is no help either -- measured against a
        // forced scale of 0.5, the box still pivots on its own centre rather
        // than on the cell. So the origin is pinned to the top-left and the
        // pivot is applied by hand: scaling about a point P is identical to
        // scaling about (0,0) and then translating by (1 - scale) * P, and
        // that translation is folded into x and y.
        readonly property point pivot: Qt.point(
            Math.max(0, Math.min(width,  root.popoverOrigin.x - baseX)),
            Math.max(0, Math.min(height, root.popoverOrigin.y - baseY)))
        x: baseX + (1 - scale) * pivot.x
        transformOrigin: Item.TopLeft
        scale: soundFlick.visible ? 1 : 0.82
        opacity: soundFlick.visible ? 1 : 0
        Behavior on scale {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 6.5; damping: MotionConfig.springDamping; mass: 0.75 }
        }
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.bgSurface
        }

        ColumnLayout {
            id: soundFlickContent
            width: soundFlick.width
            spacing: 0
            Item { Layout.preferredHeight: 12 }

            // ── Sticky mini-header ───────────────────────────────────
            SubPageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                title: "Sound"
                onBack: root.view = "home"
            }

            Item { Layout.preferredHeight: 8 }

            // ── Output ───────────────────────────────────────────────
            // The reference sets each group in from the sheet's edge by 14px
            // and breathes 5px between device rows; this ran them together
            // and hard against the edge.
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                text: "Output"
                font.pixelSize: 11
                color: root.textDim
            }
            Item { Layout.preferredHeight: 6 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                spacing: 5

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
            }

            Item { Layout.preferredHeight: 8 }

            // Output volume
            CcDeviceSlider {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                icon: Volume.muted ? "volume_off" : "volume_up"
                value: Volume.muted ? 0 : Volume.volumePercent
                onMoved: (f) => Volume.setVolume(f * 100)
            }

            Item { Layout.preferredHeight: 12 }

            // ── Input ────────────────────────────────────────────────
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                text: "Input"
                font.pixelSize: 11
                color: root.textDim
            }
            Item { Layout.preferredHeight: 6 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                spacing: 5

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
            }

            Item { Layout.preferredHeight: 8 }

            // Input volume
            CcDeviceSlider {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                icon: Volume.micMuted ? "mic_off" : "mic"
                value: Volume.micMuted ? 0 : Volume.micVolumePercent
                onMoved: (f) => Volume.setMicVolume(f * 100)
            }

            Item { Layout.preferredHeight: 12 }

            // ── Apps ─────────────────────────────────────────────────
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                text: "Apps"
                font.pixelSize: 11
                color: root.textDim
                visible: Volume.streams.length > 0
            }
            Item { Layout.preferredHeight: 6; visible: Volume.streams.length > 0 }

            // Each stream is a card like every other row in this page, with
            // its name above its own slider. This used to be bare text on
            // the sheet, so the app list read as a different surface.
            Repeater {
                model: Volume.streams
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.preferredHeight: streamCol.implicitHeight + 16
                    Layout.topMargin: 5
                    radius: 13
                    color: root.bgItem
                    border.color: "#282828"
                    border.width: 1

                    ColumnLayout {
                        id: streamCol
                        anchors { fill: parent; margins: 8 }
                        spacing: 6

                        StyledText {
                            text: Volume.displayName(modelData)
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Per-app stream volume. The node is tracked in the
                        // service (PwObjectTracker) so this stays live.
                        CcDeviceSlider {
                            Layout.fillWidth: true
                            onCard: true
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
    }


    // ═══════════════════════════════════════════════════════════════
    // DISPLAY PAGE  (Reference 3)
    // ═══════════════════════════════════════════════════════════════
    Flickable {
        id: dispFlick
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        // Set explicitly rather than by anchors, so x stays writable and the
        // reveal below can slide the box onto the clicked cell. Geometry is
        // identical to the anchors this replaces.
        // The reference drill-down is a #181614 sheet inset 22px inside the
        // black panel on all four sides -- measured off the Display crop,
        // where the panel's own edges fall at x 380.40 / 894.74 and the
        // sheet's at 402.58 / 872.67. It used to be flush to the panel
        // with only a 10px horizontal inset and no sheet behind it at all,
        // so the cards read as floating directly on black.
        readonly property real baseX: parent.x + 22
        readonly property real baseY: root.drillTop
        width: parent.width - 44
        // The shared drill-down box, not a content-derived one; the content
        // still scrolls inside it.
        height: root.drillHeight
        y: baseY + (1 - scale) * pivot.y
        contentWidth: width
        contentHeight: dispFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Nothing to scroll when the content fits: no travel, no grab.
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "display"

        onVisibleChanged: {
            if (visible) Brightness.refreshMonitorInfo()
        }

        // Grow out of the cell that was clicked.
        //
        // The pivot is done arithmetically because this Qt build exposes no
        // pixel transform origin: there is no transformOriginX/Y, no callable
        // setTransformOrigin(), and `transforms` is not assignable. Handing
        // transformOrigin an Item is no help either -- measured against a
        // forced scale of 0.5, the box still pivots on its own centre rather
        // than on the cell. So the origin is pinned to the top-left and the
        // pivot is applied by hand: scaling about a point P is identical to
        // scaling about (0,0) and then translating by (1 - scale) * P, and
        // that translation is folded into x and y.
        readonly property point pivot: Qt.point(
            Math.max(0, Math.min(width,  root.popoverOrigin.x - baseX)),
            Math.max(0, Math.min(height, root.popoverOrigin.y - baseY)))
        x: baseX + (1 - scale) * pivot.x
        transformOrigin: Item.TopLeft
        scale: dispFlick.visible ? 1 : 0.82
        opacity: dispFlick.visible ? 1 : 0
        Behavior on scale {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 6.5; damping: MotionConfig.springDamping; mass: 0.75 }
        }
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.bgSurface
        }

        ColumnLayout {
            id: dispFlickContent
            width: dispFlick.width
            spacing: 0
            Item { Layout.preferredHeight: 12 }

            // ── Sticky mini-header ───────────────────────────────────
            SubPageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                title: "Display"
                onBack: root.view = "home"
            }

            Item { Layout.preferredHeight: 12 }

            // ── Per-monitor brightness cards ──────────────────────────
            // 15px in from the sheet, 13px between cards: the reference's
            // nesting. The sheet's own edges are 22px inside the panel and
            // the cards' 15px inside that, which is what makes the measured
            // card 440px wide (514 - 2*22 - 2*15).
            Repeater {
                model: Brightness.monitors
                MonitorCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.topMargin: 12
                    monitorModel: modelData
                }
            }

            // ── Night Light card ──────────────────────────────────────
            //
            // The reference reads the live colour temperature under the
            // label ("3700 K"), not a bare "On"/"Off", and carries a second
            // moon slider underneath the toggle. This used to stop at the
            // switch, so the page showed "Off" and nothing to drag.
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                Layout.topMargin: 12
                Layout.preferredHeight: nlCol.implicitHeight + 20
                radius: 15
                color: root.bgItem
                border.width: 0

                ColumnLayout {
                    id: nlCol
                    anchors { fill: parent; margins: 10 }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            // 30, matching the per-monitor badge: the
                            // reference's Night Light disc measures 30x30.
                            Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                            color: NightLight.enabled ? root.accent : root.bgBadgeDim
                            Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                            Icon {
                                anchors.centerIn: parent
                                icon: "nightlight"
                                size: 15
                                iconColor: NightLight.enabled ? root.accentText : "#CCCCCC"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            StyledText { text: "Night Light"; font.pixelSize: 13; font.weight: Font.Medium; color: "#FFFFFF" }
                            StyledText {
                                text: NightLight.enabled
                                    ? Math.round(NightLight.nightTemperature) + " K"
                                    : "Off"
                                font.pixelSize: 12
                                color: root.textDim
                            }
                        }

                        // 42 x 21 is already the reference's size: the
                        // switch measures 41 x 22 as a solid teal shape in
                        // the Display capture, so it is left alone.
                        Toggle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 21
                            checked: NightLight.enabled
                            accentColor: root.accent
                            // The reference knob is a black hole in the
                            // accent pill, not a white one.
                            thumbColor: "#000000"
                            onToggled: NightLight.toggle()
                        }
                    }

                    // 1000..6500K, i.e. hyprsunset's identity (6500K) at
                    // the warm end. The reference does not say what range
                    // its own slider spans, so this is the defensible one
                    // rather than a fitted guess.
                    CcDeviceSlider {
                        Layout.fillWidth: true
                        visible: NightLight.enabled
                        onCard: true
                        // Same crescent as the badge above it — the reference
                        // uses one glyph in both places.
                        icon: "nightlight"
                        value: Math.max(0, Math.min(100,
                            (NightLight.nightTemperature - 1000) / 55))
                        onMoved: (f) => NightLight.setTemperature(
                            Math.round(1000 + f * 5500))
                    }
                }
            }

            Item { Layout.preferredHeight: 14 }
        }
    }


    // ═══════════════════════════════════════════════════════════════
    // WIFI PAGE (Solid cards list)
    // ═══════════════════════════════════════════════════════════════
    Flickable {
        id: wifiFlick
        // Inset overlay card, not a full-page replacement: the reference keeps
        // the home visible behind the drill-down, starting below its first
        // pill row.
        // Set explicitly rather than by anchors, so x stays writable and the
        // reveal below can slide the box onto the clicked cell. Geometry is
        // identical to the anchors this replaces.
        readonly property real baseX: parent.x + 10
        readonly property real baseY: root.drillTop
        width: parent.width - 20
        // The shared drill-down box, not a content-derived one. The page
        // content still scrolls inside it, so a list taller than the box is
        // reachable rather than silently clipped.
        height: root.drillHeight
        y: baseY + (1 - scale) * pivot.y
        contentWidth: width
        contentHeight: wifiFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Nothing to scroll when the content fits: no travel, no grab.
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "wifi"

        // Grow out of the cell that was clicked.
        //
        // The pivot is done arithmetically because this Qt build exposes no
        // pixel transform origin: there is no transformOriginX/Y, no callable
        // setTransformOrigin(), and `transforms` is not assignable. Handing
        // transformOrigin an Item is no help either -- measured against a
        // forced scale of 0.5, the box still pivots on its own centre rather
        // than on the cell. So the origin is pinned to the top-left and the
        // pivot is applied by hand: scaling about a point P is identical to
        // scaling about (0,0) and then translating by (1 - scale) * P, and
        // that translation is folded into x and y.
        readonly property point pivot: Qt.point(
            Math.max(0, Math.min(width,  root.popoverOrigin.x - baseX)),
            Math.max(0, Math.min(height, root.popoverOrigin.y - baseY)))
        x: baseX + (1 - scale) * pivot.x
        transformOrigin: Item.TopLeft
        scale: wifiFlick.visible ? 1 : 0.82
        opacity: wifiFlick.visible ? 1 : 0
        Behavior on scale {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 6.5; damping: MotionConfig.springDamping; mass: 0.75 }
        }
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: wifiFlickContent
            width: wifiFlick.width
            spacing: 0
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
        // 57 = the 41px badge plus the reference's 8px of padding above and
        // below it (badge top 76, panel fill top 68).
        height: 57
        radius: 16
        property bool active: false
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        signal clicked()

        // This cell's centre in root coordinates, so a drill-down opened from
        // here can animate out of exactly this cell.
        function originInRoot() {
            return mapToItem(root, width / 2, height / 2);
        }

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

            // Circular icon badge. 41px, measured off the reference by taking
            // the tight bounding box of the solid teal circle inside the Wi-Fi
            // pill: x 727..767, y 76..116. The old 36 came from a comment that
            // claimed it was measured and was not. Symmetric width taper, so a
            // circle, not a rounded square.
            Rectangle {
                Layout.preferredWidth: 41
                Layout.preferredHeight: 41
                radius: width / 2
                color: pill.active ? root.accent : "#2a2a2a"
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                Icon {
                    anchors.centerIn: parent
                    icon: pill.icon
                    size: 20
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
        // Circular, 60px. The reference's moon button is a solid accent circle
        // at x 1143..1202, y 138..196 -- 60x59 -- so it is directly measurable
        // as a bounding box. The old 52 was a carried-over guess.
        width: 60; height: 60; radius: width / 2
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

        spacing: 12

        // Back. The reference's chevron disc is 23px -- measured directly,
        // its #272221 fill spans x 418..440 and y 62..84 in the Display
        // capture -- so this is smaller than the 28 it used to carry, not
        // larger. Scaling the previous value up would have been wrong here.
        Rectangle {
            id: backBtn
            Layout.preferredWidth: 23; Layout.preferredHeight: 23; radius: width / 2
            color: backHover.hovered ? root.bgItemHover : root.bgItem
            border.color: "#282828"
            border.width: 1
            HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: sph.back() }
            Icon {
                anchors.centerIn: parent
                icon: "chevron_left"
                size: 14
                iconColor: "#DDDDDD"
            }
        }

        StyledText {
            text: sph.title
            font.pixelSize: 18
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

        // 40: the reference rows are 41px of #272221 (y 180..220 and
        // 225..265 in the Sound capture), against 39 for the 38 this
        // carried before.
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

            // The reference's unselected badge is a warm #413a37 disc, not
            // the neutral #2c2c2c this used. 29px: the accent disc in the
            // Sound capture measures 29 across.
            Rectangle {
                Layout.preferredWidth: 29
                Layout.preferredHeight: 29
                radius: width / 2
                color: devRow.selected ? root.accent : root.bgBadgeDim
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
                font.pixelSize: 14
                color: "#FFFFFF"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Icon {
                visible: devRow.selected
                icon: "check"
                size: 14
                iconColor: root.accent
            }
        }
    }

    // ── CcDeviceSlider — slider with a leading glyph and a % readout ─
    //
    // The reference draws this as a bare track sitting straight on the
    // popover, with the glyph riding inside the accent fill and the
    // percentage OUTSIDE the track on the right. It used to be a bordered
    // card with a separate glyph column, which read as one more row in the
    // list rather than as the group's volume control.
    component CcDeviceSlider: Rectangle {
        id: devSlider
        property string icon: "volume_up"
        property real value: 0
        // Set when the slider sits on a #272221 card, which needs the
        // slightly lighter track.
        property bool onCard: false
        signal moved(real fraction)

        // 26: the reference's slider tracks are 26px of solid accent fill
        // (y 368..393 and 576..601 in the Sound capture), against 24 here.
        Layout.preferredHeight: 26
        radius: 12
        color: "transparent"
        border.width: 0

        Item {
            id: devTrack
            anchors.left: parent.left
            anchors.right: pct.left
            anchors.rightMargin: 17
            anchors.verticalCenter: parent.verticalCenter
            height: 26

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: devSlider.onCard ? root.bgSliderTrackCard : root.bgSliderTrack

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, devSlider.value / 100)))
                    radius: parent.radius
                    color: root.accent
                    Behavior on width {
                        enabled: !devMouse.pressed && !MotionConfig.reduceMotion
                        SpringAnimation { spring: 3.6; damping: MotionConfig.springDamping; mass: 0.9 }
                    }
                }

                Icon {
                    anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                    icon: devSlider.icon
                    size: 14
                    iconColor: "#111111"
                }
            }

            MouseArea {
                id: devMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function set(mx) { devSlider.moved(Math.max(0, Math.min(1, mx / width))); }
                onPressed: (e) => set(e.x)
                onPositionChanged: (e) => { if (pressed) set(e.x); }
            }
        }

        StyledText {
            id: pct
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(devSlider.value) + "%"
            font.pixelSize: 12
            color: "#999999"
            horizontalAlignment: Text.AlignRight
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

    // ── CcControl — one placed control, dispatched on its type ─────
    //
    // Wraps the existing CcPill / CcIconBtn / SliderCard / notifications
    // block so the home page can be built from ControlCenterLayout's list of
    // {type, col, row, colSpan, rowSpan} instead of a hand-written
    // ColumnLayout. It has to live here rather than in components/ because
    // CcPill, CcIconBtn and SliderCard are inline components scoped to this
    // file.
    //
    // It is the *same* components, not copies: the drill-down origin, the
    // Wi-Fi scan, Volume.setVolume, Brightness.setBrightness and
    // Notifications.dismiss all still run from the originals. The arranger
    // therefore edits the real panel rather than a picture of it.
    component CcControl: Item {
        id: cc

        property string controlType: ""
        // Set by the parent grid so a drill-down opened from here animates out
        // of *this* cell.
        signal drillRequested(string view, point origin)

        // Row height this control asks for, in grid rows. Discs are 60, pills
        // 57, slider cards 52 -- the reference's own numbers, which is why the
        // grid cannot use one uniform row height.
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

        // Discs keep their fixed 60px and centre in whatever cell they land
        // in; everything else stretches to fill its span.
        readonly property bool isDisc: cellHeight === 60

        CcPill {
            id: pWifi
            visible: cc.controlType === "wifi"
            width: cc.isDisc ? 60 : cc.width
            height: 57
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
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

        CcPill {
            visible: cc.controlType === "bluetooth"
            width: cc.isDisc ? 60 : cc.width
            height: 57
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
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
                cc.drillRequested("bluetooth", mapToItem(root, width / 2, height / 2))
            }
        }

        CcPill {
            visible: cc.controlType === "focus"
            width: cc.isDisc ? 60 : cc.width
            height: 57
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
            active: Notifications.dnd
            icon: "do_not_disturb_on"
            label: "Focus"
            sublabel: Notifications.dnd ? "On" : "Off"
            onClicked: Notifications.dnd = !Notifications.dnd
        }

        CcPill {
            id: pGame
            property bool on: false
            visible: cc.controlType === "gameMode"
            width: cc.isDisc ? 60 : cc.width
            height: 57
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
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

        CcIconBtn {
            visible: cc.controlType === "lock"
            width: 60; height: 60
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
            icon: "lock"
            onClicked: { Quickshell.execDetached(["hyprlock"]); UiState.closeAll() }
        }

        CcIconBtn {
            visible: cc.controlType === "nightLight"
            width: 60; height: 60
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
            icon: NightLight.enabled ? "dark_mode" : "nightlight"
            active: NightLight.enabled
            onClicked: NightLight.toggle()
        }

        CcIconBtn {
            visible: cc.controlType === "idleInhibit"
            width: 60; height: 60
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
            icon: "coffee"
            active: IdleInhibit.active
            onClicked: IdleInhibit.toggle()
        }

        CcIconBtn {
            visible: cc.controlType === "battery"
            width: 60; height: 60
            x: cc.isDisc ? (cc.width - 60) / 2 : 0
            icon: Battery.charging ? "battery_charging_full" : "battery_std"
            active: Battery.available
            onClicked: {}
        }

        SliderCard {
            visible: cc.controlType === "sound"
            width: cc.width
            height: 52
            cardLabel: "Sound"
            sliderIcon: Volume.muted ? "volume_off"
                : (Volume.volumePercent > 50 ? "volume_up" : "volume_down")
            sliderValue: Volume.muted ? 0 : Volume.volumePercent / 100
            onSliderMoved: (f) => Volume.setVolume(f * 100)
            onSliderScrolled: (delta) =>
                Volume.setVolume(Math.max(0, Math.min(100, Volume.volumePercent + delta * 5)))
            onChevronClicked: cc.drillRequested("sound")
            chevronVisible: true
        }

        SliderCard {
            visible: cc.controlType === "display"
            width: cc.width
            height: 52
            cardLabel: "Display"
            // The home capture's Display slider carries the same ring-and-dots
            // sun as the drill-down one, not brightness_7's filled gear.
            sliderIcon: "wb_sunny"
            sliderValue: Math.max(0.04, Brightness.level / 100)
            onSliderMoved: (f) => Brightness.setBrightness(Math.round(f * 100))
            onSliderScrolled: (delta) => Brightness.step(delta * 5)
            onChevronClicked: cc.drillRequested("display")
            chevronVisible: true
        }

        // ── Notifications ───────────────────────────────────────
        Rectangle {
            id: notifGrid
            visible: cc.controlType === "notifications"
            width: cc.width
            height: cc.height
            radius: 14
            color: root.bgCard
            border.color: "#282828"
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

                StyledText {
                    visible: Notifications.active.length === 0
                    text: "No notifications"
                    font.pixelSize: 13
                    color: "#555555"
                }

                // The list and its scroll indicator sit in a plain Item, with
                // the indicator as a later sibling of the Flickable rather
                // than a child of it.
                //
                // A Flickable composites its contentItem ahead of its own
                // other children, so an indicator inside the Flickable is
                // painted *under* the cards. The cards are translucent, so it
                // still showed through rather than vanishing -- just dimmed
                // where they overlapped, which read as three broken segments
                // instead of one continuous thumb. Moving it after the
                // Flickable, raising its z, and dropping the contentItem's z
                // were each tried and none changed the paint order. As a
                // sibling in a plain Item the ordering is ordinary, so it is
                // on top.
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
                                delegate: NotifRow {
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

    // One scroll indicator for all four sub-pages, rather than one inside each
    // page. A Flickable composites its clipped contentItem ahead of its own
    // other children, so an indicator parented to the Flickable is painted
    // under the content -- on the notification list the translucent cards
    // dimmed it into three broken segments. Only one page is open at a time,
    // so a single indicator bound to whichever is showing is enough, and as a
    // later sibling it paints over the whole page. The sub-pages are 22px or
    // 10px inset sheets, so it tracks the card rather than the panel.
    SubtleScroll {
        flickable: root.activeFlick
        z: 60
        // Inset 6px, not 3. At 3 it landed exactly on the card's 1px border
        // and was indistinguishable from it; 6 puts it just inside the card
        // fill, clear of both the border and the content's own right edge.
        x: drillCard.x + drillCard.width - 6
        y: drillCard.y + 4
        height: drillCard.height - 8
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
        // The reference card is a #272221 slab with a soft edge and no
        // hairline, sitting on the #181614 popover. It used to be the same
        // #181614 as the popover with a visible border, which made the
        // nesting read as flat.
        radius: 15
        property var monitorModel: null
        // +27, not +20: the reference card is 163px tall and its own
        // measured edges put the content 17px above the card's bottom,
        // against this column's 10px margin.
        implicitHeight: mcCol.implicitHeight + 27
        color: root.bgItem
        border.width: 0

        readonly property real brightness: monitorModel ? monitorModel.brightness : 0
        readonly property string monName: monitorModel ? monitorModel.modelData.name : ""
        // Quickshell.screens has no refresh rate, so it comes from the
        // Brightness service's Hyprland probe. Omit the segment when it is
        // unknown rather than printing "NaN Hz", which is what this did.
        readonly property string _hz: {
            const hz = monitorModel ? Brightness.refreshRates[monitorModel.modelData.name] : undefined;
            return (typeof hz === "number" && isFinite(hz) && hz > 0) ? Math.round(hz) + " Hz" : "";
        }
        // Quickshell.screens has no per-output scale in this build, so the
        // scale comes from Brightness's own Hyprland probe. Falls back to
        // modelData.scale in case a future build does expose it.
        readonly property real monScale: {
            if (!monitorModel) return 0;
            const probed = Brightness.outputScales[monitorModel.modelData.name];
            if (typeof probed === "number" && probed > 0) return probed;
            const direct = monitorModel.modelData.scale;
            return (typeof direct === "number" && direct > 0) ? direct : 0;
        }

        readonly property string monScaleLabel: monScale > 0
            ? Number(monScale).toFixed(2).replace(/0$/, "") + "x"
            : ""

        readonly property string monDesc: monitorModel ? [
            monitorModel.modelData.width + "×" + monitorModel.modelData.height,
            _hz,
            monScaleLabel
        ].filter(s => s !== "").join("  ·  ") : ""

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
            anchors { fill: parent; margins: 10 }
            // 7, not 10: in the reference the gap between the bottom of the
            // brightness track (y 185.1) and the top of the scale chips
            // (y 192) is 6.9px. The gap below the chips is wider, which the
            // resolution row's topMargin below carries.
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // A 30px disc. The focused output gets a solid accent fill
                // with a dark glyph; the others get a warm grey disc with a
                // pale glyph. It used to be a 36px rounded square with a
                // 20%-alpha accent wash, which matched neither. The 30 is
                // the reference's: the accent disc on the DP-1 card measures
                // 30 x 29 as a solid teal shape.
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                    color: mc.focused ? root.accent : root.bgBadgeDim
                    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
                    Icon {
                        anchors.centerIn: parent
                        icon: "monitor"
                        size: 15
                        iconColor: mc.focused ? root.accentText : "#CCCCCC"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText { text: mc.monName; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                    StyledText { text: mc.monDesc; font.pixelSize: 11; color: root.textDim }
                }

                StyledText {
                    visible: mc.focused
                    Layout.alignment: Qt.AlignVCenter
                    text: "focused"
                    font.pixelSize: 11
                    color: root.accent
                }
            }

            // Track with the percentage parked OUTSIDE it on the right, as
            // the reference has it. The readout used to be drawn inside the
            // track and flipped colour with the level, which put a number
            // on top of the accent fill.
            Item {
                id: mcBrightRow
                Layout.fillWidth: true
                // 26: the reference track's own edges cross half-way at
                // y 159.1 and 185.1.
                Layout.preferredHeight: 26

                Item {
                    id: mcTrack
                    anchors.left: parent.left
                    anchors.right: mcPct.left
                    anchors.rightMargin: 17
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.bgSliderTrackCard
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
                            // "brightness_5" in Material Symbols is a
                            // scalloped gear; the reference slider uses the
                            // ring-and-dots sun, which is "wb_sunny".
                            icon: "wb_sunny"; size: 14; iconColor: "#111111"
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

                StyledText {
                    id: mcPct
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(mc.brightness * 100) + "%"
                    font.pixelSize: 12
                    color: "#999999"
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: [1.0, 1.25, 1.5, 1.75, 2.0]

                    Rectangle {
                        required property real modelData
                        readonly property bool selected: mc.monitorModel &&
                            mc.monScale > 0 &&
                            Math.abs(mc.monScale - modelData) < 0.05
                        // 28 tall and fully rounded: the reference's scale
                        // chips are pills, not 30px rounded squares. The
                        // selected chip's own teal edge runs y 193..220 in
                        // the Display capture -- 28, against 26 here.
                        height: 28
                        width: scaleLabel.implicitWidth + 20
                        radius: height / 2
                        color: selected ? root.accent : root.bgPill
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                Quickshell.execDetached([
                                    "hyprctl", "keyword", "monitor",
                                    mc.monName + ",preferred,auto," + modelData
                                ])
                                // The scale we just asked for is not what the
                                // probe last saw; re-read so the chip lights
                                // up and the spec line follows.
                                Brightness.refreshMonitorInfo()
                            }
                        }

                        StyledText {
                            id: scaleLabel
                            anchors.centerIn: parent
                            text: Number(modelData).toFixed(2).replace(/0$/, "") + "x"
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: selected ? root.accentText : "#AAAAAA"
                        }
                    }
                }
            }

            // The reference sets this row straight onto the card — no second
            // bordered box — and indents it a little further in than the
            // chips above.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                Layout.leftMargin: 8
                // The reference opens this row 14px below the chips (their
                // bottom edge is y 220, its own ink starts at 239) where the
                // column's own 7px spacing would leave 7.
                Layout.topMargin: 7

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                RowLayout {
                    anchors { fill: parent; rightMargin: 3 }
                    StyledText { text: "Resolution"; font.pixelSize: 13; color: root.textDim }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        // Same omission rule as monDesc: no refresh rate
                        // means no "@ ... Hz" segment, never "NaN Hz".
                        text: mc.monitorModel
                            ? (mc.monitorModel.modelData.width + "×" +
                               mc.monitorModel.modelData.height +
                               (mc._hz ? " @ " + mc._hz : ""))
                            : ""
                        font.pixelSize: 13; color: "#8a8a8a"
                    }
                    Icon { icon: "chevron_right"; size: 14; iconColor: "#666666" }
                }
            }
        }
    }
}