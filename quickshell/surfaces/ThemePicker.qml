import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// Theme strip: search + n/total, a horizontal run of swatch cards, and the
// "Enter to apply" hint. Arrows move the cursor, Enter/click applies.
PopupPanel {
    id: root

    open: UiState.themePickerOpen
    width: 804
    implicitHeight: 220
    cornerRadius: Config.expandedRadius
    backgroundColor: Theme.colors.background

    readonly property var rows: Theme.pickerRows()
    readonly property var filtered: {
        const q = search.text.trim().toLowerCase()
        return q ? rows.filter(t => t.name.toLowerCase().includes(q)) : rows
    }

    function activeIndex() {
        for (let i = 0; i < filtered.length; i++)
            if (filtered[i].key === Theme.currentName)
                return i
        return 0
    }

    function sync() {
        if (list.count === 0)
            return

        list.currentIndex = activeIndex()
        Qt.callLater(() => {
            if (list.count > 0)
                list.positionViewAtIndex(list.currentIndex, ListView.Center)
        })
    }

    function moveSelection(delta) {
        if (list.count === 0)
            return

        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta))
        list.positionViewAtIndex(list.currentIndex, ListView.Center)
    }

    function applySelection() {
        if (list.currentIndex < 0 || list.currentIndex >= filtered.length)
            return

        Theme.setTheme(filtered[list.currentIndex].key)
        UiState.close()
    }

    onOpenChanged: if (open) {
        sync()
        Qt.callLater(() => search.forceInputFocus())
    }

    // Retry if the window had not taken keyboard focus when open flipped.
    onActiveFocusChanged: if (activeFocus && open)
        Qt.callLater(() => search.forceInputFocus())

    Connections {
        target: Theme
        function onThemeChanged() { root.sync() }
    }

    Keys.onLeftPressed: e => { root.moveSelection(-1); e.accepted = true }
    Keys.onRightPressed: e => { root.moveSelection(1); e.accepted = true }
    Keys.onUpPressed: e => { root.moveSelection(-3); e.accepted = true }
    Keys.onDownPressed: e => { root.moveSelection(3); e.accepted = true }
    Keys.onReturnPressed: e => { root.applySelection(); e.accepted = true }
    Keys.onEnterPressed: e => { root.applySelection(); e.accepted = true }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            SearchField {
                id: search

                Layout.fillWidth: true
                fieldHeight: 30
                placeholderText: "Search themes..."
                externalNavigation: true

                onNavigateLeft: root.moveSelection(-1)
                onNavigateRight: root.moveSelection(1)
                onNavigateUp: root.moveSelection(-3)
                onNavigateDown: root.moveSelection(3)
                onAccepted: root.applySelection()
                onTextChanged: root.sync()
            }

            Label {
                Layout.alignment: Qt.AlignVCenter
                text: list.count > 0 ? (list.currentIndex + 1) + "/" + list.count : "0/0"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.4)
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: 112
            orientation: ListView.Horizontal
            spacing: 10
            clip: true
            model: root.filtered
            highlightRangeMode: ListView.NoHighlightRange
            snapMode: ListView.NoSnap

            onCountChanged: root.sync()

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                width: 176
                height: 98

                readonly property bool selected: modelData.selected
                readonly property bool highlighted: ListView.isCurrentItem

                opacity: highlighted ? 1 : 0.72
                Behavior on opacity { NumberAnimation { duration: Config.hover() } }

                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: card.modelData.cardColor
                    border.width: card.highlighted ? 2 : 1
                    border.color: card.highlighted
                        ? card.modelData.accent
                        : Theme.withAlpha(Theme.colors.text, 0.06)

                    Rectangle {
                        visible: card.selected
                        width: 7
                        height: 7
                        radius: 3.5
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        color: card.modelData.accent
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    spacing: 5

                    Repeater {
                        model: card.modelData.swatchColors

                        Rectangle {
                            required property var modelData

                            width: 10
                            height: 10
                            radius: 5
                            color: modelData
                        }
                    }
                }

                Label {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    text: card.modelData.name
                    font.pixelSize: Theme.px(11)
                    font.weight: card.selected ? Font.DemiBold : Font.Normal
                    color: Theme.withAlpha(Theme.colors.text, card.selected ? 0.9 : 0.6)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                TapHandler {
                    onTapped: {
                        list.currentIndex = card.index
                        root.applySelection()
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignRight
            text: "Enter to apply"
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.35)
        }
    }
}
