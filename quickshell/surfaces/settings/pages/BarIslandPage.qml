import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 24

    // ---- Page Header (Reference 5) ----
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 12
            color: Qt.rgba(Theme.colors.accent.r, Theme.colors.accent.g, Theme.colors.accent.b, 0.18)

            Icon {
                anchors.centerIn: parent
                icon: "crop_landscape"
                size: 24
                iconColor: Theme.colors.accent
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 18
            font.weight: Font.DemiBold
            text: "Bar & Island"
            color: "#FFFFFF"
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 13
            text: "Shape and size of the island, the notch, and the Game Mode bar."
            color: Qt.rgba(1, 1, 1, 0.5)
        }
    }

    // ---- Settings Card (Reference 5) ----
    Rectangle {
        Layout.fillWidth: true
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        implicitHeight: settingsCol.implicitHeight + 28

        ColumnLayout {
            id: settingsCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 16

            // Notch mode Toggle Row
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    text: "Notch mode"
                    color: "#FFFFFF"
                }

                Item { Layout.fillWidth: true }

                Toggle {
                    checked: BarConfig.notchMode
                    accentColor: Theme.colors.accent
                    onToggled: (v) => BarConfig.setNotchMode(v)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Notch flare (visible when notch mode is active or always)
            SettingsSliderRow {
                label: "Notch flare"
                value: BarConfig.notchFlare
                from: 0; to: 30; suffix: " px"
                onMoved: (v) => BarConfig.setNotchFlare(v)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Bar height
            SettingsSliderRow {
                label: "Bar height"
                value: BarConfig.barHeight
                from: 24; to: 56; suffix: " px"
                onMoved: (v) => BarConfig.setBarHeight(v)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Collapsed width
            SettingsSliderRow {
                label: "Collapsed width"
                value: BarConfig.collapsedWidth
                from: 60; to: 240; suffix: " px"
                onMoved: (v) => BarConfig.setCollapsedWidth(v)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Expanded height
            SettingsSliderRow {
                label: "Expanded height"
                value: BarConfig.expandedHeight
                from: 80; to: 220; suffix: " px"
                onMoved: (v) => BarConfig.setExpandedHeight(v)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Gap from screen edge
            SettingsSliderRow {
                label: "Gap from screen edge"
                value: BarConfig.gapFromScreenEdge
                from: 0; to: 40; suffix: " px"
                onMoved: (v) => BarConfig.setGapFromScreenEdge(v)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Corner radius (expanded)
            SettingsSliderRow {
                label: "Corner radius (expanded)"
                value: BarConfig.expandedCornerRadius
                from: 12; to: 40; suffix: " px"
                onMoved: (v) => BarConfig.setExpandedCornerRadius(v)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Status circle Toggle Row
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    text: "Status circle (battery and Wi-Fi)"
                    color: "#FFFFFF"
                }

                Item { Layout.fillWidth: true }

                Toggle {
                    checked: BarConfig.statusCircleEnabled
                    accentColor: Theme.colors.accent
                    onToggled: (v) => BarConfig.setStatusCircleEnabled(v)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Album art circle Toggle Row
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    text: "Album art circle while a player is open"
                    color: "#FFFFFF"
                }

                Item { Layout.fillWidth: true }

                Toggle {
                    checked: BarConfig.albumArtCircleEnabled
                    accentColor: Theme.colors.accent
                    onToggled: (v) => BarConfig.setAlbumArtCircleEnabled(v)
                }
            }
        }
    }
}
