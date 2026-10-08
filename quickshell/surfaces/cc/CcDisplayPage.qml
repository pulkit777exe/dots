import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

// Display drill page: one card per monitor, then the night light card.

CcPage {
    id: page
    sideMargin: 15
    onVisibleChanged: if (visible) Brightness.refreshMonitors()

    CcHeader {
        Layout.fillWidth: true
        title: "Display"
        onBack: page.back()
    }

    Item { Layout.preferredHeight: 12; Layout.fillWidth: true }

    Repeater {
        model: Brightness.monitorList
        CcMonitorCard {
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: 12
            monitor: modelData
        }
    }

    Rectangle {                          // night light
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.preferredHeight: nlCol.implicitHeight + 20
        radius: 15
        color: Theme.cc.item

        ColumnLayout {
            id: nlCol
            anchors { fill: parent; margins: 10 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: NightLight.enabled ? Theme.accentFor("control-center")
                        : Theme.withAlpha(Theme.colors.text, 0.20)
                    Behavior on color { ColorAnimation { duration: Config.hover() } }

                    Icon {
                        anchors.centerIn: parent
                        icon: "nightlight"
                        size: 15
                        iconColor: NightLight.enabled ? Theme.colors.accentText
                            : Theme.withAlpha(Theme.colors.text, 0.85)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { text: "Night Light"; font.pixelSize: Theme.px(13); font.weight: Font.Medium; color: Theme.colors.text }
                    Label {
                        text: NightLight.enabled ? NightLight.temperature + " K" : "Off"
                        font.pixelSize: Theme.px(12)
                        color: Theme.withAlpha(Theme.colors.text, 0.48)
                    }
                }

                Toggle {
                    accent: Theme.accentFor("control-center")
                    checked: NightLight.enabled
                    onToggled: NightLight.toggle()
                }
            }

            CcDeviceSlider {
                Layout.fillWidth: true
                visible: NightLight.enabled
                icon: "nightlight"
                value: Math.max(0, Math.min(1, (NightLight.temperature - 1000) / 5500))
                onMoved: f => NightLight.setTemperature(Math.round(1000 + f * 5500))
            }
        }
    }

    Item { Layout.preferredHeight: 14; Layout.fillWidth: true }
}
