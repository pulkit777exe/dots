import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

PopupPanel {
    id: root

    open: UiState.themePickerOpen
    width: 804
    implicitHeight: 220
    cornerRadius: open ? Config.expandedRadius : pillRadius
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
            Layout.preferredHeight: 116
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
                height: 114

                readonly property bool selected: modelData.selected
                readonly property bool highlighted: ListView.isCurrentItem

                opacity: highlighted ? 1 : 0.8
                Behavior on opacity { NumberAnimation { duration: Config.hover() } }

                Item {
                    id: cardRect
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 86

                    Glow {
                        anchors.fill: parent
                        anchors.margins: -5
                        cornerRadius: 20
                        glowColor: Theme.withAlpha(card.modelData.accent, 0.08)
                        on: card.highlighted
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 13
                        color: card.modelData.cardColor
                        border.width: card.highlighted ? 2 : 1
                        border.color: card.highlighted
                            ? card.modelData.accent
                            : Theme.withAlpha(Theme.colors.text, 0.06)

                        SelectionDot {
                            selected: card.selected
                            color: card.modelData.accent
                        }
                    }

                    Row {
                        anchors.centerIn: parent
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
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: cardRect.bottom
                        topMargin: 7
                    }
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
