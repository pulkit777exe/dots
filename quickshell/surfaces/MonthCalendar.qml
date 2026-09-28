import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// MonthCalendar
// The month grid from 2026-09-20_22-25-42, which the shell had no equivalent
// of at all: Calendar.qml renders only a clock and a 7-day strip.
//
// 341 x 281, measured off the reference the same way as the other panels --
// long dark runs only, so the crop's own rounded corners cannot pull the box
// outward. The grid is 7 columns on a 44px pitch with 6 date rows on a 31.5px
// pitch, both centred, which is what leaves the reference's ~38px side margins
// inside a 341px card.
Item {
    id: root

    implicitWidth: 341
    implicitHeight: 281

    // Paged by the header's arrows. `shown` is the first of the displayed month.
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

    // Six weeks starting on the Sunday on or before the 1st, so the grid is
    // always 6 rows tall and the card never changes height month to month --
    // the same guarantee the reference's fixed 281px implies.
    readonly property var grid: {
        const first = root.shown
        const lead = first.getDay()                       // 0 = Sunday
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

    // Clicking the grid's body (not an arrow) drops back to the week strip.
    MouseArea {
        anchors.fill: parent
        onClicked: UiState.showCalendarWeek()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        // ---- Header: ‹  "September 2026"  › ----
        Item {
            Layout.fillWidth: true
            implicitHeight: 30

            // The reference puts ‹ hard left and › hard right with the title
            // between them. Both arrows used to sit in a Row on the left, which
            // read as a pair of controls rather than a pager.
            component PageArrow: Rectangle {
                id: arrow
                property string glyph: ""
                property int delta: 0
                width: 26; height: 26; radius: 13
                color: arrowHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                Icon {
                    anchors.centerIn: parent
                    icon: arrow.glyph
                    size: 15
                    iconColor: Qt.rgba(1, 1, 1, 0.7)
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
                color: "#F6E2CB"
            }

            PageArrow {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: "chevron_right"
                delta: 1
            }
        }

        Item { Layout.preferredHeight: 14; Layout.fillWidth: true }

        // ---- Weekday letters ----
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
                    textColor: Qt.rgba(1, 1, 1, 0.45)
                }
            }
        }

        Item { Layout.preferredHeight: 10; Layout.fillWidth: true }

        // ---- Six rows of dates ----
        //
        // A Grid over the flat 42-cell model rather than nested Repeaters.
        // Nested Repeaters cannot reach the outer delegate's index from the
        // inner one (`row is not defined`, and the inner `index` shadows the
        // outer), which is what threw 210 TypeErrors on load.
        //
        // 7 columns on a 44px pitch and 6 rows on a 31.5px pitch come off the
        // reference: its column centres are 43.9px apart and its date rows
        // 31.5px apart, and 7 x 44 = 308 leaves the reference's ~16px side
        // margins inside a 341px card.
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
                            ? "#0B1512"
                            : (modelData.inMonth ? "#F6E2CB" : Qt.rgba(1, 1, 1, 0.28))
                    }
                }
            }
        }
    }
}
