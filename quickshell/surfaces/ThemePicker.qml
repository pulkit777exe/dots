import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

Surface {
    id: root

    property var themes: []

    signal themeSelected(int index)

    width: 780
    implicitHeight: 196

    backgroundColor: "transparent"
    borderWidth: 0
    shadow: false

    readonly property var filteredThemes: {
        const q = search.text.trim().toLowerCase()

        if (!q)
            return themes

        return themes.filter(
            theme => theme.name.toLowerCase().includes(q)
        )
    }

    function activeIndex() {
        for (let i = 0; i < filteredThemes.length; i++) {
            if (filteredThemes[i].key === Theme.currentName)
                return i
        }

        return 0
    }

    function sync() {
        if (list.count === 0)
            return

        list.currentIndex = activeIndex()

        Qt.callLater(function() {
            if (list.count > 0)
                list.positionViewAtIndex(
                    list.currentIndex,
                    ListView.Center
                )
        })
    }

    function moveSelection(delta) {
        if (list.count === 0)
            return

        const next = Math.max(
            0,
            Math.min(
                list.count - 1,
                list.currentIndex + delta
            )
        )

        list.currentIndex = next

        list.positionViewAtIndex(
            next,
            ListView.Center
        )
    }

    function applySelection() {
        if (
            list.currentIndex < 0 ||
            list.currentIndex >= filteredThemes.length
        )
            return

        const item = filteredThemes[list.currentIndex]
        const index = themes.indexOf(item)

        if (index >= 0)
            root.themeSelected(index)
    }

    onThemesChanged: sync()

    onVisibleChanged: {
        if (visible) {
            sync()
            forceActiveFocus()
        }
    }

    Connections {
        target: Theme

        function onThemeChanged() {
            root.sync()
        }
    }

    focus: true

    Keys.onLeftPressed: function(event) {
        moveSelection(-1)
        event.accepted = true
    }

    Keys.onRightPressed: function(event) {
        moveSelection(1)
        event.accepted = true
    }

    Keys.onReturnPressed: function(event) {
        applySelection()
        event.accepted = true
    }

    Keys.onEnterPressed: function(event) {
        applySelection()
        event.accepted = true
    }

    Keys.onEscapePressed: function(event) {
        UiState.closeAll()
        event.accepted = true
    }

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

                placeholderText: "Search themes..."
                externalNavigation: true

                onNavigateLeft:
                    root.moveSelection(-1)

                onNavigateRight:
                    root.moveSelection(1)

                onNavigateUp:
                    root.moveSelection(-3)

                onNavigateDown:
                    root.moveSelection(3)

                onAccepted:
                    root.applySelection()

                onTextChanged:
                    root.sync()
            }

            StyledText {
                variant: "mediaSubtitle"

                text:
                    list.count > 0
                        ? (list.currentIndex + 1) +
                          "/" +
                          list.count
                        : "0/0"

                color:
                    Theme.withAlpha(
                        Theme.colors.text,
                        0.4
                    )
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: 112

            orientation: ListView.Horizontal
            spacing: 10
            clip: true

            model: root.filteredThemes

            currentIndex: 0

            highlightRangeMode:
                ListView.NoHighlightRange

            snapMode:
                ListView.NoSnap

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                
                
                
                
                
                width: 176
                height: 98

                readonly property bool selected:
                    modelData.key === Theme.currentName

                readonly property bool highlighted:
                    ListView.isCurrentItem

                
                
                
                
                
                
                
                
                
                
                scale: 1

                opacity:
                    highlighted ? 1 : 0.72

                Behavior on scale {
                    NumberAnimation {
                        duration: MotionConfig.fade(1.1)
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.fill: parent

                    radius: 13

                    color:
                        modelData.cardColor

                    border.width:
                        card.highlighted ? 2 : 1

                    border.color:
                        card.highlighted
                            ? modelData.accent
                            : Theme.withAlpha(
                                Theme.colors.text,
                                0.06
                              )

                    Rectangle {
                        visible: card.selected

                        width: 7
                        height: 7

                        radius: 3.5

                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8

                        color:
                            modelData.accent
                    }
                }

                Row {
                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    anchors.top: parent.top
                    anchors.topMargin: 32

                    spacing: 5

                    Repeater {
                        model: modelData.swatchColors

                        Rectangle {
                            required property var modelData

                            width: 10
                            height: 10

                            radius: 5

                            color: modelData
                        }
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10

                    text: modelData.name

                    font.pixelSize: 11
                    font.weight:
                        card.selected
                            ? Font.DemiBold
                            : Font.Normal

                    color:
                        Theme.withAlpha(
                            Theme.colors.text,
                            card.selected ? 0.9 : 0.6
                        )

                    horizontalAlignment:
                        Text.AlignHCenter

                    elide: Text.ElideRight
                }

                TapHandler {
                    onTapped: {
                        list.currentIndex = index
                        root.forceActiveFocus()
                    }
                }
            }

            onCountChanged:
                root.sync()
        }

        StyledText {
            Layout.alignment: Qt.AlignRight

            variant: "mediaSubtitle"

            text: "Enter to apply"

            color:
                Theme.withAlpha(
                    Theme.colors.text,
                    0.35
                )
        }
    }
}