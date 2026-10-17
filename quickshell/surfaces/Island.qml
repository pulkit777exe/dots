import QtQuick
import "../components"
import "../services"

Item {
    id: island

    readonly property bool rich: hover.containsMouse
    readonly property bool showStatus: Config.statusEnabled
    readonly property bool showCard: Config.cardEnabled

    readonly property bool hidden: Compositor.activeWindowFullscreen && Notifications.toasts.length === 0

    opacity: hidden ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic }
    }

    readonly property int richHeight: 96
    readonly property int cardW: 300
    readonly property int cardH: 46
    readonly property int pad: 16
    readonly property int restGap: 20
    readonly property int richGap: 40

    readonly property real leftWidth: Math.max(nameZone.implicitWidth, bars.implicitWidth)
    readonly property real statusWidth: showStatus
        ? (rich ? statusCol.width : badgeRow.implicitWidth) : 0

    readonly property real restWidth:
        2 * pad + bars.implicitWidth + 2 * restGap + clock.implicitWidth + statusWidth

    readonly property real richWidth: Math.max(restWidth,
        2 * pad + (showCard ? cardW : 0) + 2 * (showCard ? richGap : restGap)
        + 2 * Math.max(leftWidth, statusWidth))

    width: rich ? richWidth : Math.max(restWidth, Config.collapsedWidth)
    height: rich ? richHeight : Config.barHeight

    readonly property real expand:
        (height - Config.barHeight) / (richHeight - Config.barHeight)

    function zoneY(richY, h): real {
        const centred = (height - h) / 2;
        return centred + (richY - centred) * expand;
    }

    Behavior on width {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: 5.8; damping: Config.springDamping; mass: 0.55 }
    }
    Behavior on height {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: 5.8; damping: Config.springDamping; mass: 0.55 }
    }

    readonly property string timeFormat: Config.time24h
        ? (Config.showSeconds ? "hh:mm:ss" : "hh:mm")
        : (Config.showSeconds ? "h:mm:ss AP" : "h:mm AP")
    property string clockText: Qt.formatTime(new Date(), timeFormat)
    property string dateText: Qt.formatDate(new Date(), "ddd, MMM d")

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            island.clockText = Qt.formatTime(new Date(), island.timeFormat);
            island.dateText = Qt.formatDate(new Date(), "ddd, MMM d");
        }
    }

    Surface {
        anchors.fill: parent
        readonly property real effRadius: Math.min(Config.collapsedRadius, Config.barHeight / 2)
        cornerRadius: effRadius
        topLeftRadius: Config.notchMode ? 0 : effRadius
        topRightRadius: Config.notchMode ? 0 : effRadius
        backgroundColor: Theme.colors.background
        shadow: island.rich

        Behavior on cornerRadius {
            enabled: !Config.reduceMotion
            SpringAnimation { spring: 5.8; damping: Config.springDamping; mass: 0.55 }
        }
    }

    // Collapsed chrome.
    Label {
        id: clock
        text: island.clockText
        font.pixelSize: Theme.px(14)
        font.weight: Font.DemiBold
        color: Theme.colors.text
        x: (island.width - width) / 2
        y: (island.height - height) / 2
        opacity: island.rich ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }
    }

    // Header: clock + date, top centre.
    Row {
        id: header
        spacing: 8
        x: (island.width - width) / 2
        y: island.zoneY(16, height)
        opacity: island.rich ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }

        Label {
            id: clockLabel
            text: island.clockText
            font.pixelSize: Theme.px(18)
            font.weight: Font.DemiBold
            color: Theme.colors.text
        }
        Label {
            text: island.dateText
            font.pixelSize: Theme.px(12)
            font.weight: Font.Medium
            color: Theme.withAlpha(Theme.colors.text, 0.55)
            y: (clockLabel.implicitHeight - implicitHeight) / 2
        }
    }

    Item {
        id: nameZone
        x: island.pad
        y: island.zoneY(18, height)
        opacity: island.rich ? 1 : 0
        implicitWidth: 11 + nameText.implicitWidth
        implicitHeight: Math.max(4, nameText.implicitHeight)

        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }

        Rectangle {
            width: 4
            height: 4
            radius: 2
            color: Theme.accentFor("island")
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id: nameText
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            text: Workspaces.focusedName
            font.pixelSize: Theme.px(12)
            font.weight: Font.DemiBold
            color: Theme.colors.text
        }
    }

    WorkspaceBars {
        id: bars
        accent: Theme.accentFor("island")
        x: island.pad
        y: island.zoneY(40, height)
    }

    Item {
        id: card
        visible: island.showCard && (island.rich || opacity > 0.01)
        width: island.cardW
        height: island.cardH
        x: (island.width - width) / 2
        y: island.zoneY(46, height)
        opacity: island.rich ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.withAlpha(Theme.colors.text, 0.09)
        }

        Item {
            x: 8
            y: (card.height - height) / 2
            width: 34
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.withAlpha(Theme.colors.text, 0.10)
                clip: true

                Image {
                    anchors.fill: parent
                    visible: Media.artUrl.length > 0
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
            }
            Icon {
                anchors.centerIn: parent
                visible: Media.artUrl.length === 0
                icon: "music_note"
                size: 16
                iconColor: Theme.withAlpha(Theme.colors.text, 0.55)
            }
        }

        Column {
            x: 52
            width: card.width - x - dots.width - 18
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: Media.hasPlayer ? Media.title : "No media"
                font.pixelSize: Theme.px(13)
                font.weight: Font.DemiBold
                color: Theme.colors.text
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Label {
                width: parent.width
                visible: Media.hasPlayer && Media.artist.length > 0
                text: Media.artist
                font.pixelSize: Theme.px(10)
                color: Theme.withAlpha(Theme.colors.text, 0.55)
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Row {
            id: dots
            x: card.width - 12 - width
            spacing: 2.5
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.hasPlayer && Media.length > 0

            Repeater {
                model: 14
                delegate: Rectangle {
                    required property int index
                    width: 2
                    height: 2
                    radius: 1
                    color: index < Math.round(Media.progress * 14)
                        ? Theme.accentFor("island")
                        : Theme.withAlpha(Theme.colors.text, 0.25)
                }
            }
        }
    }

    // Right column: notification status over the signal/battery badges.
    Column {
        id: statusCol
        visible: island.showStatus
        width: Math.max(notifRow.implicitWidth, badgeRow.implicitWidth)
        spacing: 6
        x: island.width - island.pad - width
        y: island.zoneY(18, height)

        Row {
            id: notifRow
            x: statusCol.width - width
            spacing: 6
            visible: island.rich
            opacity: island.rich ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }

            Label {
                text: Notifications.history.length === 0
                    ? "All caught up"
                    : Notifications.history.length + " new"
                font.pixelSize: Theme.px(12)
                font.weight: Font.Medium
                color: Theme.colors.text
            }
            Icon {
                icon: Notifications.dnd ? "do_not_disturb_on" : "notifications"
                size: 15
                iconColor: Theme.withAlpha(Theme.colors.text, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            id: badgeRow
            x: statusCol.width - width
            spacing: 8

            SignalBars {
                accent: Theme.accentFor("island")
                strength: Wifi.enabled && Wifi.connected ? Wifi.strength : 0
            }
            BatteryBadge {
                accent: Theme.accentFor("island")
                percentage: Battery.percentage
                charging: Battery.charging
            }
        }
    }

    function inside(z, px, py): bool {
        return px >= z.x && px < z.x + z.width && py >= z.y && py < z.y + z.height;
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (island.showStatus && island.inside(statusCol, mouse.x, mouse.y)) {
                UiState.toggleControlCenter();
            } else if (island.rich && island.showCard && island.inside(card, mouse.x, mouse.y)) {
                Media.togglePlay();
            } else if (island.inside(bars, mouse.x, mouse.y)) {
                const i = bars.indexAt(mouse.x - bars.x);
                if (i >= 0) bars.focusSlot(i);
            }
        }
    }
}
