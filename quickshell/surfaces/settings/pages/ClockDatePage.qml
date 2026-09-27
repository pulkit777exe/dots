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
            Icon { anchors.centerIn: parent; icon: "schedule"; size: 22; iconColor: Theme.colors.accent }
        }
        ColumnLayout {
            spacing: 2
            StyledText { variant: "mediaTitle"; font.pixelSize: 17; text: "Clock & Date" }
            StyledText {
                variant: "mediaSubtitle"
                text: "Time formatting, calendar layout, and display preferences."
            }
        }
    }

    // Live Clock Preview Card
    Surface {
        Layout.fillWidth: true
        implicitHeight: 100
        cornerRadius: 16
        backgroundColor: Theme.colors.surface

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: 30
                font.weight: Font.Bold
                text: Qt.formatTime(new Date(), ConfigStore.time24h ? (ConfigStore.showSeconds ? "hh:mm:ss" : "hh:mm") : (ConfigStore.showSeconds ? "hh:mm:ss AP" : "hh:mm AP"))
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: 13
                textColor: Qt.rgba(1, 1, 1, 0.6)
                text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
            }
        }
    }

    // Toggles
    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "24-Hour Time Format" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.time24h
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setTime24h(v)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "Display Seconds in Clock" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.showSeconds
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setShowSeconds(v)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { variant: "mediaTitle"; font.pixelSize: 13; text: "First Day of the Week: Monday" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: ConfigStore.firstDayMonday
            accentColor: Theme.colors.accent
            onToggled: (v) => ConfigStore.setFirstDayMonday(v)
        }
    }
}
