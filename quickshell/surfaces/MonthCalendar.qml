import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"










Item {
    id: root

    implicitWidth: 341
    implicitHeight: 281

    
    property var shown: firstOfMonth(new Date())
    readonly property var today: new Date()

    readonly property var dayLetters: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var monthNames: ["January", "February", "March", "April",
                                       "May", "June", "July", "August",
                                       "September", "October", "November", "December"]

    function firstOfMonth(d) { return new Date(d.getFullYear(), d.getMonth(), 1); }
    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    
    
    
    readonly property var grid: {
        const first = root.shown
        const lead = first.getDay()                       
        const start = new Date(first)
        start.setDate(1 - lead)
        const cells = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(start)
            d.setDate(start.getDate() + i)
            cells.push({
                date: d.getDate(),
                inMonth: d.getMonth() === root.shown.getMonth(),
                isToday: root.isSameDay(d, root.today)
            })
        }
        return cells
    }

    function stepMonth(delta) {
        root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + delta, 1)
    }

    
    MouseArea {
        anchors.fill: parent
        onClicked: UiState.showCalendarWeek()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        
        Item {
            Layout.fillWidth: true
            implicitHeight: 30

            
            
            
            component PageArrow: Rectangle {
                id: arrow
                property string glyph: ""
                property int delta: 0
                width: 26; height: 26; radius: 13
                color: arrowHover.hovered ? Theme.colors.surfaceAlt : Theme.colors.surface
                Icon {
                    anchors.centerIn: parent
                    icon: arrow.glyph
                    size: 15
                    iconColor: Theme.withAlpha(Theme.colors.text, 0.7)
                }
                HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.stepMonth(arrow.delta) }
            }

            PageArrow {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                glyph: "chevron_left"
                delta: -1
            }

            StyledText {
                anchors.centerIn: parent
                text: root.monthNames[root.shown.getMonth()] + " " + root.shown.getFullYear()
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }

            PageArrow {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: "chevron_right"
                delta: 1
            }
        }

        Item { Layout.preferredHeight: 14; Layout.fillWidth: true }

        
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.dayLetters
                delegate: StyledText {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: 12
                    textColor: Theme.withAlpha(Theme.colors.text, 0.45)
                }
            }
        }

        Item { Layout.preferredHeight: 10; Layout.fillWidth: true }

        
        
        
        
        
        
        
        
        
        
        
        Grid {
            Layout.fillWidth: true
            Layout.topMargin: 8
            columns: 7
            columnSpacing: 0
            rowSpacing: 0

            Repeater {
                model: root.grid

                delegate: Item {
                    required property var modelData
                    width: 44
                    height: 31.5

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 15
                        color: Theme.colors.accent
                        visible: modelData.isToday
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.date
                        font.pixelSize: 14
                        font.weight: modelData.isToday ? Font.DemiBold : Font.Normal
                        color: modelData.isToday
                            ? Theme.colors.accentText
                            : (modelData.inMonth ? Theme.colors.text : Theme.withAlpha(Theme.colors.text, 0.28))
                    }
                }
            }
        }
    }
}
