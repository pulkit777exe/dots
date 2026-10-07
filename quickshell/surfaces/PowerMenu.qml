import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// One row of five tiles; Reboot and Power Off ask twice before acting.

PopupPanel {
    id: root

    open: UiState.powerMenuOpen

    readonly property real tileWidth: 90
    readonly property real tileHeight: 81
    readonly property real tileSpacing: 8
    readonly property real containerPadding: 2

    implicitWidth: 5 * tileWidth + 4 * tileSpacing + 2 * containerPadding
    implicitHeight: tileHeight + 2 * containerPadding
    cornerRadius: 24
    backgroundColor: Theme.colors.background

    component PowerTile: Item {
        id: tile

        property string icon: ""
        property string label: ""
        property bool primary: false
        property bool needsConfirm: false
        signal activated()

        readonly property bool confirming: needsConfirm && confirmTimer.running
        readonly property bool isHovered: hover.hovered

        implicitWidth: root.tileWidth
        implicitHeight: root.tileHeight
        transformOrigin: Item.Center
        scale: tap.pressed ? 0.94 : (isHovered ? 1.03 : 1.0)
        Behavior on scale {
            enabled: !Config.reduceMotion
            SpringAnimation { spring: 5; damping: Config.springDamping; mass: 0.5 }
        }

        Timer { id: confirmTimer; interval: 3000 }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: tile.confirming ? Theme.colors.danger
                : tile.primary ? Theme.colors.accent
                : tile.isHovered ? Qt.lighter(Theme.colors.surface, 1.25)
                : Theme.colors.surface
            Behavior on color { ColorAnimation { duration: Config.hover() } }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: tile.confirming ? "warning" : tile.icon
                size: 22
                iconColor: (tile.primary || tile.confirming) ? Theme.colors.accentText
                                                             : Theme.withAlpha(Theme.colors.text, 0.9)
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: tile.confirming ? "Confirm?" : tile.label
                font.pixelSize: Theme.px(12)
                font.weight: tile.primary ? Font.DemiBold : Font.Medium
                color: (tile.primary || tile.confirming) ? Theme.colors.accentText
                                                         : Theme.withAlpha(Theme.colors.text, 0.88)
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: tap
            onTapped: {
                if (!tile.needsConfirm) {
                    tile.activated();
                    return;
                }
                if (tile.confirming) {
                    confirmTimer.stop();
                    tile.activated();
                } else {
                    confirmTimer.restart();
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.containerPadding
        spacing: root.tileSpacing

        PowerTile {
            icon: "lock"
            label: "Lock"
            onActivated: { Power.lock(); UiState.closeAll(); }
        }
        PowerTile {
            icon: "bedtime"
            label: "Suspend"
            onActivated: { Power.suspend(); UiState.closeAll(); }
        }
        PowerTile {
            icon: "logout"
            label: "Log Out"
            onActivated: { Power.logOut(); UiState.closeAll(); }
        }
        PowerTile {
            icon: "refresh"
            label: "Reboot"
            needsConfirm: true
            onActivated: { Power.reboot(); UiState.closeAll(); }
        }
        PowerTile {
            icon: "power_settings_new"
            label: "Power Off"
            primary: true
            needsConfirm: true
            onActivated: { Power.powerOff(); UiState.closeAll(); }
        }
    }
}
