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

        
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.currentTime
            font.pixelSize: 24
            font.weight: Font.DemiBold
            textColor: Theme.colors.text
        }

        
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

                    
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: UiState.showCalendarMonth() }

                    readonly property int dist: Math.abs(modelData.offset)
                    
                    opacity: dist === 0 ? 1.0 : (dist === 1 ? 0.75 : (dist === 2 ? 0.40 : 0.18))
                    scale: modelData.isToday ? 1.05 : 0.95

                    
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Theme.withAlpha(Theme.colors.text, 0.08)
                        border.color: Theme.colors.border
                        border.width: 1
                        visible: modelData.isToday
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.shortName
                            font.pixelSize: modelData.isToday ? 10 : 11
                            font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            color: modelData.isSunday
                                ? Theme.colors.danger
                                : (modelData.isToday ? Theme.colors.text : Theme.withAlpha(Theme.colors.text, 0.6))
                        }

                        
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.date
                            font.pixelSize: modelData.isToday ? 14 : 13
                            font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            color: modelData.isToday
                                ? Theme.colors.accent
                                : (modelData.isSunday ? Theme.colors.danger : Theme.withAlpha(Theme.colors.text, 0.85))
                        }
                    }
                }
            }
        }
    }
}
