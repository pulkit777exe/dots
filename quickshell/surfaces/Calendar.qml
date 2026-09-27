import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

Item {
    id: root

    implicitWidth: 300
    implicitHeight: 115

    property string currentTime: Qt.formatTime(new Date(), "hh:mm")
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "hh:mm")
    }

    readonly property var dayNames: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var dayLetters: ["S", "M", "T", "W", "T", "F", "S"]

    property var weekDays: buildWeekDays()

    function buildWeekDays() {
        const list = []
        const now = new Date()
        for (let i = -3; i <= 3; i++) {
            const d = new Date(now)
            d.setDate(now.getDate() + i)
            const dayOfWeek = d.getDay()
            list.push({
                offset: i,
                date: d.getDate(),
                dayOfWeek: dayOfWeek,
                isSunday: dayOfWeek === 0,
                isToday: i === 0,
                shortName: i === 0 ? dayNames[dayOfWeek] : dayLetters[dayOfWeek]
            })
        }
        return list
    }

    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: root.weekDays = buildWeekDays()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // ---- Time (Centered) ----
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.currentTime
            font.pixelSize: 24
            font.weight: Font.DemiBold
            color: "#F7EFE1"
        }

        // ---- Horizontal 7-Day Calendar Strip ----
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Repeater {
                model: root.weekDays

                Item {
                    id: dayCell
                    Layout.preferredWidth: modelData.isToday ? 34 : 26
                    Layout.preferredHeight: 46
                    Layout.alignment: Qt.AlignVCenter

                    readonly property int dist: Math.abs(modelData.offset)
                    // Progressive blur/fade toward both edges
                    opacity: dist === 0 ? 1.0 : (dist === 1 ? 0.75 : (dist === 2 ? 0.40 : 0.18))
                    scale: modelData.isToday ? 1.05 : 0.95

                    // Today highlight capsule
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        visible: modelData.isToday
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        // Day Letter / Short Name
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.shortName
                            font.pixelSize: modelData.isToday ? 10 : 11
                            font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            color: modelData.isSunday
                                ? "#E05252"
                                : (modelData.isToday ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.6))
                        }

                        // Day Number
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.date
                            font.pixelSize: modelData.isToday ? 14 : 13
                            font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            color: modelData.isToday
                                ? Theme.colors.accent
                                : (modelData.isSunday ? "#E05252" : Qt.rgba(1, 1, 1, 0.85))
                        }
                    }
                }
            }
        }
    }
}
