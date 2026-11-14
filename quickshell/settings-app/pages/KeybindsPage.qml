import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["keybinds", "keyboard", "shortcuts",
        "hotkeys", "bindings", "keys", "workspace", "screenshot", "media",
        "window", "launcher", "terminal", "lock"]

    property string filter: ""

    readonly property var groups: [
        {
            name: "Applications", icon: "apps",
            binds: [
                { keys: "SUPER + Return", action: "Open terminal" },
                { keys: "SUPER + /", action: "Open launcher" },
                { keys: "SUPER + D", action: "Open launcher" },
                { keys: "SUPER + N", action: "Open control center" },
                { keys: "SUPER + S", action: "Open settings" },
                { keys: "SUPER + T", action: "Open theme picker" },
                { keys: "SUPER + W", action: "Open wallpaper picker" },
                { keys: "SUPER + C", action: "Open clipboard" },
                { keys: "SUPER + SHIFT + L", action: "Open power menu" },
                { keys: "SUPER + Escape", action: "Close all overlays" },
            ]
        },
        {
            name: "Navigation", icon: "open_with",
            binds: [
                { keys: "SUPER + ← ↑ ↓ →", action: "Focus window in direction" },
                { keys: "SUPER + SHIFT + ← ↑ ↓ →", action: "Move window in direction" },
                { keys: "SUPER + ALT + ← ↑ ↓ →", action: "Swap window in direction" },
                { keys: "ALT + Tab", action: "Cycle to next window" },
                { keys: "ALT + SHIFT + Tab", action: "Cycle to previous window" },
                { keys: "SUPER + 1 … 0", action: "Focus workspace" },
                { keys: "SUPER + SHIFT + 1 … 0", action: "Move window to workspace" },
            ]
        },
        {
            name: "Windows", icon: "window",
            binds: [
                { keys: "SUPER + V", action: "Toggle floating" },
                { keys: "SUPER + F", action: "Toggle fullscreen" },
                { keys: "SUPER + SHIFT + V", action: "Toggle pseudo-tiling" },
                { keys: "SUPER + CTRL + ← ↑ ↓ →", action: "Resize window" },
                { keys: "SUPER + drag left", action: "Move window" },
                { keys: "SUPER + drag right", action: "Resize window" },
                { keys: "SUPER + Q", action: "Close window" },
            ]
        },
        {
            name: "Screenshots", icon: "screenshot_monitor",
            binds: [
                { keys: "Print", action: "Capture area" },
                { keys: "SHIFT + Print", action: "Capture active window" },
                { keys: "CTRL + Print", action: "Capture full output" },
            ]
        },
        {
            name: "Media & brightness", icon: "volume_up",
            binds: [
                { keys: "Volume Up / Down", action: "Adjust output volume" },
                { keys: "Volume Mute", action: "Mute output" },
                { keys: "Mic Mute", action: "Mute microphone" },
                { keys: "Play / Next / Previous", action: "Control media" },
                { keys: "Brightness Up / Down", action: "Adjust brightness" },
            ]
        },
        {
            name: "System", icon: "settings",
            binds: [
                { keys: "SUPER + L", action: "Lock screen" },
                { keys: "SUPER + R", action: "Reload desktop" },
            ]
        },
    ]

    readonly property var filtered: {
        const q = filter.trim().toLowerCase();
        const out = [];
        for (const group of groups) {
            const binds = q.length === 0 ? group.binds
                : group.binds.filter(b => b.keys.toLowerCase().includes(q)
                    || b.action.toLowerCase().includes(q));
            if (binds.length > 0)
                out.push({ name: group.name, icon: group.icon, binds: binds });
        }
        return out;
    }

    SettingsHeader {
        icon: "keyboard"
        title: "Keybinds"
        subtitle: "Every shortcut available in this desktop."
    }

    SettingsCard {
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.preferredHeight: 38
            radius: 10
            color: Theme.withAlpha(Theme.colors.text, 0.07)
            border.color: keyFilter.activeFocus ? Theme.accentFor("settings")
                                               : Theme.withAlpha(Theme.colors.text, 0.12)
            border.width: 1

            TextField {
                id: keyFilter
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                textSize: 13
                onTextChanged: root.filter = text
            }

            Label {
                anchors.fill: parent
                anchors.leftMargin: 12
                verticalAlignment: Text.AlignVCenter
                visible: keyFilter.text.length === 0
                text: "Filter shortcuts"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.35)
            }
        }
    }

    Repeater {
        model: root.filtered

        SettingsCard {
            id: groupCard
            required property var modelData

            SettingsLabelRow { label: groupCard.modelData.name }

            Repeater {
                model: groupCard.modelData.binds

                Item {
                    id: bindRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: Math.max(150, keysLabel.implicitWidth + 20)
                            Layout.preferredHeight: 26
                            radius: 7
                            color: Theme.withAlpha(Theme.colors.text, 0.07)

                            Label {
                                id: keysLabel
                                anchors.centerIn: parent
                                text: bindRow.modelData.keys
                                font.family: "monospace"
                                font.pixelSize: Theme.px(11)
                                color: Theme.withAlpha(Theme.colors.text, 0.82)
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: bindRow.modelData.action
                            font.pixelSize: Theme.px(13)
                            color: Theme.withAlpha(Theme.colors.text, 0.72)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.filtered.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: "No shortcuts match"
        font.pixelSize: Theme.px(12)
        color: Theme.withAlpha(Theme.colors.text, 0.4)
    }
}
