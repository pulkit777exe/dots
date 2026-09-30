import QtQuick
import QtQuick.Layouts
import "../services"


















Item {
    id: root

    property string controlType: ""
    property int colSpan: 1
    property int rowSpan: 1
    
    
    property bool selected: false

    

    component StatusPill: Item {
        id: pill
        property string title: ""
        property string subtitle: ""
        property string iconName: ""
        
        
        
        property bool isOn: false
        property bool showSubtitle: true

        implicitHeight: 52
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.055)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 16
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                
                
                color: pill.isOn ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.07)

                Icon {
                    anchors.centerIn: parent
                    icon: pill.iconName
                    size: 19
                    iconColor: pill.isOn ? "#0B1512" : Qt.rgba(1, 1, 1, 0.75)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: pill.title
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: "#F6E2CB"
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: pill.showSubtitle
                    text: pill.subtitle
                    font.pixelSize: 11
                    textColor: Qt.rgba(1, 1, 1, 0.55)
                    elide: Text.ElideRight
                }
            }
        }
    }

    component DiscButton: Item {
        id: disc
        property string iconName: ""
        property bool isOn: false
        implicitWidth: 52
        implicitHeight: 52
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: disc.isOn ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.055)
        }
        Icon {
            anchors.centerIn: parent
            icon: disc.iconName
            size: 21
            iconColor: disc.isOn ? "#0B1512" : Qt.rgba(1, 1, 1, 0.8)
        }
    }

    
    component SliderCard: Item {
        id: card
        property string title: ""
        property string iconName: ""
        property real fraction: 0
        property string chipText: ""
        property bool chipOn: true
        implicitHeight: 68

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.055)
        }

        StyledText {
            id: titleText
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 11
            text: card.title
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: "#F6E2CB"
        }

        Icon {
            anchors.right: parent.right
            anchors.verticalCenter: titleText.verticalCenter
            anchors.rightMargin: 14
            icon: "chevron_right"
            size: 16
            iconColor: Qt.rgba(1, 1, 1, 0.45)
        }

        Item {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            height: 22

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.11)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(1, card.fraction))
                height: 6
                radius: 3
                color: Theme.colors.accent
            }
            Icon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: card.iconName
                size: 15
                iconColor: Theme.colors.accent
            }
            
            
            Rectangle {
                visible: card.chipText.length > 0
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width,
                                         parent.width * card.fraction - width / 2))
                width: chipLabel.implicitWidth + 26
                height: 22
                radius: 11
                color: card.chipOn ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.12)
                StyledText {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: card.chipText
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: card.chipOn ? "#0B1512" : "#F6E2CB"
                }
            }
        }
    }

    component NotificationList: Item {
        id: list
        
        
        readonly property var shown: Notifications.active.slice(0, 2)
        implicitHeight: 40 + Math.max(1, shown.length) * 64

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.055)
        }

        StyledText {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 13
            text: "Notifications"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: "#F6E2CB"
        }

        StyledText {
            anchors.top: head.top
            anchors.right: parent.right
            anchors.rightMargin: 16
            text: "Clear all"
            font.pixelSize: 12
            textColor: Qt.rgba(1, 1, 1, 0.55)
        }

        Column {
            anchors.top: head.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            
            
            Repeater {
                model: list.shown.length ? list.shown : [null]

                delegate: Rectangle {
                    id: notifRow
                    required property var modelData

                    readonly property string sender: modelData
                        ? (modelData.appName || modelData.app || "notify-send") : "notify-send"
                    readonly property string summary: modelData
                        ? (modelData.summary || modelData.title || "") : "All caught up"
                    readonly property string body: modelData ? (modelData.body || "") : ""

                    width: parent.width
                    height: 56
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.035)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: Qt.alpha(Theme.colors.accent, 0.18)
                            StyledText {
                                anchors.centerIn: parent
                                text: notifRow.sender.slice(0, 1).toUpperCase()
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.colors.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: notifRow.sender
                                font.pixelSize: 10
                                textColor: Qt.rgba(1, 1, 1, 0.5)
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: notifRow.summary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#F6E2CB"
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: notifRow.body
                                font.pixelSize: 11
                                textColor: Qt.rgba(1, 1, 1, 0.55)
                                elide: Text.ElideRight
                            }
                        }

                        Icon {
                            icon: "close"
                            size: 14
                            iconColor: Qt.rgba(1, 1, 1, 0.4)
                        }
                    }
                }
            }
        }
    }

    

    StatusPill {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "wifi"
        title: "Wi-Fi"; iconName: "wifi"; isOn: Wifi.connected
        subtitle: Wifi.connected ? (Wifi.ssid || "Connected") : "Off"
    }

    StatusPill {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "bluetooth"
        title: "Bluetooth"; iconName: "bluetooth"; isOn: Bluetooth.enabled
        subtitle: Bluetooth.enabled ? (Bluetooth.connectedName || "On") : "Off"
    }

    StatusPill {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "focus"
        title: "Focus"; iconName: "do_not_disturb_on"; isOn: Notifications.dnd
        subtitle: Notifications.dnd ? "On" : "Off"
    }

    StatusPill {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "gameMode"
        title: "Game Mode"; iconName: "sports_esports"
        isOn: PowerProfile.active === "performance"
        subtitle: PowerProfile.active === "performance" ? "On" : "Off"
    }

    StatusPill {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "nowPlaying"
        title: Media.hasPlayer ? (Media.title || "Now Playing") : "Nothing playing"
        iconName: "music_note"
        isOn: Media.hasPlayer
        subtitle: Media.artist || "Now Playing"
    }

    StatusPill {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "clipboard"
        title: "Clipboard"; iconName: "content_paste"
        isOn: Clipboard.entries.length > 0
        subtitle: Clipboard.entries.length + (Clipboard.entries.length === 1 ? " entry" : " entries")
    }

    DiscButton {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "lock"
        iconName: "lock"
    }

    DiscButton {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "nightLight"
        iconName: "dark_mode"
        isOn: NightLight.enabled
    }

    DiscButton {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "idleInhibit"
        iconName: "coffee"
        isOn: IdleInhibit.active
    }

    DiscButton {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "battery"
        iconName: Battery.charging ? "battery_charging_full" : "battery_std"
        isOn: Battery.available
    }

    SliderCard {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "sound"
        title: "Sound"
        iconName: Volume.iconName || "volume_up"
        
        
        fraction: Volume.volume
        chipText: "Night Light"
        chipOn: NightLight.enabled
    }

    SliderCard {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "display"
        title: "Display"
        iconName: "brightness_high"
        fraction: Brightness.available ? Brightness.level / 100 : 0
    }

    NotificationList {
        
        
        
        
        
        
        anchors.fill: parent
        visible: root.controlType === "notifications"
    }

    

    Rectangle {
        anchors.fill: parent
        radius: Math.min(parent.height / 2, parent.width / 2)
        color: "transparent"
        border.width: root.selected ? 1.5 : 0
        border.color: Theme.colors.accent
        visible: root.selected
    }

    
    
    Rectangle {
        visible: root.selected
        width: 20; height: 20; radius: 10
        color: Theme.colors.danger
        x: -10
        y: -10
        z: 2

        Icon {
            anchors.centerIn: parent
            icon: "remove"
            size: 13
            iconColor: "#FFFFFF"
        }
    }
}
