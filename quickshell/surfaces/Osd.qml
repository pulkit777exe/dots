import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// The volume/brightness on-screen display: a bottom-centre pill that pops
// whenever the sink volume or the backlight changes -- keybind, slider,
// anything -- and eases its value bar to the new length before fading out.
//
// It lives in the overlay window but stays out of that window's input
// mask, so it is pure feedback: it can never eat a click. All of its state
// is derived from the services; there is nothing here to keep in sync.

Item {
    id: root

    property bool shown: false
    property string icon: "volume_up"
    property int value: 0

    // The services take a beat to deliver their first reads at shell
    // start; changes inside that window are startup settling, not
    // feedback, and must not pop the pill.
    property bool warmedUp: false

    function show() {
        if (!warmedUp) return;
        shown = true;
        hide.restart();
    }

    function popVolume() {
        icon = Volume.iconName;      // mute/low/high are all in there
        value = Volume.volumePercent;
        show();
    }

    function popBrightness() {
        icon = "wb_sunny";           // the same glyph the CC row uses
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
    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }

    // ---- panel ----------------------------------------------------------------
    // Opacity keeps the window's mask irrelevant either way: hidden means
    // invisible, and invisible means nothing to hit.

    opacity: shown ? 1 : 0
    visible: opacity > 0.005
    implicitWidth: panel.width
    implicitHeight: panel.height
    transform: Translate {
        y: root.shown ? 0 : 12
        Behavior on y {
            NumberAnimation { duration: Config.movement(0.8); easing.type: Easing.OutCubic }
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Config.fade(0.9); easing.type: Easing.OutCubic }
    }

    Surface {
        id: panel
        anchors.centerIn: parent
        width: contentRow.implicitWidth + 44
        height: contentRow.implicitHeight + 26

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 16

            Icon {
                icon: root.icon
                size: 24
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 8
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

                        // The bar is the smooth part: a held key or a drag
                        // retargets this animation instead of jumping.
                        Behavior on width {
                            NumberAnimation { duration: Config.movement(0.6); easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Label {
                text: root.value + "%"
                font.pixelSize: Theme.px(13)
                Layout.preferredWidth: 40
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            }
        }
    }
}
