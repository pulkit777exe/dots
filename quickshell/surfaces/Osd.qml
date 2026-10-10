import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

Item {
    id: root

    property bool shown: false
    property string icon: "volume_up"
    property int value: 0

    property bool warmedUp: false

    function show() {
        if (!warmedUp) return;
        shown = true;
        hide.restart();
    }

    function popVolume() {
        icon = Volume.iconName;
        value = Volume.volumePercent;
        show();
    }

    function popBrightness() {
        icon = "wb_sunny";
        value = Brightness.level;
        show();
    }

    Connections {
        target: Volume
        function onVolumeChanged() { root.popVolume(); }
        function onMutedChanged() { root.popVolume(); }
    }

    Connections {
        target: Brightness
        function onLevelChanged() { root.popBrightness(); }
    }

    Timer { id: warmup; interval: 750; onTriggered: root.warmedUp = true }
    Component.onCompleted: warmup.start()
    Timer { id: hide; interval: Config.osdTimeoutMs; onTriggered: root.shown = false }

    opacity: shown ? 1 : 0
    visible: opacity > 0.005
    implicitWidth: panel.width
    implicitHeight: panel.height
    transform: Translate {
        y: root.shown ? 0 : 12
        Behavior on y {
            NumberAnimation { duration: Config.movement(0.8); easing.type: Easing.OutQuint }
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Config.fade(0.9); easing.type: Easing.OutCubic }
    }

    Surface {
        id: panel
        anchors.centerIn: parent
        width: contentRow.implicitWidth + 40
        height: contentRow.implicitHeight + 12
        cornerRadius: 18

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 24

            Icon {
                icon: root.icon
                size: 24
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.preferredWidth: 216
                Layout.preferredHeight: Config.osdBarThickness
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.cc.track

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
                        height: parent.height
                        radius: height / 2
                        color: Theme.accentFor("osd")

                        Behavior on width {
                            NumberAnimation { duration: Config.movement(0.6); easing.type: Easing.OutQuint }
                        }
                    }
                }
            }

            Label {
                text: root.value + "%"
                font.pixelSize: Theme.px(13)
                Layout.preferredWidth: 56
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            }
        }
    }
}
