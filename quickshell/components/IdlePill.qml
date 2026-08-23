import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

/**
 * Three-tier idle pill:
 *   minimal -- nothing playing, no hover: just the waveform + clock (Image 14)
 *   peek    -- nothing playing, light hover (~120ms): + wifi, battery,
 *              last-played track, no full expand
 *   full    -- media playing (regardless of hover): art + track + clock +
 *              date + wifi + battery (Image 1/2)
 *
 * Hover-intent (both the peek and full-expand timers) lives in IslandState;
 * this component only reports hover enter/exit.
 */
Rectangle {
    id: root
    implicitWidth: content.implicitWidth + 32
    implicitHeight: Theme.barHeight
    radius: height / 2
    color: Theme.colors.surface
    border.width: 1
    border.color: Qt.lighter(Theme.colors.surface, 1.3)

    Behavior on color { ColorAnimation { duration: Config.animNormal } }
    Behavior on implicitWidth { NumberAnimation { duration: Config.animNormal; easing.type: Easing.OutCubic } }

    property string currentTime: ""
    property string currentDate: ""

    function updateClock() {
        var now = new Date()
        currentTime = Qt.formatTime(now, "h:mm AP")
        currentDate = Qt.formatDate(now, "ddd, MMM d")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateClock()
    }

    Component.onCompleted: updateClock()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: IslandState.onIslandHoverEntered()
        onExited: IslandState.onIslandHoverExited()
    }

    readonly property bool playing: MprisService.playbackStatus === "Playing" || MprisService.playbackStatus === "Paused"
    readonly property bool showPeek: !playing && IslandState.peeking
    readonly property bool showMinimal: !playing && !IslandState.peeking

    // Real ticking phase for the waveform bars -- the previous version used
    // `Math.sin(Date.now() / 200 + ...)` directly in a property binding,
    // which QML evaluates exactly once (Date.now() isn't a bound property,
    // so nothing ever re-triggered it) and the bars were frozen at whatever
    // value they got on first render, not animating at all.
    property real animPhase: 0
    Timer {
        interval: 100
        running: root.showMinimal
        repeat: true
        onTriggered: root.animPhase += 0.3
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 12

        // -- Minimal (Image 14): waveform bars + time only --
        RowLayout {
            visible: root.showMinimal
            spacing: 8

            Row {
                spacing: 2
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: 2
                        property real barHeight: 4 + Math.sin(root.animPhase + index * 1.2) * 4
                        height: Math.max(2, barHeight)
                        radius: 1
                        color: Theme.colors.accent
                    }
                }
            }

            Text {
                text: root.currentTime
                color: Theme.colors.text
                font.pixelSize: Theme.fontSize + 6
                font.bold: true
            }
        }

        // -- Peek (light hover, nothing playing): wifi + battery +
        // last-played + clock, no art, no full expand --
        RowLayout {
            visible: root.showPeek
            spacing: 10

            ColumnLayout {
                spacing: 0
                visible: MprisService.title !== ""
                Text {
                    text: MprisService.title
                    color: Theme.colors.textMuted
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    Layout.maximumWidth: Theme.fontSize * 8
                }
                Text {
                    text: MprisService.artist
                    color: Theme.colors.textMuted
                    font.pixelSize: Theme.fontSize - 4
                    elide: Text.ElideRight
                    Layout.maximumWidth: Theme.fontSize * 8
                }
            }
            Rectangle {
                width: 1; height: Theme.barHeight * 0.5; color: Theme.colors.surfaceHover
                visible: MprisService.title !== ""
            }

            Text {
                text: root.currentTime
                color: Theme.colors.text
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }

            Text {
                text: NetworkService.wifiEnabled ? Config.wifiIcon(80) : Config.iconWifiOff
                color: NetworkService.wifiEnabled ? Theme.colors.accent : Theme.colors.textMuted
                font.family: Config.iconFontFamily
                font.pixelSize: Theme.fontSize
            }
            RowLayout {
                spacing: 4
                Text {
                    text: Config.batteryIcon(UPowerService.percentage, UPowerService.charging)
                    color: UPowerService.low ? Theme.colors.danger : Theme.colors.accent
                    font.family: Config.iconFontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    text: UPowerService.percentage + "%"
                    color: UPowerService.low ? Theme.colors.danger : Theme.colors.textMuted
                    font.pixelSize: Theme.fontSize - 3
                    visible: UPowerService.available
                }
            }
        }

        // -- Full (Image 1/2): art + track + clock + date + icons --
        RowLayout {
            visible: root.playing
            spacing: 12

            RowLayout {
                spacing: 8
                Rectangle {
                    width: Theme.barHeight - 14
                    height: width
                    radius: 6
                    color: Theme.colors.surfaceHover
                    Image {
                        anchors.fill: parent
                        source: MprisService.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: MprisService.artUrl !== ""
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: MprisService.title
                        color: Theme.colors.text
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: Theme.fontSize * 9
                    }
                    Text {
                        text: MprisService.artist
                        color: Theme.colors.textMuted
                        font.pixelSize: Theme.fontSize - 3
                        elide: Text.ElideRight
                        Layout.maximumWidth: Theme.fontSize * 9
                    }
                }
            }

            Rectangle { width: 1; height: Theme.barHeight * 0.5; color: Theme.colors.surfaceHover }

            ColumnLayout {
                spacing: 0
                Text {
                    text: root.currentTime
                    color: Theme.colors.text
                    font.pixelSize: Theme.fontSize + 6
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.currentDate
                    color: Theme.colors.textMuted
                    font.pixelSize: Theme.fontSize - 4
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Rectangle { width: 1; height: Theme.barHeight * 0.5; color: Theme.colors.surfaceHover }

            RowLayout {
                spacing: 8
                Text {
                    text: NetworkService.wifiEnabled ? Config.wifiIcon(80) : Config.iconWifiOff
                    color: NetworkService.wifiEnabled ? Theme.colors.accent : Theme.colors.textMuted
                    font.family: Config.iconFontFamily
                    font.pixelSize: Theme.fontSize
                }
                RowLayout {
                    spacing: 4
                    Text {
                        text: Config.batteryIcon(UPowerService.percentage, UPowerService.charging)
                        color: UPowerService.low ? Theme.colors.danger : Theme.colors.accent
                        font.family: Config.iconFontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Text {
                        text: UPowerService.percentage + "%"
                        color: UPowerService.low ? Theme.colors.danger : Theme.colors.textMuted
                        font.pixelSize: Theme.fontSize - 3
                        visible: UPowerService.available
                    }
                }
            }
        }
    }
}
