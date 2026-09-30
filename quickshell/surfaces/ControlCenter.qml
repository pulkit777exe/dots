import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../components"
import "../services"
import "settings"






Surface {
    id: root

    focus: UiState.controlCenterOpen
    Keys.onEscapePressed: root.view = "home"

    readonly property color accent: Theme.colors.accent
    readonly property color accentText: Theme.colors.accentText

    
    
    
    
    readonly property color bgSurface: "#181614"
    readonly property color bgCard: "#181614"
    readonly property color bgCardHover: "#282828"
    readonly property color bgCardActive: "#24332c"
    readonly property color bgItem: "#272221"
    readonly property color bgItemHover: "#2e2e2e"
    readonly property color bgSliderTrack: "#0d0b0a"

    
    
    
    
    
    readonly property color bgBadgeDim: "#413a37"
    readonly property color bgPill: "#342e29"
    
    
    readonly property color bgSliderTrackCard: "#141211"
    
    readonly property color textDim: "#7a7a7a"

    width: 460
    
    
    height: implicitHeight
    cornerRadius: 24
    backgroundColor: root.bgSurface
    borderColor: "#262626"
    borderWidth: 1
    shadow: true

    
    
    
    
    
    
    
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

    
    
    
    
    
    
    
    readonly property var activeNetwork: {
        const nets = Wifi.networks || []
        
        
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
        
        if (!s || s === "--" || s === "NONE") return ""
        return s
    }

    readonly property string activeMeta: {
        const parts = ["Connected"]
        if (root.activeSecurity.length > 0) parts.push(root.activeSecurity)
        if (Wifi.strength > 0) parts.push(Wifi.strength + "% signal")
        return parts.join(" · ")
    }

    
    property string view: "home"

    
    
    onViewChanged: if (UiState.ccView !== root.view) UiState.ccView = root.view
    Connections {
        target: UiState
        function onCcViewChanged() {
            if (UiState.ccView !== root.view) root.view = UiState.ccView;
        }
    }
    Component.onCompleted: root.view = UiState.ccView

    
    Connections {
        target: UiState
        function onControlCenterOpenChanged() {
            if (!UiState.controlCenterOpen) root.view = "home"
        }
    }

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
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

    
    
    
    readonly property bool drillOpen: view !== "home"

    
    
    
    
    property point popoverOrigin: Qt.point(width / 2, 150)


    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    Item {
        id: homePage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }

        readonly property var layoutItems: ControlCenterLayout.items
        readonly property int cols: ControlCenterLayout.columns

        
        
        readonly property real cellW: (width - (cols - 1) * 10) / cols
        
        
        
        function colX(c) { return c * (cellW + 10) }

        
        
        
        
        
        
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

        
        
        
        readonly property real firstRowBottom: {
            const t = rowTops()
            if (t.length < 2) return Math.min(height, 70)
            return t[1] - 5
        }

        
        
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

    
    
    
    
    
    
    Rectangle {
        id: drillCard
        
        
        
        
        
        
        
        readonly property real inset:
            (root.view === "display" || root.view === "sound") ? 22 : 10
        readonly property real baseX: parent.x + inset
        readonly property real baseY: root.drillTop
        width: parent.width - inset * 2
        
        
        height: root.drillHeight

        x: baseX
        y: baseY + (root.drillOpen ? 0 : -BarConfig.panelSlideIn)
        opacity: root.drillOpen ? 1 : 0
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        radius: 18
        color: root.bgSurface
        border.color: "#282828"
        border.width: 1
        visible: root.view !== "home"
    }

    
    
    
    Flickable {
        id: btFlick
        
        
        
        
        
        
        readonly property real baseX: parent.x + 10
        readonly property real baseY: root.drillTop
        width: parent.width - 20
        
        
        
        height: root.drillHeight
        contentWidth: width
        contentHeight: btFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "bluetooth"

        x: baseX
        y: baseY + (btFlick.visible ? 0 : -BarConfig.panelSlideIn)
        opacity: btFlick.visible ? 1 : 0
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: btFlickContent
            width: btFlick.width
            spacing: 0
            Item { Layout.preferredHeight: 12 }

            
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


    
    
    
    
    
    
    
    
    Flickable {
        id: soundFlick
        
        
        
        
        
        
        
        readonly property real baseX: parent.x + 22
        readonly property real baseY: root.drillTop
        width: parent.width - 44
        
        
        height: root.drillHeight
        contentWidth: width
        contentHeight: soundFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "sound"

        x: baseX
        y: baseY + (soundFlick.visible ? 0 : -BarConfig.panelSlideIn)
        opacity: soundFlick.visible ? 1 : 0
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
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

            
            SubPageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                title: "Sound"
                onBack: root.view = "home"
            }

            Item { Layout.preferredHeight: 8 }

            
            
            
            
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

            
            CcDeviceSlider {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                icon: Volume.muted ? "volume_off" : "volume_up"
                value: Volume.muted ? 0 : Volume.volumePercent
                onMoved: (f) => Volume.setVolume(f * 100)
            }

            Item { Layout.preferredHeight: 12 }

            
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

            
            CcDeviceSlider {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                icon: Volume.micMuted ? "mic_off" : "mic"
                value: Volume.micMuted ? 0 : Volume.micVolumePercent
                onMoved: (f) => Volume.setMicVolume(f * 100)
            }

            Item { Layout.preferredHeight: 12 }

            
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


    
    
    
    Flickable {
        id: dispFlick
        
        
        
        
        
        
        
        
        
        
        
        
        readonly property real baseX: parent.x + 22
        readonly property real baseY: root.drillTop
        width: parent.width - 44
        
        
        height: root.drillHeight
        contentWidth: width
        contentHeight: dispFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "display"

        onVisibleChanged: {
            if (visible) Brightness.refreshMonitorInfo()
        }

        x: baseX
        y: baseY + (dispFlick.visible ? 0 : -BarConfig.panelSlideIn)
        opacity: dispFlick.visible ? 1 : 0
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
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

            
            SubPageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 15
                Layout.rightMargin: 15
                title: "Display"
                onBack: root.view = "home"
            }

            Item { Layout.preferredHeight: 12 }

            
            
            
            
            
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

                        
                        
                        
                        Toggle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 21
                            checked: NightLight.enabled
                            accentColor: root.accent
                            
                            
                            thumbColor: "#000000"
                            onToggled: NightLight.toggle()
                        }
                    }

                    
                    
                    
                    
                    CcDeviceSlider {
                        Layout.fillWidth: true
                        visible: NightLight.enabled
                        onCard: true
                        
                        
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


    
    
    
    Flickable {
        id: wifiFlick
        
        
        
        
        
        
        readonly property real baseX: parent.x + 10
        readonly property real baseY: root.drillTop
        width: parent.width - 20
        
        
        
        height: root.drillHeight
        contentWidth: width
        contentHeight: wifiFlickContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        visible: root.view === "wifi"

        x: baseX
        y: baseY + (wifiFlick.visible ? 0 : -BarConfig.panelSlideIn)
        opacity: wifiFlick.visible ? 1 : 0
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
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

    
    
    
    
    
    
    onPendingWifiSsidChanged: {
        if (pendingWifiSsid.length > 0) pwDialog.open(pendingWifiSsid, pendingWifiError)
    }
    onPendingWifiErrorChanged: {
        if (pendingWifiSsid.length > 0 && pendingWifiError.length > 0) pwDialog.open(pendingWifiSsid, pendingWifiError)
    }


    
    
    

    
    component CcPill: Rectangle {
        id: pill
        
        
        height: 57
        radius: 16
        property bool active: false
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        signal clicked()

        
        
        function originInRoot() {
            return mapToItem(root, width / 2, height / 2);
        }

        
        
        
        
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

    
    component CcIconBtn: Rectangle {
        id: iconBtn
        
        
        
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

    
    
    
    
    
    component SubPageHeader: RowLayout {
        id: sph
        property string title: ""
        property string icon: ""
        property bool toggleVisible: false
        property bool toggleOn: false
        signal back()
        signal toggled()

        spacing: 12

        
        
        
        
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

    
    
    
    
    
    
    
    component CcDeviceSlider: Rectangle {
        id: devSlider
        property string icon: "volume_up"
        property real value: 0
        
        
        property bool onCard: false
        signal moved(real fraction)

        
        
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

    
    component SliderCard: Rectangle {
        id: sc
        
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

    
    
    
    
    
    
    
    
    
    
    
    
    
    component CcControl: Item {
        id: cc

        property string controlType: ""
        
        
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
            
            
            sliderIcon: "wb_sunny"
            sliderValue: Math.max(0.04, Brightness.level / 100)
            onSliderMoved: (f) => Brightness.setBrightness(Math.round(f * 100))
            onSliderScrolled: (delta) => Brightness.step(delta * 5)
            onChevronClicked: cc.drillRequested("display")
            chevronVisible: true
        }

        
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

    
    
    
    
    
    
    
    
    SubtleScroll {
        flickable: root.activeFlick
        z: 60
        
        
        
        x: drillCard.x + drillCard.width - 6
        y: drillCard.y + 4
        height: drillCard.height - 8
    }

    
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

    
    component SectionLabel: StyledText {
        font.pixelSize: 12
        font.weight: Font.Medium
        color: "#888888"
    }

    
    
    
    
    
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

            
            
            StyledText {
                text: cbr.device.connected ? "Disconnect" : (cbr.device.paired ? "Connect" : "Pair")
                font.pixelSize: 11
                color: root.accent
            }
        }
    }

    
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

    
    component MonitorCard: Rectangle {
        id: mc
        
        
        
        
        radius: 15
        property var monitorModel: null
        
        
        
        implicitHeight: mcCol.implicitHeight + 27
        color: root.bgItem
        border.width: 0

        readonly property real brightness: monitorModel ? monitorModel.brightness : 0
        readonly property string monName: monitorModel ? monitorModel.modelData.name : ""
        
        
        
        readonly property string hostname: {
            const hz = monitorModel ? Brightness.refreshRates[monitorModel.modelData.name] : undefined;
            return (typeof hz === "number" && isFinite(hz) && hz > 0) ? Math.round(hz) + " Hz" : "";
        }
        
        
        
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
            hostname,
            monScaleLabel
        ].filter(s => s !== "").join("  ·  ") : ""

        
        
        
        
        
        readonly property var activeMonitor: Brightness.getMonitor("active")
        readonly property bool focused: !!monitorModel && !!activeMonitor
            && activeMonitor.modelData.name === monitorModel.modelData.name

        ColumnLayout {
            id: mcCol
            anchors { fill: parent; margins: 10 }
            
            
            
            
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                
                
                
                
                
                
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

            
            
            
            
            Item {
                id: mcBrightRow
                Layout.fillWidth: true
                
                
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

            
            
            
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                Layout.leftMargin: 8
                
                
                
                Layout.topMargin: 7

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                RowLayout {
                    anchors { fill: parent; rightMargin: 3 }
                    StyledText { text: "Resolution"; font.pixelSize: 13; color: root.textDim }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        
                        
                        text: mc.monitorModel
                            ? (mc.monitorModel.modelData.width + "×" +
                               mc.monitorModel.modelData.height +
                               (mc.hostname ? " @ " + mc.hostname : ""))
                            : ""
                        font.pixelSize: 13; color: "#8a8a8a"
                    }
                    Icon { icon: "chevron_right"; size: 14; iconColor: "#666666" }
                }
            }
        }
    }
}