import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "palette"
        title: "Appearance & Themes"
        subtitle: "Theme presets, wallpaper picker, surface glass opacity, and geometry."
    }

    
    Surface {
        Layout.fillWidth: true
        implicitHeight: 110
        cornerRadius: 14
        backgroundColor: Theme.colors.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.DemiBold; text: "Theme Preset" }
                StyledText { font.pixelSize: 12; textColor: Theme.colors.accent; text: Theme.displayName }
                IconButton { icon: "chevron_right"; size: 28; iconSize: 16; onClicked: UiState.toggleThemePicker() }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

            RowLayout {
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.DemiBold; text: "Wallpaper" }
                StyledText { font.pixelSize: 12; textColor: Theme.colors.accent; text: Theme.currentWallpaper.length > 0 ? "Active" : "None" }
                IconButton { icon: "chevron_right"; size: 28; iconSize: 16; onClicked: UiState.toggleWallpaperPicker() }
            }
        }
    }

    
    SettingsSliderRow {
        label: "Surface Glass Opacity"
        value: ConfigStore.glassOpacity * 100
        from: 60; to: 100; suffix: " %"
        onMoved: (v) => ConfigStore.setGlassOpacity(v / 100)
    }

    SettingsSliderRow {
        label: "Corner Radius Preset"
        value: ConfigStore.cornerRadiusPreset
        from: 10; to: 32; suffix: " px"
        onMoved: (v) => ConfigStore.setCornerRadiusPreset(Math.round(v))
    }

    
    Surface {
        Layout.fillWidth: true
        implicitHeight: transCol.implicitHeight + 24
        cornerRadius: 14
        backgroundColor: Theme.colors.surface

        ColumnLayout {
            id: transCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            StyledText { variant: "mediaTitle"; font.pixelSize: 13; font.weight: Font.DemiBold; text: "Wallpaper Transition Style" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { key: "circleOut", name: "Circle Wipe" },
                        { key: "fade", name: "Fade & Zoom" },
                        { key: "slide", name: "Slide H" },
                        { key: "slideVertical", name: "Slide V" },
                        { key: "instant", name: "Instant" }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 8
                        color: ConfigStore.wallpaperTransitionStyle === modelData.key ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.06)

                        StyledText {
                            anchors.centerIn: parent
                            font.pixelSize: 11
                            font.weight: ConfigStore.wallpaperTransitionStyle === modelData.key ? Font.DemiBold : Font.Normal
                            textColor: ConfigStore.wallpaperTransitionStyle === modelData.key ? Theme.colors.accentText : Qt.rgba(1, 1, 1, 0.85)
                            text: modelData.name
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConfigStore.setWallpaperTransitionStyle(modelData.key)
                        }
                    }
                }
            }
        }
    }

    SettingsSliderRow {
        label: "Wallpaper Transition Duration"
        value: ConfigStore.wallpaperTransitionDuration
        from: 200; to: 1500; suffix: " ms"
        onMoved: (v) => ConfigStore.setWallpaperTransitionDuration(Math.round(v))
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Dark Mode Base" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: Theme.darkMode
            accentColor: Theme.colors.accent
            onToggled: (v) => Theme.darkMode = v
        }
    }
}
