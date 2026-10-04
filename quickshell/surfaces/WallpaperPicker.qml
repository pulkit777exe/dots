import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// WallpaperPicker.qml -- the wallpaper panel: a title, a horizontal strip of
// thumbnails, and a caption saying which one you are on.
//
// What is left in this file is the picker's own state: which wallpaper is
// current, how that tracks the theme's saved wallpaper, the arrow keys, and
// the geometry of the strip -- 170x113 cards, 16 between them, centred on
// the current one. What a single thumbnail looks like is
// WallpaperCard.qml.
//
// The strip is a ListView rather than a Row, because it has to keep the
// current item centred without ever scrolling past the ends: that is
// StrictlyEnforceRange plus SnapToItem, and both are properties of the view
// rather than of the cards, so they stayed here.
//
// The model, the theme name and the `wallpaperSelected` signal all come from
// IslandCenterPanel, which is what actually applies a wallpaper. Nothing here
// touches the filesystem.

Surface {
    id: root

    property var wallpapers: []
    property string themeName: ""
    property string themeKey: ""
    property int currentIndex: 0

    signal wallpaperSelected(int index)

    width: 1008
    implicitHeight: 222
    cornerRadius: 20

    readonly property real itemW: 170
    readonly property real itemH: 113
    readonly property real cardSpacing: 16


    // Land the selection on the wallpaper the theme is actually using rather
    // than wherever it happened to be, because the panel is opened to change
    // the wallpaper from the one already set.
    function resetSelection() {
        if (
            !wallpapers ||
            wallpapers.length === 0
        ) {
            currentIndex = 0
            return
        }

        for (
            let i = 0;
            i < wallpapers.length;
            i++
        ) {
            if (wallpapers[i].selected) {
                currentIndex = i
                return
            }
        }

        currentIndex = 0
    }

    // Wraps, unlike the clipboard list: a strip of six has no end to stop at,
    // and wrapping is what makes left-then-right feel like one control.
    function moveSelection(delta) {
        if (list.count === 0)
            return

        currentIndex =
            (
                currentIndex +
                delta +
                list.count
            ) %
            list.count

        list.currentIndex =
            currentIndex

        list.positionViewAtIndex(
            currentIndex,
            ListView.Center
        )
    }

    function applySelection() {
        if (
            currentIndex >= 0 &&
            currentIndex < list.count
        ) {
            wallpaperSelected(
                currentIndex
            )
        }
    }


    onWallpapersChanged:
        resetSelection()

    onThemeKeyChanged:
        resetSelection()

    onVisibleChanged: {
        if (visible) {
            resetSelection()
            forceActiveFocus()

            // After the model has been laid out, not before: the strip is
            // sized by its cards, and centring index 0 in a list that has not
            // measured itself yet centres it in the wrong place.
            Qt.callLater(function() {
                if (list.count > 0) {
                    list.positionViewAtIndex(
                        currentIndex,
                        ListView.Center
                    )
                }
            })
        }
    }

    Component.onCompleted:
        resetSelection()

    focus: true


    Keys.onLeftPressed:
        function(event) {
            moveSelection(-1)
            event.accepted = true
        }

    Keys.onRightPressed:
        function(event) {
            moveSelection(1)
            event.accepted = true
        }

    Keys.onReturnPressed:
        function(event) {
            applySelection()
            event.accepted = true
        }

    Keys.onEnterPressed:
        function(event) {
            applySelection()
            event.accepted = true
        }

    Keys.onEscapePressed:
        function(event) {
            UiState.closeAll()
            event.accepted = true
        }


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16

        spacing: 12


        RowLayout {
            Layout.fillWidth: true

            StyledText {
                variant: "mediaTitle"

                font.pixelSize: 15
                font.weight: Font.DemiBold

                text: "Wallpaper"
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                variant: "mediaSubtitle"

                font.pixelSize: 11

                color:
                    Theme.withAlpha(Theme.colors.text, 0.45)

                text:
                    root.themeName

                elide:
                    Text.ElideRight
            }
        }


        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: root.itemH

            orientation:
                ListView.Horizontal

            spacing: root.cardSpacing

            clip: true

            model:
                root.wallpapers

            currentIndex:
                root.currentIndex

            // The current card stays in the middle whatever the list width,
            // and the strip refuses to scroll past either end -- which is why
            // there is empty panel to the left of the first card rather than
            // the first card being flush against it.
            highlightRangeMode:
                ListView.StrictlyEnforceRange

            preferredHighlightBegin:
                (width - root.itemW) / 2

            preferredHighlightEnd:
                (width - root.itemW) / 2

            highlightMoveDuration:
                MotionConfig.reduceMotion
                    ? 0
                    : 280

            snapMode:
                ListView.SnapToItem

            delegate: WallpaperCard {
                required property var modelData
                required property int index

                // itemW and itemH are declared here and passed down, so the
                // numbers the highlight range is computed from and the numbers
                // the cards are laid out with cannot disagree.
                cardWidth: root.itemW
                cardHeight: root.itemH

                onPicked: {
                    root.currentIndex =
                        index

                    list.currentIndex =
                        index

                    list.positionViewAtIndex(
                        index,
                        ListView.Center
                    )

                    root.applySelection()
                    root.forceActiveFocus()
                }
            }
        }


        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true

                variant:
                    "mediaSubtitle"

                font.pixelSize: 11

                color:
                    Theme.withAlpha(Theme.colors.text, 0.50)

                elide:
                    Text.ElideMiddle

                text: {
                    if (
                        root.currentIndex >= 0 &&
                        root.currentIndex <
                            root.wallpapers.length
                    ) {
                        return root.wallpapers[
                            root.currentIndex
                        ].fileName || ""
                    }

                    return ""
                }
            }

            StyledText {
                variant:
                    "mediaSubtitle"

                font.pixelSize: 11

                color:
                    Theme.withAlpha(Theme.colors.text, 0.35)

                text:
                    root.wallpapers.length > 0
                        ? (
                            root.currentIndex + 1
                          ) +
                          "/" +
                          root.wallpapers.length +
                          " · Enter to apply"
                        : "0/0"
            }
        }
    }
}
