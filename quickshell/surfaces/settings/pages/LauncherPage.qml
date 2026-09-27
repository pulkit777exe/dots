import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"
ColumnLayout {
    id: root
    spacing: 20

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 28
            color: Qt.rgba(1, 1, 1, 0.06)
            Icon { anchors.centerIn: parent; icon: "search"; size: 22; iconColor: Theme.colors.accent }
        }
        ColumnLayout {
            spacing: 2
            StyledText { variant: "mediaTitle"; font.pixelSize: 17; text: "Application Launcher" }
            StyledText {
                variant: "mediaSubtitle"
                text: "Search providers, indexing preferences, and result density."
            }
        }
    }

    SettingsSliderRow {
        label: "Width"
        value: ConfigStore.launcherWidth
        from: 380; to: 800; suffix: " px"
        onMoved: (v) => ConfigStore.setLauncherWidth(Math.round(v))
    }

    SettingsSliderRow {
        label: "Row height"
        value: ConfigStore.launcherRowHeight
        from: 36; to: 72; suffix: " px"
        onMoved: (v) => ConfigStore.setLauncherRowHeight(Math.round(v))
    }

    SettingsSliderRow {
        label: "Rows before scrolling"
        value: ConfigStore.launcherRowsBeforeScrolling
        from: 3; to: 12; suffix: ""
        onMoved: (v) => ConfigStore.setLauncherRowsBeforeScrolling(Math.round(v))
    }

    SettingsSliderRow {
        label: "Maximum Visible Results"
        value: ConfigStore.launcherMaxResults
        from: 3; to: 12; suffix: " items"
        onMoved: (v) => ConfigStore.setLauncherMaxResults(Math.round(v))
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Include Shell Commands & Binaries in Search" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.launcherIncludeCommands
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setLauncherIncludeCommands(v)
        }
    }

    // Hotkey note card
    Surface {
        Layout.fillWidth: true
        implicitHeight: 64
        cornerRadius: 14
        backgroundColor: Theme.colors.surface

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Icon {
                icon: "keyboard"
                size: 20
                iconColor: Theme.colors.accent
            }

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: 13
                text: "Global shortcut: Super + D (or click the Island pill)"
            }
        }
    }
}
