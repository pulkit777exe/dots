import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

Surface {
    id: root

    property var wallpapers: []
    property string themeName: ""
    property string themeKey: ""
    property int currentIndex: 0

    signal wallpaperSelected(int index)

    // Geometry measured off 2026-09-20_22-30-49, the wallpaper reference.
    // That capture's panel spans x 198..1207 (1009 wide) with the first card
    // starting 37 in and the last ending 38 from the other edge -- symmetric.
    // Five cards of ~170 with ~16px gaps need 5*170 + 4*16 = 914, which fits
    // the 985 of usable width with ~35 either side.
    //
    // 734 was showing three and a half cards in a much smaller panel, which is
    // where the crowding came from.
    width: 1008
    implicitHeight: 222
    cornerRadius: 20

    // Thumbnail metrics, named so the delegate and the ListView agree.
    //
    // No currentScale/otherScale: the reference does not scale the selected
    // card, and the scale is what made this row's spacing uneven (see the
    // delegate's `scale` below).
    readonly property real itemW: 170
    readonly property real itemH: 113
    readonly property real cardSpacing: 16

    // ------------------------------------------------------------
    // Selection
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------

    onWallpapersChanged:
        resetSelection()

    onThemeKeyChanged:
        resetSelection()

    onVisibleChanged: {
        if (visible) {
            resetSelection()
            forceActiveFocus()

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

    // ------------------------------------------------------------
    // Keyboard
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // Layout
    // ------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16

        spacing: 12

        // --------------------------------------------------------
        // Header
        // --------------------------------------------------------

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
                    Qt.rgba(
                        1,
                        1,
                        1,
                        0.45
                    )

                text:
                    root.themeName

                elide:
                    Text.ElideRight
            }
        }

        // --------------------------------------------------------
        // Wallpaper list
        // --------------------------------------------------------

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: root.itemH

            orientation:
                ListView.Horizontal

            spacing: root.cardSpacing

            // Clip. It was false, so the thumbnails were free to render past
            // the panel's edge and over its rounded corner: the current item is
            // scaled to 1.16, i.e. 227px against a 196px slot, and the
            // neighbours spill either side of it. With the list 706px of
            // usable width the three visible items need 170 + 12 + 227 + 12 +
            // 170 = 591, so clipping costs nothing and nothing can escape.
            clip: true

            model:
                root.wallpapers

            currentIndex:
                root.currentIndex

            highlightRangeMode:
                ListView.StrictlyEnforceRange

            // Centred on the real item width. Nothing is scaled now, so this
            // is simply centring the current thumbnail in the row.
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

            delegate: Item {
                required property string source
                required property bool selected
                required property string fileName
                required property int index

                width: root.itemW
                height: root.itemH

                // Uniform, no scale -- the reference's selected card is the
                // same size as the rest, marked only by its 2px accent border
                // (which the thumbnail Rectangle below already draws).
                //
                // The 1.16/0.87 scale is what made this row's spacing look
                // broken: the current card painted 227px into a 196px slot and
                // ate 15px of each neighbour's gap, while unhighlighted pairs
                // were left with far more, so the gaps alternated.
                scale: 1

                opacity:
                    ListView.isCurrentItem
                        ? 1
                        : 0.86

                Behavior on opacity {
                    enabled:
                        !MotionConfig.reduceMotion

                    NumberAnimation {
                        duration:
                            MotionConfig.hover()
                    }
                }

                // ------------------------------------------------
                // Thumbnail
                // ------------------------------------------------

                Rectangle {
                    anchors.fill: parent

                    radius: 12
                    clip: true

                    color:
                        Theme.colors.surfaceAlt

                    border.width:
                        selected ? 2 : 1

                    border.color:
                        selected
                            ? Theme.colors.accent
                            : Qt.rgba(
                                1,
                                1,
                                1,
                                0.06
                              )

                    Image {
                        anchors.fill: parent

                        source:
                            parent.parent.source

                        fillMode:
                            Image.PreserveAspectCrop

                        asynchronous: true
                        cache: true
                        smooth: true

                        sourceSize:
                            Qt.size(
                                392,
                                236
                            )
                    }

                    Rectangle {
                        anchors.fill: parent

                        color:
                            Qt.rgba(
                                0,
                                0,
                                0,
                                0.08
                            )
                    }

                    Rectangle {
                        visible:
                            selected

                        width: 7
                        height: 7

                        radius: 3.5

                        anchors.top:
                            parent.top

                        anchors.right:
                            parent.right

                        anchors.margins: 8

                        color:
                            Theme.colors.accent
                    }
                }

                // ------------------------------------------------
                // Hover
                // ------------------------------------------------

                HoverHandler {
                    id: hover
                }

                Rectangle {
                    anchors.fill: parent

                    radius: 12

                    color:
                        hover.hovered &&
                        !ListView.isCurrentItem
                            ? Qt.rgba(
                                1,
                                1,
                                1,
                                0.06
                              )
                            : "transparent"
                }

                // ------------------------------------------------
                // Click
                // ------------------------------------------------

                TapHandler {
                    onTapped: {
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
        }

        // --------------------------------------------------------
        // Footer
        // --------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true

                variant:
                    "mediaSubtitle"

                font.pixelSize: 11

                color:
                    Qt.rgba(
                        1,
                        1,
                        1,
                        0.50
                    )

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
                    Qt.rgba(
                        1,
                        1,
                        1,
                        0.35
                    )

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