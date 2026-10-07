import QtQuick
import "../components"
import "../services"

// The island's home: the pill at rest, and the wide panel you get by
// hovering it or by a track loading.
//
// One face, two layouts, chosen by `rich` rather than by two different
// surfaces. That is the point of the merge -- the rest state and the rich
// state are the SAME item at two sizes, so the workspace bars, the clock and
// the status indicators are declared once and simply sit at a different y.
// Two faces would have had to agree on all three of them by hand.
//
// SIZING CONTRACT. This item is NOT the size of the panel. It is anchored
// to fill it, and it reports `implicitWidth`/`implicitHeight`, which are
// computed from its children and from nothing else -- never from `width`
// or `height`, which the panel animates. IslandPanel reads the two
// implicits as its spring targets. Reading `width` here instead would make
// the target depend on the value it is driving.
//
// STACKING CONTRACT. There is exactly one MouseArea in this file and it is
// the LAST child, so it is what the scene finds under the cursor and it
// owns the hover. It also owns every click and routes them by hit-testing
// against the zones below it, rather than putting a MouseArea inside each
// zone: a MouseArea declared before this one would sit underneath it and
// never see a press.
Item {
    id: home

    // Resolved per-monitor bar geometry -- see IslandMetrics.qml.
    property var metrics

    // Which screen this island belongs to, for the workspace indicator.
    property string screenName: ""

    property string currentTime: ""
    property string currentDate: ""

    // ---- geometry --------------------------------------------------------
    //
    // Measured off the reference design and divided through by its 1.8
    // capture scale: the rest pill is 201x30 logical and the rich panel is
    // about 371x76, both with a 16px inner pad.
    readonly property real pad: 16
    readonly property real restGap: 20
    readonly property real richGap: 40
    readonly property real cardWidth: 156
    readonly property real cardHeight: 30
    readonly property real richHeight: 76

    readonly property bool showStatus: BarConfig.statusCircleEnabled
    readonly property bool showCard: BarConfig.albumArtCircleEnabled

    // The now-playing card's inner padding, which is what the "Inner
    // padding" setting has meant since the album-art dot it was written for
    // went away. Three things are positioned from it -- the artwork, the
    // text block and the progress dots -- so it is read once here rather
    // than three times inline, where they could drift apart.
    readonly property real cardPad: BarConfig.innerPadding

    // ---- the hover, and with it the rich state ---------------------------
    //
    // Hovering widens it. Nothing else does.
    //
    // There used to be a second trigger, an active media player, and it was
    // wrong twice. It first read `Media.hasPlayer` -- "some player is
    // registered" -- so an idle browser tab holding a paused video pinned
    // the panel wide for an hour with nothing playing. Narrowing it to
    // `Media.playing` only moved the problem: a background track then held
    // it open for as long as the track ran, which is the same panel that
    // will not go away by a different route.
    //
    // The second trigger is gone rather than narrowed a third time. A card
    // that opens itself is a panel the user has to dismiss instead of one
    // they ask for, and the card is still a single hover from reach -- so
    // the media case is not lost, it is just no longer the thing that
    // decides the bar is open.
    readonly property bool hovered: zone.containsMouse
    readonly property bool rich: hovered

    // ---- what the face is wide enough for -------------------------------

    readonly property real statusWidth: showStatus ? statusZone.width : 0

    // The left column is the wider of the name row and the bar group. For a
    // short workspace name the bars win and the name costs no width at all,
    // which is the common case: `Desktop` is 30px, five bars are 46.
    readonly property real leftWidth: Math.max(nameZone.implicitWidth, bars.implicitWidth)

    readonly property real restWidth: 2 * pad + bars.implicitWidth
        + 2 * restGap + restClock.implicitWidth + statusWidth

    readonly property real richWidth: Math.max(restWidth,
        2 * pad + (showCard ? cardWidth : 0)
        + 2 * (showCard ? richGap : restGap)
        + 2 * Math.max(leftWidth, statusWidth))

    implicitWidth: rich ? richWidth : restWidth
    implicitHeight: rich ? richHeight : metrics.barHeight

    // ---- rest clock ------------------------------------------------------

    Text {
        id: restClock
        // Kept visible even when rich so opacity can fade it out smoothly.
        // Hiding it at opacity 0 lets the fade finish before it leaves the tree.
        visible: true
        opacity: home.rich ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        text: home.currentTime
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Theme.colors.text
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
    }

    // ---- rich header: clock and date, centred as a group -----------------
    //
    // A separate Text pair rather than the same one with an extra child,
    // because a Row that grows and shrinks would drag the clock off centre
    // every time the date became visible.

    Row {
        id: richHeader
        // Like restClock: stays in the tree, fades in/out.
        visible: true
        opacity: home.rich ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        spacing: 8
        x: (parent.width - width) / 2
        y: home.rich ? 12 : (parent.height - height) / 2
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 5.5; damping: 0.68; mass: 0.5 }
        }

        Text {
            text: home.currentTime
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.colors.text
        }

        Text {
            text: home.currentDate
            font.pixelSize: 9
            font.weight: Font.Medium
            color: Theme.withAlpha(Theme.colors.text, 0.55)
        }
    }

    // ---- rich left column: which workspace you are on, and how to leave ---

    Item {
        id: nameZone
        // Fade in/out with the rich state.
        visible: true
        opacity: home.rich ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        implicitWidth: 11 + nameText.implicitWidth
        implicitHeight: Math.max(3, nameText.implicitHeight)
        x: home.pad
        y: home.rich ? 30 : (parent.height - height) / 2
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 5.5; damping: 0.68; mass: 0.5 }
        }

        Rectangle {
            id: bullet
            y: (parent.height - height) / 2
            width: 3
            height: 3
            radius: 1.5
            color: Theme.colors.accent
        }

        Text {
            id: nameText
            x: 11
            y: (parent.height - height) / 2
            text: Workspaces.focusedName
            font.pixelSize: 9
            font.weight: Font.DemiBold
            color: Theme.colors.text
        }
    }

    WorkspaceBars {
        id: bars
        screenName: home.screenName
        x: home.pad
        y: home.rich ? 46 : (parent.height - height) / 2

        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation {
                spring: 5.5
                damping: 0.65
                mass: 0.5
            }
        }
    }

    // ---- the now-playing card -------------------------------------------

    Rectangle {
        id: card
        // Keep in tree so the opacity fade can finish; opacity gates
        // visibility so it draws nothing until the fade-in begins.
        visible: home.showCard
        opacity: home.rich ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
        width: home.cardWidth
        height: home.cardHeight
        radius: 10
        color: Theme.withAlpha(Theme.colors.text, 0.09)
        x: (parent.width - width) / 2
        y: home.rich ? 33 : (parent.height - height) / 2

        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation {
                spring: 5.5
                damping: 0.65
                mass: 0.5
            }
        }

        Rectangle {
            id: art
            x: home.cardPad + 2
            y: (parent.height - height) / 2
            width: 22
            height: 22
            radius: 5
            color: Theme.withAlpha(Theme.colors.text, 0.1)
            clip: true

            Image {
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: Media.artUrl.length > 0
            }

            Icon {
                anchors.centerIn: parent
                icon: "music_note"
                size: 13
                iconColor: Theme.withAlpha(Theme.colors.text, 0.55)
                visible: Media.artUrl.length === 0
            }
        }

        // Stops short of the progress dots rather than running to them, so a
        // long title elides instead of walking into them.
        Column {
            id: textBlock
            x: home.cardPad + 32
            y: (parent.height - height) / 2
            width: home.cardWidth - x - 8 - 42
            spacing: 1

            Text {
                width: parent.width
                text: Media.hasPlayer ? Media.title : "No media"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.colors.text
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                visible: Media.hasPlayer && Media.artist.length > 0
                text: Media.artist
                font.pixelSize: 9
                color: Theme.withAlpha(Theme.colors.text, 0.55)
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Twelve dots at a 3px pitch, filled up to the playhead. A progress
        // BAR would have been two more rectangles at the same width; the dots
        // read as position without implying that dragging them does anything
        // the card does not already offer.
        Row {
            id: dots
            x: home.cardWidth - (home.cardPad + 4) - width
            y: (parent.height - height) / 2
            spacing: 1.5
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

    // ---- status: signal and battery --------------------------------------
    //
    // Pinned to the right pad and centred vertically in the whole face, so
    // the same numbers land at 30 tall and at 76 without a second y.

    Item {
        id: statusZone
        visible: home.showStatus
        width: signal.implicitWidth + 6 + battery.implicitWidth
        height: Math.max(signal.implicitHeight, battery.implicitHeight)
        x: parent.width - home.pad - width
        y: (parent.height - height) / 2

        Row {
            id: statusRow
            spacing: 6

            SignalBars {
                id: signal
                strength: Wifi.enabled && Wifi.connected ? Wifi.strength : 0
            }

            BatteryBadge {
                id: battery
                percentage: Battery.percentage
                charging: Battery.charging
            }
        }
    }

    // ---- the one MouseArea ------------------------------------------------
    //
    // Declared LAST, so the scene finds this under the cursor: it is what
    // reports the hover that widens the face, and it is on top of every
    // zone, so it is also what receives the press.
    //
    // One area rather than one per zone on purpose. Two overlapping
    // MouseAreas do not hand a press down to the one underneath -- a press
    // that the top area does not accept walks up the PARENT chain and is
    // discarded, it never reaches a sibling -- so the zones cannot own their
    // own clicks. This one routes them instead, in the same order the zones
    // are drawn.
    MouseArea {
        id: zone
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (home.showStatus && home.insideZone(statusZone, statusZone.mapFromItem(home, mouse.x, mouse.y))) {
                UiState.toggleControlCenter()
                return
            }
            if (home.showCard && home.rich && home.insideZone(card, card.mapFromItem(home, mouse.x, mouse.y))) {
                UiState.toggleMedia()
                return
            }
            var p = bars.mapFromItem(home, mouse.x, mouse.y)
            if (home.insideZone(bars, p)) {
                var i = bars.indexAt(p.x)
                if (i >= 0) {
                    Workspaces.focus(bars.list[i])
                    return
                }
            }
            UiState.toggleCalendar()
        }
    }

    // A point is in a zone if it is inside that zone's own box. Spelled out
    // once rather than three times, and not called `contains` because Item
    // already answers that name.
    function insideZone(item, p) {
        return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height
    }
}
