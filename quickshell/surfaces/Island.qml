import QtQuick
import "../components"
import "../services"

// The bar: a pill that grows into the "rich" face on hover.
//
// One face at two sizes rather than two panels -- rest is a 33px stadium
// with the workspace dots, clock and status; rich is 76px tall and adds
// the date, the workspace name and the now-playing card. Everything is
// positioned against the root and animated with springs, so the pill
// always grows from its own centre.

Item {
    id: island

    property string screenName: ""

    readonly property bool rich: hover.containsMouse
    readonly property bool showStatus: Config.statusEnabled
    readonly property bool showCard: Config.cardEnabled

    // A popup or an exclusive fullscreen window both take the bar away.
    // Toasts keep it: they are transient shell feedback, and hiding the bar
    // over a fullscreen window while one is on screen is the known case.
    readonly property bool hidden: UiState.anyOpen
        || (Compositor.activeWindowFullscreen && Notifications.toasts.length === 0)

    opacity: hidden ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic }
    }

    // ---- geometry ------------------------------------------------------

    readonly property int richHeight: 76
    readonly property int cardW: 156
    readonly property int cardH: 30
    readonly property int pad: 16
    readonly property int restGap: 20
    readonly property int richGap: 40

    readonly property real leftWidth: Math.max(nameZone.implicitWidth, bars.implicitWidth)
    readonly property real statusWidth: showStatus ? statusRow.implicitWidth : 0

    readonly property real restWidth:
        2 * pad + bars.implicitWidth + 2 * restGap + clock.implicitWidth + statusWidth

    readonly property real richWidth: Math.max(restWidth,
        2 * pad + (showCard ? cardW : 0) + 2 * (showCard ? richGap : restGap)
        + 2 * Math.max(leftWidth, statusWidth))

    width: rich ? richWidth : Math.max(restWidth, Config.collapsedWidth)
    height: rich ? richHeight : Config.barHeight

    // ---- zone motion ---------------------------------------------------
    // A zone sits centred at rest and takes its rich position when open.
    // It gets there by interpolating on the pill's own animated height, not
    // with a second spring: a two-state `y` plus its own spring launched the
    // dots toward y=46 while the pill was still 33px tall, so they overshot
    // outside the panel and wobbled after every hover. Bound this way the
    // zones track the width/height springs exactly, in both directions.

    readonly property real expand:
        (height - Config.barHeight) / (richHeight - Config.barHeight)

    function zoneY(richY, h): real {
        const centred = (height - h) / 2;
        return centred + (richY - centred) * expand;
    }

    Behavior on width {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: 5.8; damping: 0.68; mass: 0.55 }
    }
    Behavior on height {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: 5.8; damping: 0.68; mass: 0.55 }
    }

    // ---- clock ---------------------------------------------------------

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

    // ---- frame -----------------------------------------------------------

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
            SpringAnimation { spring: 5.8; damping: 0.68; mass: 0.55 }
        }
    }

    // ---- zones (rest -> rich; opacity fades, y springs) -------------------

    Label {                              // rest clock, centred
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

    Row {                                // rich header: time + date
        id: header
        spacing: 8
        x: (island.width - width) / 2
        y: island.zoneY(12, height)
        opacity: island.rich ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }

        Label {
            text: island.clockText
            font.pixelSize: Theme.px(12)
            font.weight: Font.DemiBold
            color: Theme.colors.text
        }
        Label {
            text: island.dateText
            font.pixelSize: Theme.px(9)
            font.weight: Font.Medium
            color: Theme.withAlpha(Theme.colors.text, 0.55)
        }
    }

    Item {                               // rich workspace name
        id: nameZone
        x: island.pad
        y: island.zoneY(30, height)
        opacity: island.rich ? 1 : 0
        implicitWidth: 11 + nameText.implicitWidth
        implicitHeight: Math.max(3, nameText.implicitHeight)

        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }

        Rectangle {
            width: 3
            height: 3
            radius: 1.5
            color: Theme.colors.accent
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id: nameText
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            text: Workspaces.focusedName
            font.pixelSize: Theme.px(9)
            font.weight: Font.DemiBold
            color: Theme.colors.text
        }
    }

    WorkspaceBars {                      // dots: x16, centred at rest, y46 rich
        id: bars
        screenName: island.screenName
        x: island.pad
        y: island.zoneY(46, height)
    }

    Item {                               // now-playing card
        id: card
        visible: island.showCard && (island.rich || opacity > 0.01)
        width: island.cardW
        height: island.cardH
        x: (island.width - width) / 2
        y: island.zoneY(33, height)
        opacity: island.rich ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Config.fade(); easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.withAlpha(Theme.colors.text, 0.09)
        }

        Item {                           // album art
            x: Config.cardPad + 2
            y: (card.height - height) / 2
            width: 22
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: 5
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
                size: 13
                iconColor: Theme.withAlpha(Theme.colors.text, 0.55)
            }
        }

        Column {                          // title / artist
            x: Config.cardPad + 32
            width: card.width - x - 50
            spacing: 1
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: Media.hasPlayer ? Media.title : "No media"
                font.pixelSize: Theme.px(11)
                font.weight: Font.DemiBold
                color: Theme.colors.text
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Label {
                width: parent.width
                visible: Media.hasPlayer && Media.artist.length > 0
                text: Media.artist
                font.pixelSize: Theme.px(9)
                color: Theme.withAlpha(Theme.colors.text, 0.55)
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Row {                             // 12-dot progress
            x: card.width - (Config.cardPad + 4) - width
            spacing: 1.5
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.hasPlayer && Media.length > 0

            Repeater {
                model: 12
                delegate: Rectangle {
                    required property int index
                    width: 1.5
                    height: 1.5
                    radius: 0.75
                    color: index < Math.round(Media.progress * 12)
                        ? Theme.colors.accent
                        : Theme.withAlpha(Theme.colors.text, 0.25)
                }
            }
        }
    }

    Row {                                // signal + battery, right edge
        id: statusRow
        spacing: 6
        visible: island.showStatus
        x: island.width - island.pad - width
        y: (island.height - height) / 2

        SignalBars {
            strength: Wifi.enabled && Wifi.connected ? Wifi.strength : 0
        }
        BatteryBadge {
            percentage: Battery.percentage
            charging: Battery.charging
        }
    }

    // ---- input: one area, topmost, routed in paint order -------------------

    function inside(z, px, py): bool {
        return px >= z.x && px < z.x + z.width && py >= z.y && py < z.y + z.height;
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (island.showStatus && island.inside(statusRow, mouse.x, mouse.y)) {
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
