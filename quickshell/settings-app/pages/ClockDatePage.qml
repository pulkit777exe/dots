import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    property date now: new Date()

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: root.now = new Date()
    }

    SettingsHeader {
        icon: "schedule"
        title: "Clock & Date"
        subtitle: "Time formatting and display preferences."
    }

    Surface {
        Layout.fillWidth: true
        implicitHeight: 100
        cornerRadius: 15
        backgroundColor: Theme.colors.surface
        borderWidth: 0
        shadow: false

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Label {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Theme.px(30)
                font.weight: Font.Bold
                color: Theme.colors.text
                text: Qt.formatTime(root.now, Config.time24h
                    ? (Config.showSeconds ? "hh:mm:ss" : "hh:mm")
                    : (Config.showSeconds ? "hh:mm:ss AP" : "hh:mm AP"))
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Theme.px(13)
                color: Theme.withAlpha(Theme.colors.text, 0.6)
                text: Qt.formatDate(root.now, "dddd, MMMM d, yyyy")
            }
        }
    }

    SettingsCard {
        SettingsToggleRow {
            label: "24-hour time"
            checked: Config.time24h
            onToggled: (v) => Config.set("time24h", v)
        }
        SettingsDivider {}
        SettingsToggleRow {
            label: "Show seconds"
            checked: Config.showSeconds
            onToggled: (v) => Config.set("showSeconds", v)
        }
    }
}
