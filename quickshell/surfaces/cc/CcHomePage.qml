import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../services"

Item {
    id: page

    signal drill(string page)
    property bool drillOpen: false

    readonly property real rowH: 60
    readonly property real firstRowBottom: rowH + 5
    readonly property real notifTop: 264
    readonly property real notifH: Math.max(0, height - notifTop)

    function liveAt(bottom): bool { return !drillOpen || bottom <= firstRowBottom; }

    RowLayout {
        width: parent.width
        height: rowH
        spacing: 10

        CcPill {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            enabled: page.liveAt(rowH)
            active: Wifi.enabled && Wifi.connected
            icon: Wifi.iconName
            title: "Wi-Fi"
            subtitle: Wifi.subtitle
            onClicked: { Wifi.scan(); page.drill("wifi"); }
        }
        CcPill {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            enabled: page.liveAt(rowH)
            active: Notifications.dnd
            icon: "do_not_disturb_on"
            title: "Focus"
            subtitle: Notifications.dnd ? "On" : "Off"
            onClicked: Notifications.toggleDnd()
        }
        CcIconButton {
            icon: "lock"
            onClicked: { Quickshell.execDetached(["sh", "-c", "~/.config/hypr/hyprlock/scripts/lock.sh"]); UiState.closeAll(); }
        }
    }

    RowLayout {
        y: 70
        width: parent.width
        height: rowH
        spacing: 10

        CcPill {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            enabled: page.liveAt(70 + rowH)
            active: Bluetooth.enabled
            icon: Bluetooth.iconName
            title: "Bluetooth"
            subtitle: !Bluetooth.enabled ? "Off"
                : (Bluetooth.connectedName.length > 0 ? Bluetooth.connectedName : "On")
            onClicked: { Bluetooth.scan(); page.drill("bluetooth"); }
        }
        CcPill {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            enabled: page.liveAt(70 + rowH)
            active: PowerProfile.active === "performance"
            icon: "sports_esports"
            title: "Game Mode"
            subtitle: PowerProfile.active === "performance" ? "On" : "Off"
            onClicked: PowerProfile.setProfile(
                PowerProfile.active === "performance" ? "balanced" : "performance")
        }
        CcIconButton {
            active: NightLight.enabled
            icon: NightLight.enabled ? "dark_mode" : "nightlight"
            onClicked: NightLight.toggle()
        }
    }

    CcSliderCard {
        y: 140
        width: parent.width
        label: "Sound"
        icon: Volume.muted ? "volume_off" : (Volume.volumePercent > 50 ? "volume_up" : "volume_down")
        value: Volume.muted ? 0 : Volume.volumePercent / 100
        onMoved: f => Volume.setVolume(f * 100)
        onScrolled: d => Volume.setVolume(
            Math.max(0, Math.min(100, Volume.volumePercent + d * 5)))
        onChevronClicked: page.drill("sound")
    }

    CcSliderCard {
        y: 202
        width: parent.width
        label: "Display"
        icon: "wb_sunny"
        value: Math.max(0.04, Brightness.level / 100)
        onMoved: f => Brightness.setBrightness(Math.round(f * 100))
        onScrolled: d => Brightness.step(d * 5)
        onChevronClicked: page.drill("display")
    }

    Rectangle {
        y: notifTop
        width: parent.width
        height: notifH
        radius: 14
        color: Theme.cc.card
        border.color: Theme.cc.border
        border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Notifications"
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.Medium
                    color: Theme.withAlpha(Theme.colors.text, 0.55)
                    Layout.fillWidth: true
                }
                Label {
                    visible: Notifications.history.length > 0
                    text: "Clear all"
                    font.pixelSize: Theme.px(12)
                    color: Theme.accentFor("control-center")
                    TapHandler { onTapped: Notifications.clearAll() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }

            Label {
                visible: Notifications.history.length === 0
                text: "No notifications"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.35)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.maximumHeight: Config.notifHistoryHeight
                spacing: 6
                visible: Notifications.history.length > 0

                Flickable {
                    id: notifFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: notifList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: notifList
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: Notifications.history
                            delegate: RowLayout {
                                required property var modelData
                                width: notifList.width
                                height: 64
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 4
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: width / 2
                                    color: Theme.accentFor("control-center")
                                    opacity: modelData.urgent ? 1 : 0.35
                                }
                                Icon {
                                    icon: modelData.appIcon || "notifications"
                                    size: 18
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                NotificationText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    summary: modelData.summary
                                    body: modelData.body
                                }
                                Icon {
                                    icon: "close"
                                    size: 14
                                    iconColor: Theme.withAlpha(Theme.colors.text, 0.4)
                                    Layout.alignment: Qt.AlignVCenter
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: Notifications.dismiss(modelData.key) }
                                }
                            }
                        }
                    }
                }

                ScrollRail {
                    flickable: notifFlick
                    accent: Theme.accentFor("control-center")
                }
            }
        }
    }
}
