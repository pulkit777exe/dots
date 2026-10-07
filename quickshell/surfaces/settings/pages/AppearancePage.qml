import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "palette"
        title: "Appearance"
        subtitle: "Theme, wallpaper, fonts, corners, and surface depth."
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            StyledText { Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.DemiBold; text: "Theme" }
            RowLayout {
                spacing: 4
                StyledText { font.pixelSize: 12; color: Theme.withAlpha(Theme.colors.text, 0.6); text: Theme.displayName || Theme.currentName }
                Icon { icon: "chevron_right"; size: 16; iconColor: Theme.withAlpha(Theme.colors.text, 0.4) }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: UiState.toggleThemePicker() }
        }

        SettingsDivider {}

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            StyledText { Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.DemiBold; text: "Wallpaper" }
            RowLayout {
                spacing: 4
                StyledText { font.pixelSize: 12; color: Theme.withAlpha(Theme.colors.text, 0.6); text: "Choose..." }
                Icon { icon: "chevron_right"; size: 16; iconColor: Theme.withAlpha(Theme.colors.text, 0.4) }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: UiState.toggleWallpaperPicker() }
        }
    }

    SettingsSectionLabel {
        label: "Accent"
    }

    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            StyledText { Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.DemiBold; text: "Accent colour" }

            Row {
                spacing: 8
                Repeater {
                    model: ["#3ed0af", "#eb6f65", "#a7c080", "#e5c07b", "#7aa2f7", "#d38aea", "#7dcfff"]
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: 20
                        height: 20
                        radius: 10
                        color: modelData

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: "#101010"
                            visible: index === 0
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {}
                    }
                }
            }
        }

        SettingsDivider {}

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            StyledText { Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.DemiBold; text: "Custom (#rrggbb)" }
            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 28
                radius: 6
                color: Theme.colors.surfaceAlt
                border.width: 1
                border.color: Theme.withAlpha(Theme.colors.text, 0.08)
                TextInput {
                    anchors.fill: parent
                    anchors.margins: 4
                    anchors.leftMargin: 8
                    font.pixelSize: 12
                    color: Theme.colors.text
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                }
            }
        }

        SettingsDivider {}

        SettingsToggleRow {
            label: "Color burst (a different palette colour per surface)"
            checked: false
        }
    }

    SettingsSectionLabel {
        label: "Type"
    }

    SettingsCard {
        SettingsSliderRow {
            label: "Font size"
            value: 15
            from: 11; to: 20; suffix: " px"
        }
    }
}
