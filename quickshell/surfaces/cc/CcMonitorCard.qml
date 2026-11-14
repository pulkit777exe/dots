import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Rectangle {
    id: card

    property var monitor: null

    radius: 15
    color: Theme.cc.item
    implicitHeight: col.implicitHeight + 20

    readonly property string name: monitor ? monitor.name : ""
    readonly property real brightness: monitor
        ? Brightness.monitorBrightness(monitor.name) / 100 : 0
    readonly property real monScale: monitor && monitor.scale > 0 ? monitor.scale : 1
    readonly property string currentMode: {
        if (!monitor) return "preferred";
        if (Config.monitors && Config.monitors[name] && Config.monitors[name].mode)
            return Config.monitors[name].mode;
        return monitor.width + "x" + monitor.height + "@" + Math.round(monitor.hz || 0) + ".00Hz";
    }
    readonly property int currentTransform: {
        if (Config.monitors && Config.monitors[name] && Config.monitors[name].transform !== undefined)
            return Number(Config.monitors[name].transform) || 0;
        return 0;
    }

    function shortMode(mode) {
        return String(mode).replace(".00Hz", "Hz");
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 10 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: card.monitor && card.monitor.focused
                    ? Theme.accentFor("control-center") : Theme.withAlpha(Theme.colors.text, 0.20)
                Behavior on color { ColorAnimation { duration: Config.hover() } }

                Icon {
                    anchors.centerIn: parent
                    icon: "monitor"
                    size: 15
                    iconColor: card.monitor && card.monitor.focused
                        ? Theme.colors.accentText : Theme.withAlpha(Theme.colors.text, 0.85)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: card.name
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.Bold
                    color: Theme.colors.text
                }
                Label {
                    text: card.monitor
                        ? card.monitor.width + "×" + card.monitor.height
                          + (card.monitor.hz > 0 ? "  ·  " + Math.round(card.monitor.hz) + " Hz" : "")
                        : ""
                    font.pixelSize: Theme.px(11)
                    color: Theme.withAlpha(Theme.colors.text, 0.48)
                }
            }

            Label {
                visible: card.monitor && card.monitor.focused
                text: "focused"
                font.pixelSize: Theme.px(11)
                color: Theme.accentFor("control-center")
            }
        }

        CcDeviceSlider {
            Layout.fillWidth: true
            icon: "wb_sunny"
            trackColor: Theme.cc.trackCard
            value: card.brightness
            onMoved: f => Brightness.setMonitorBrightness(card.name, f * 100)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                text: "Scale"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }

            Flow {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: [1.0, 1.25, 1.5, 1.75, 2.0]

                    Rectangle {
                        required property real modelData
                        readonly property bool selected:
                            Math.abs(card.monScale - modelData) < 0.05

                        height: 28
                        width: scaleLabel.implicitWidth + 20
                        radius: height / 2
                        color: selected ? Theme.accentFor("control-center")
                            : (scaleArea.containsMouse ? Theme.cc.itemHover
                               : Theme.withAlpha(Theme.colors.text, 0.12))
                        Behavior on color { ColorAnimation { duration: Config.hover() } }

                        Label {
                            id: scaleLabel
                            anchors.centerIn: parent
                            text: Number(modelData).toFixed(2).replace(/0$/, "") + "x"
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.DemiBold
                            color: selected ? Theme.colors.accentText
                                : Theme.withAlpha(Theme.colors.text, 0.70)
                        }
                        MouseArea {
                            id: scaleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Brightness.setMonitorConfig(card.name, { scale: modelData })
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: card.monitor && card.monitor.modes && card.monitor.modes.length > 0

            Label {
                text: "Resolution / refresh"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }

            Flow {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: {
                        const modes = ["preferred"];
                        if (card.monitor && card.monitor.modes)
                            for (const m of card.monitor.modes)
                                if (modes.indexOf(m) < 0) modes.push(m);
                        return modes.slice(0, 9);
                    }

                    Rectangle {
                        required property var modelData
                        readonly property bool selected: {
                            if (String(modelData) === "preferred")
                                return !Config.monitors || !Config.monitors[card.name]
                                    || !Config.monitors[card.name].mode
                                    || Config.monitors[card.name].mode === "preferred";
                            return String(modelData) === String(card.currentMode)
                                || (Config.monitors && Config.monitors[card.name]
                                    && Config.monitors[card.name].mode === String(modelData));
                        }

                        height: 28
                        width: modeLabel.implicitWidth + 18
                        radius: height / 2
                        color: selected ? Theme.accentFor("control-center")
                            : (modeArea.containsMouse ? Theme.cc.itemHover
                               : Theme.withAlpha(Theme.colors.text, 0.12))
                        Behavior on color { ColorAnimation { duration: Config.hover() } }

                        Label {
                            id: modeLabel
                            anchors.centerIn: parent
                            text: String(modelData) === "preferred" ? "Preferred" : card.shortMode(modelData)
                            font.pixelSize: Theme.px(11)
                            font.weight: selected ? Font.DemiBold : Font.Normal
                            color: selected ? Theme.colors.accentText
                                : Theme.withAlpha(Theme.colors.text, 0.70)
                        }
                        MouseArea {
                            id: modeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Brightness.setMonitorConfig(card.name, { mode: String(modelData) })
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                text: "Rotation"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }

            Flow {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: [
                        { value: 0, label: "Normal" },
                        { value: 1, label: "90°" },
                        { value: 2, label: "180°" },
                        { value: 3, label: "270°" }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property bool selected: Number(modelData.value) === card.currentTransform

                        height: 28
                        width: rotLabel.implicitWidth + 18
                        radius: height / 2
                        color: selected ? Theme.accentFor("control-center")
                            : (rotArea.containsMouse ? Theme.cc.itemHover
                               : Theme.withAlpha(Theme.colors.text, 0.12))
                        Behavior on color { ColorAnimation { duration: Config.hover() } }

                        Label {
                            id: rotLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.px(11)
                            font.weight: selected ? Font.DemiBold : Font.Normal
                            color: selected ? Theme.colors.accentText
                                : Theme.withAlpha(Theme.colors.text, 0.70)
                        }
                        MouseArea {
                            id: rotArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Brightness.setMonitorConfig(card.name, { transform: Number(modelData.value) })
                        }
                    }
                }
            }
        }
    }
}
