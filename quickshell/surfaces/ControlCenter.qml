import QtQuick
import "../components"
import "../services"
import "cc"

PopupPanel {
    id: cc

    open: UiState.controlCenterOpen
    width: 460
    cornerRadius: open ? 24 : pillRadius
    backgroundColor: Theme.cc.surface
    borderColor: Theme.cc.border
    borderWidth: 1

    readonly property bool drillOpen: UiState.ccView !== "home"

    // Fixed geometry: the box never resizes between pages or as content
    // changes -- pages scroll inside it instead.
    readonly property int panelHeight: 544
    readonly property int inset: 14
    readonly property real drillTop: inset + homePage.firstRowBottom
    readonly property real drillHeight: panelHeight - inset - drillTop

    implicitHeight: panelHeight

    CcHomePage {
        id: homePage
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.margins: cc.inset
        drillOpen: cc.drillOpen
        onDrill: page => UiState.ccView = page
    }

    Rectangle {
        id: drillCard

        x: cc.inset
        y: cc.drillTop + (cc.drillOpen ? 0 : -22)
        width: cc.width - cc.inset * 2
        height: cc.drillHeight
        radius: 22
        color: Theme.cc.surface
        border.color: Theme.cc.border
        border.width: 1
        clip: true
        visible: cc.drillOpen || opacity > 0.01
        opacity: cc.drillOpen ? 1 : 0
        transformOrigin: Item.Top
        scale: cc.drillOpen ? 1 : 0.985

        Behavior on y {
            enabled: !Config.reduceMotion
            NumberAnimation { duration: Config.movement(0.5); easing.type: Easing.OutQuint }
        }
        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }
        Behavior on scale {
            enabled: !Config.reduceMotion
            NumberAnimation { duration: Config.movement(0.5); easing.type: Easing.OutQuint }
        }

        CcDisplayPage {
            id: displayPage
            anchors.fill: parent
            visible: UiState.ccView === "display"
            onBack: UiState.ccView = "home"
        }
        CcSoundPage {
            id: soundPage
            anchors.fill: parent
            visible: UiState.ccView === "sound"
            onBack: UiState.ccView = "home"
        }
        CcWifiPage {
            id: wifiPage
            anchors.fill: parent
            visible: UiState.ccView === "wifi"
            onBack: UiState.ccView = "home"
        }
        CcBluetoothPage {
            id: btPage
            anchors.fill: parent
            visible: UiState.ccView === "bluetooth"
            onBack: UiState.ccView = "home"
        }
    }
}
