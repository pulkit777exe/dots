import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"


Rectangle {
    id: mc

    CcTokens { id: cc }


    radius: 15
    property var monitorModel: null


    implicitHeight: mcCol.implicitHeight + 27
    color: cc.bgItem
    border.width: 0

    readonly property real brightness: monitorModel ? monitorModel.brightness : 0
    readonly property string monName: monitorModel ? monitorModel.modelData.name : ""


    readonly property string hostname: {
        const hz = monitorModel ? Brightness.refreshRates[monitorModel.modelData.name] : undefined;
        return (typeof hz === "number" && isFinite(hz) && hz > 0) ? Math.round(hz) + " Hz" : "";
    }


    readonly property real monScale: {
        if (!monitorModel) return 0;
        const probed = Brightness.outputScales[monitorModel.modelData.name];
        if (typeof probed === "number" && probed > 0) return probed;
        const direct = monitorModel.modelData.scale;
        return (typeof direct === "number" && direct > 0) ? direct : 0;
    }

    readonly property string monScaleLabel: monScale > 0
        ? Number(monScale).toFixed(2).replace(/0$/, "") + "x"
        : ""

    readonly property string monDesc: monitorModel ? [
        monitorModel.modelData.width + "×" + monitorModel.modelData.height,
        hostname,
        monScaleLabel
    ].filter(s => s !== "").join("  ·  ") : ""


    readonly property var activeMonitor: Brightness.getMonitor("active")
    readonly property bool focused: !!monitorModel && !!activeMonitor
        && activeMonitor.modelData.name === monitorModel.modelData.name

    ColumnLayout {
        id: mcCol
        anchors { fill: parent; margins: 10 }


        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 10


            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                color: mc.focused ? Theme.colors.accent : cc.bgBadgeDim
                Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
                Icon {
                    anchors.centerIn: parent
                    icon: "monitor"
                    size: 15
                    iconColor: mc.focused ? Theme.colors.accentText : cc.textIcon
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText { text: mc.monName; font.pixelSize: 13; font.weight: Font.DemiBold; color: cc.textPrimary }
                StyledText { text: mc.monDesc; font.pixelSize: 11; color: cc.textDim }
            }

            StyledText {
                visible: mc.focused
                Layout.alignment: Qt.AlignVCenter
                text: "focused"
                font.pixelSize: 11
                color: Theme.colors.accent
            }
        }


        Item {
            id: mcBrightRow
            Layout.fillWidth: true


            Layout.preferredHeight: 26

            Item {
                id: mcTrack
                anchors.left: parent.left
                anchors.right: mcPct.left
                anchors.rightMargin: 17
                anchors.verticalCenter: parent.verticalCenter
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: cc.bgSliderTrackCard
                    clip: true

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, mc.brightness)))
                        radius: parent.radius
                        color: Theme.colors.accent
                        Behavior on width {
                            enabled: !brightMouse.pressed && !MotionConfig.reduceMotion
                            SpringAnimation { spring: 3.6; damping: MotionConfig.springDamping; mass: 0.9 }
                        }
                    }

                    Icon {
                        anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }


                        icon: "wb_sunny"; size: 14; iconColor: cc.onAccent
                    }
                }

                MouseArea {
                    id: brightMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function set(mx) {
                        if (mc.monitorModel)
                            mc.monitorModel.setBrightness(Math.max(0.01, Math.min(1, mx / width)))
                    }
                    onPressed: (e) => set(e.x)
                    onPositionChanged: (e) => { if (pressed) set(e.x) }
                    onWheel: (e) => {
                        if (mc.monitorModel)
                            mc.monitorModel.setBrightness(mc.brightness + (e.angleDelta.y > 0 ? 0.05 : -0.05))
                    }
                }
            }

            StyledText {
                id: mcPct
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(mc.brightness * 100) + "%"
                font.pixelSize: 12
                color: cc.textMedium
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: [1.0, 1.25, 1.5, 1.75, 2.0]

                Rectangle {
                    required property real modelData
                    readonly property bool selected: mc.monitorModel &&
                        mc.monScale > 0 &&
                        Math.abs(mc.monScale - modelData) < 0.05


                    height: 28
                    width: scaleLabel.implicitWidth + 20
                    radius: height / 2
                    color: selected ? Theme.colors.accent : cc.bgPill
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached([
                                "hyprctl", "keyword", "monitor",
                                mc.monName + ",preferred,auto," + modelData
                            ])


                            Brightness.refreshMonitorInfo()
                        }
                    }

                    StyledText {
                        id: scaleLabel
                        anchors.centerIn: parent
                        text: Number(modelData).toFixed(2).replace(/0$/, "") + "x"
                        font.pixelSize: 12; font.weight: Font.Medium
                        color: selected ? Theme.colors.accentText : cc.textStrong
                    }
                }
            }
        }


        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            Layout.leftMargin: 8


            Layout.topMargin: 7

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            RowLayout {
                anchors { fill: parent; rightMargin: 3 }
                StyledText { text: "Resolution"; font.pixelSize: 13; color: cc.textDim }
                Item { Layout.fillWidth: true }
                StyledText {


                    text: mc.monitorModel
                        ? (mc.monitorModel.modelData.width + "×" +
                           mc.monitorModel.modelData.height +
                           (mc.hostname ? " @ " + mc.hostname : ""))
                        : ""
                    font.pixelSize: 13; color: cc.textSub
                }
                Icon { icon: "chevron_right"; size: 14; iconColor: cc.textFaint }
            }
        }
    }
}
