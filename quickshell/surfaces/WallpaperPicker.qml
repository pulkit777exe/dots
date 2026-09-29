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

    width: 734
    implicitHeight: 232
    cornerRadius: 20

    // Thumbnail metrics, named so the delegate and the ListView's highlight
    // maths cannot drift apart. The delegate is laid out at `itemW` and then
    // scaled, so its *visual* width is itemW * currentScale -- which is what
    // has to be used when centring the current item.
    readonly property real itemW: 196
    readonly property real itemH: 118
    readonly property real currentScale: 1.16
    readonly property real otherScale: 0.87
    readonly property real scaledItemW: itemW * currentScale

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
            Layout.preferredHeight: 138

            orientation:
                ListView.Horizontal

            spacing: 12

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

            // Centred on the SCALED width. It used the unscaled 196, so the
            // current item was positioned as if it were still 196 wide while
            // actually painting 227, leaving it 15px right of centre and
            // shoving the row toward the panel's right edge.
            preferredHighlightBegin:
                (width - root.scaledItemW) / 2

            preferredHighlightEnd:
                (width - root.scaledItemW) / 2

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

                scale:
                    ListView.isCurrentItem
                        ? root.currentScale
                        : root.otherScale

                opacity:
                    ListView.isCurrentItem
                        ? 1
                        : 0.72

                Behavior on scale {
                    enabled:
                        !MotionConfig.reduceMotion

                    NumberAnimation {
                        duration: MotionConfig.fade(1.4)

                        easing.type:
                            Easing.OutBack
                    }
                }

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