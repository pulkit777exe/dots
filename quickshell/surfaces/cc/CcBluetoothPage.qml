import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"


// CcBluetoothPage.qml -- the control centre's Bluetooth page.
//
// Extracted from ControlCenter.qml. The geometry, the slide-in and the
// fade are CcDrillPage's; what is left is this page's own content.
// `back()` goes to ControlCenter, which owns `view` -- a page does not
// know the name of the view it came from.

CcDrillPage {
    id: root

    property real inset: 10

    signal back()


    CcTokens { id: cc }


    contentHeight: btFlickContent.implicitHeight


    ColumnLayout {
        id: btFlickContent
        width: root.width
        spacing: 0
        Item { Layout.preferredHeight: 12 }


        CcSubPageHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            toggleVisible: true
            toggleOn: Bluetooth.enabled
            onBack: root.back()
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

                CcSectionLabel { text: "Connected" }

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

                CcSectionLabel { text: "Saved" }

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
                CcSectionLabel { text: "Nearby" }
                Item { Layout.fillWidth: true }
                RowLayout {
                    spacing: 6
                    visible: Bluetooth.scanning
                    Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: Theme.colors.accent }
                    StyledText { text: "Scanning"; font.pixelSize: 11; color: cc.textSub }
                }
            }

            Repeater {
                model: Bluetooth.nearbyDevices
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
