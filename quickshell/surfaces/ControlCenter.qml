import QtQuick
import QtQuick.Layouts
// `Quickshell` is imported by the two files that call `execDetached` -- the lock
// button's body in components/CcControl.qml and the scale pills in
// components/CcMonitorCard.qml -- and it has to be `Quickshell`, not
// `Quickshell.Io`: the namespace access resolves against the module that
// declares it, so importing Io instead left the lock button throwing a
// ReferenceError on click. Both of those name no Io type.
import "../components"
import "../services"
import "cc"
import "settings"

Surface {
    id: root

    focus: UiState.controlCenterOpen
    Keys.onEscapePressed: root.view = "home"

    readonly property color accent: Theme.colors.accent

    readonly property color accentText: Theme.colors.accentText

    // Everything else this panel paints is `cc.*`, from
    // components/CcTokens.qml. It used to be eleven `readonly property color`
    // declarations with hardcoded hex in this file; ten of the eleven matched
    // no palette in colors/themes/ at all, and the panel was the wrong colour
    // on five of the six.
    CcTokens { id: ccColors }

    width: 460
    
    height: implicitHeight
    cornerRadius: 24
    backgroundColor: ccColors.bgSurface
    borderColor: ccColors.borderColor
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
        view === "bluetooth" ? btPage
        : view === "display"   ? dispPage
        : view === "wifi"      ? wifiPage
        : view === "sound"     ? soundPage
        : null

    readonly property real drillTop: homePage.y + homePage.firstRowBottom
    readonly property real drillHeight: Math.max(140, root.panelHeight - 14 - root.drillTop)

    // Height follows the page that is showing, for the same reason the settings
    // window does: 514/564/719 were kept in step by hand and had drifted, so a
    // drill page drew up to 370px of dead black below its last control. The
    // numbers were also load-bearing on the wrong side -- too small clips the
    // page. Same bug class Phase 3 of todos.md records for the bar window.
    //
    // activeFlick.contentHeight is the content's own height and does not read
    // the window back, so this cannot feed its own input. The home view keeps
    // 514: its rows are absolutely positioned inside a Repeater, so there is no
    // content height to read, and inventing one would be a guess.
    readonly property int panelHeight: drillOpen && activeFlick
        ? Math.ceil(drillTop + 14 + Math.max(140, activeFlick.contentHeight))
        : 514
    implicitHeight: panelHeight

    readonly property bool drillOpen: view !== "home"

    property point popoverOrigin: Qt.point(width / 2, 150)

    CcHomePage {
        id: homePage
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        panel: root
        drillOpen: root.drillOpen
        onDrillRequested: (view, origin) => {
            if (origin) root.popoverOrigin = origin;
            root.view = view;
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
        color: ccColors.bgSurface
        border.color: ccColors.borderColor
        border.width: 1
        visible: root.view !== "home"
    }

// The four drill pages. Each is a CcDrillPage: it is given the
    // panel's own geometry and told whether it is the one open, and it reports
    // contentHeight back through activeFlick, which is what panelHeight is built
    // from.
    //
    // They stay direct children of the panel, and that is load-bearing rather
    // than incidental: a page inside a wrapper would measure against the
    // wrapper, and panelHeight reads this page's contentHeight to size the very
    // window that draws it.
    CcBluetoothPage {
        id: btPage
        open: root.view === "bluetooth"
        panelX: root.x
        panelWidth: root.width
        pageTop: root.drillTop
        pageHeight: root.drillHeight
        onBack: root.view = "home"
    }

    CcSoundPage {
        id: soundPage
        open: root.view === "sound"
        panelX: root.x
        panelWidth: root.width
        pageTop: root.drillTop
        pageHeight: root.drillHeight
        onBack: root.view = "home"
    }

    CcDisplayPage {
        id: dispPage
        open: root.view === "display"
        panelX: root.x
        panelWidth: root.width
        pageTop: root.drillTop
        pageHeight: root.drillHeight
        onBack: root.view = "home"
    }

    CcWifiPage {
        id: wifiPage
        open: root.view === "wifi"
        panelX: root.x
        panelWidth: root.width
        pageTop: root.drillTop
        pageHeight: root.drillHeight
        activeMeta: root.activeMeta
        onBack: root.view = "home"
        onConnectRequested: (ssid, secured) => root.attemptWifiConnect(ssid, secured)
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

    SubtleScroll {
        flickable: root.activeFlick
        z: 60
        
        x: drillCard.x + drillCard.width - 6
        y: drillCard.y + 4
        height: drillCard.height - 8
    }

}