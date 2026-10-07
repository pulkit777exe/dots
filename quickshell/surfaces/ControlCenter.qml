import QtQuick
import "../components"
import "../services"
import "cc"

// The control centre: a 460px card under the bar. The home grid is always
// laid out; a drill page draws over it from the second row down, so the
// first row stays visible as the page switcher. The panel's height follows
// whichever view is showing -- the bar window sizes itself from it.

PopupPanel {
    id: cc

    open: UiState.controlCenterOpen
    width: 460
    cornerRadius: 24
    backgroundColor: Theme.cc.surface
    borderColor: Theme.cc.border
    borderWidth: 1

    readonly property bool drillOpen: UiState.ccView !== "home"

    // The line the drill card covers from: five px into the gap under row 0.
    readonly property real drillTop: 14 + homePage.firstRowBottom
    readonly property int homeBottom: Math.ceil(homePage.contentBottom + 28)

    readonly property real activeContent: {
        switch (UiState.ccView) {
        case "display": return displayPage.contentHeight;
        case "sound": return soundPage.contentHeight;
        case "wifi": return wifiPage.contentHeight;
        case "bluetooth": return btPage.contentHeight;
        }
        return 0;
    }
    readonly property int drillBottom: Math.ceil(drillTop + Math.max(140, activeContent) + 14)

    // Never shorter than the home grid, so nothing peeks out below the card.
    readonly property int panelHeight: drillOpen ? Math.max(homeBottom, drillBottom) : homeBottom
    readonly property real drillHeight: Math.max(140, panelHeight - 14 - drillTop)

    implicitHeight: panelHeight

    CcHomePage {
        id: homePage
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: 14
        drillOpen: cc.drillOpen
        onDrill: page => UiState.ccView = page
    }

    // ---- drill card -------------------------------------------------------

    Rectangle {
        id: drillCard

        readonly property int inset:
            (UiState.ccView === "display" || UiState.ccView === "sound") ? 22 : 10

        x: inset
        y: cc.drillTop + (cc.drillOpen ? 0 : -22)
        width: cc.width - inset * 2
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
            NumberAnimation { duration: Config.movement(0.5); easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }
        Behavior on scale {
            enabled: !Config.reduceMotion
            NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic }
        }

        CcDisplayPage {
            id: displayPage
            anchors { top: parent.top; left: parent.left; right: parent.right }
            visible: UiState.ccView === "display"
            onBack: UiState.ccView = "home"
        }
        CcSoundPage {
            id: soundPage
            anchors { top: parent.top; left: parent.left; right: parent.right }
            visible: UiState.ccView === "sound"
            onBack: UiState.ccView = "home"
        }
        CcWifiPage {
            id: wifiPage
            anchors { top: parent.top; left: parent.left; right: parent.right }
            visible: UiState.ccView === "wifi"
            onBack: UiState.ccView = "home"
        }
        CcBluetoothPage {
            id: btPage
            anchors { top: parent.top; left: parent.left; right: parent.right }
            visible: UiState.ccView === "bluetooth"
            onBack: UiState.ccView = "home"
        }
    }
}
