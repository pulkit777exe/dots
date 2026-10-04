import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"


// CcDisplayPage.qml -- the control centre's Display page.
//
// Extracted from ControlCenter.qml. The geometry, the slide-in and the
// fade are CcDrillPage's; what is left is this page's own content.
// `back()` goes to ControlCenter, which owns `view` -- a page does not
// know the name of the view it came from.

CcDrillPage {
    id: root

    property real inset: 22

    signal back()

    // Was `onVisibleChanged` on the Flickable. `open` stands in for it:
    // the page is hidden exactly when it is closed, so the two fire
    // together.
    onOpenChanged: {
        if (open) Brightness.refreshMonitorInfo()
    }


    CcTokens { id: cc }


    contentHeight: dispFlickContent.implicitHeight


    Rectangle {
        anchors.fill: parent
        radius: 24
        color: cc.bgSurface
    }

    ColumnLayout {
        id: dispFlickContent
        width: root.width
        spacing: 0
        Item { Layout.preferredHeight: 12 }


        CcSubPageHeader {
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            title: "Display"
            onBack: root.back()
        }

        Item { Layout.preferredHeight: 12 }


        Repeater {
            model: Brightness.monitors
            CcMonitorCard {
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
            color: cc.bgItem
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
                        color: NightLight.enabled ? Theme.colors.accent : cc.bgBadgeDim
                        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                        Icon {
                            anchors.centerIn: parent
                            icon: "nightlight"
                            size: 15
                            iconColor: NightLight.enabled ? Theme.colors.accentText : cc.textIcon
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        StyledText { text: "Night Light"; font.pixelSize: 13; font.weight: Font.Medium; color: cc.textPrimary }
                        StyledText {
                            text: NightLight.enabled
                                ? Math.round(NightLight.nightTemperature) + " K"
                                : "Off"
                            font.pixelSize: 12
                            color: cc.textDim
                        }
                    }


                    Toggle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 21
                        checked: NightLight.enabled
                        accentColor: Theme.colors.accent


                        thumbColor: cc.onAccent
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
