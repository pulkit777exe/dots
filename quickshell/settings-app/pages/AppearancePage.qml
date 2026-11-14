import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["appearance", "theme", "wallpaper",
        "accent", "colour", "color", "font", "size", "type", "burst"]

    readonly property var accentSwatches: ["", "#3ed0af", "#eb6f65", "#a7c080",
                                           "#e5c07b", "#7aa2f7", "#d38aea", "#7dcfff"]
    readonly property color baseAccent: (Theme.current && Theme.current.colors && Theme.current.colors.accent)
        ? Theme.current.colors.accent : Theme.fallbackColors.accent

    SettingsHeader {
        icon: "palette"
        title: "Appearance"
        subtitle: "Theme, wallpaper, accent, and type."
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: "Theme — " + Theme.displayName
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
                elide: Text.ElideRight
            }
            StyledButton { label: "Change"; accent: Theme.accentFor("settings"); onClicked: UiState.toggleThemePicker() }
        }

        SettingsDivider {}

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: "Wallpaper"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
                elide: Text.ElideRight
            }
            StyledButton { label: "Choose"; accent: Theme.accentFor("settings"); onClicked: UiState.toggleWallpaperPicker() }
        }
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: "Accent colour"
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.9)
            }

            Row {
                spacing: 6

                Repeater {
                    model: root.accentSwatches

                    Rectangle {
                        id: swatch
                        required property var modelData

                        width: 24
                        height: 24
                        radius: 12
                        color: "transparent"
                        border.width: Config.accentOverride === modelData ? 2 : 0
                        border.color: Theme.accentFor("settings")

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            radius: 8
                            color: swatch.modelData === "" ? root.baseAccent : swatch.modelData
                            border.width: swatch.modelData === "" ? 1 : 0
                            border.color: Theme.withAlpha(Theme.colors.text, 0.25)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.set("accentOverride", swatch.modelData);
                                Theme.publish(Theme.currentName);
                            }
                        }
                    }
                }
            }
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Font size"
            value: Config.fontSize
            from: 11; to: 20; suffix: " px"
            onMoved: (v) => Config.set("fontSize", Math.round(v))
        }

        SettingsDivider {}

        SettingsToggleRow {
            label: "Colour burst (a different accent per surface)"
            checked: Config.colorBurst
            onToggled: (v) => Config.set("colorBurst", v)
        }
    }
}
