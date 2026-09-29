import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// ClipboardHistory
// Spotlight-style clipboard manager matching Launcher.qml layout and aesthetics.
// Supports both image thumbnails and text previews with smooth keyboard navigation.

Surface {
    id: root

    width: 550
    cornerRadius: 20
    backgroundColor: Theme.panelFill

    property var results: Clipboard.filteredEntries
    property int selectedIndex: 0

    implicitHeight:
        Math.min(
            480,
            column.implicitHeight + 24
        )

    transformOrigin: Item.Center

    opacity: 0
    scale: 0.96

    signal closeRequested()

    // ------------------------------------------------------------
    // Selection
    // ------------------------------------------------------------

    function moveSelection(delta) {
        if (results.length === 0)
            return

        selectedIndex =
            Math.max(
                0,
                Math.min(
                    results.length - 1,
                    selectedIndex + delta
                )
            )

        listView.positionViewAtIndex(
            selectedIndex,
            ListView.Contain
        )
    }

    function activateSelection() {
        if (
            results.length > 0 &&
            selectedIndex >= 0 &&
            selectedIndex < results.length
        ) {
            const entry =
                results[selectedIndex]

            Clipboard.copyEntry(
                entry.id
            )

            UiState.closeAll()
        }
    }

    function searchFieldFocus() {
        search.text = ""
        search.focusInput()
        selectedIndex = 0
    }

    function searchFieldHasFocus(): bool {
        return search.hasFocus
    }

    // ------------------------------------------------------------
    // Visibility
    // ------------------------------------------------------------

    onVisibleChanged: {
        if (visible) {
            Clipboard.refresh()
            focusRetry.restart()
        }
    }

    Timer {
        id: focusRetry

        interval: 60
        repeat: true

        onTriggered: {
            if (
                !root.visible ||
                search.hasFocus
            ) {
                stop()
                return
            }

            searchFieldFocus()
        }
    }

    // ------------------------------------------------------------
    // Appearance
    // ------------------------------------------------------------

    ParallelAnimation {
        id: appearAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: MotionConfig.fadeMs
            easing.type: Easing.OutCubic
        }

        SpringAnimation {
            target: root
            property: "scale"
            to: 1
            spring: 4
            damping:
                MotionConfig.springDamping
            mass: 0.7
        }
    }

    // ------------------------------------------------------------
    // Layout
    // ------------------------------------------------------------

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: 12

        spacing: 0

        // --------------------------------------------------------
        // Search
        // --------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            Layout.leftMargin: 8
            Layout.rightMargin: 8

            spacing: 8

            SearchField {
                id: search

                Layout.fillWidth: true

                placeholderText:
                    "Search clipboard..."

                onNavigateDown:
                    root.moveSelection(1)

                onNavigateUp:
                    root.moveSelection(-1)

                Keys.onDownPressed:
                    root.moveSelection(1)

                Keys.onUpPressed:
                    root.moveSelection(-1)

                Keys.onEscapePressed:
                    UiState.closeAll()

                onAccepted:
                    root.activateSelection()

                onTextChanged: {
                    Clipboard.query = text
                    root.selectedIndex = 0
                }
            }

            Rectangle {
                Layout.preferredHeight: 32

                Layout.preferredWidth:
                    clearText.implicitWidth + 16

                radius: 16

                color:
                    clearHover.hovered
                        ? Qt.rgba(
                            1,
                            0.3,
                            0.3,
                            0.15
                          )
                        : "transparent"

                visible:
                    Clipboard.entries.length > 0

                StyledText {
                    id: clearText

                    anchors.centerIn: parent

                    font.pixelSize: 12
                    font.weight: Font.Medium

                    textColor:
                        Theme.colors.danger

                    text: "Clear all"
                }

                HoverHandler {
                    id: clearHover

                    cursorShape:
                        Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped:
                        Clipboard.wipe()
                }
            }
        }

        // --------------------------------------------------------
        // Divider
        // --------------------------------------------------------

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1

            Layout.topMargin: 8
            Layout.bottomMargin: 8

            color:
                Qt.rgba(
                    1,
                    1,
                    1,
                    0.08
                )

            visible:
                Clipboard.entries.length > 0
        }

        // --------------------------------------------------------
        // Empty state
        // --------------------------------------------------------

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 24

            Layout.alignment:
                Qt.AlignHCenter

            horizontalAlignment:
                Text.AlignHCenter

            font.pixelSize: 13

            textColor:
                Qt.rgba(
                    1,
                    1,
                    1,
                    0.5
                )

            visible:
                Clipboard.available &&
                Clipboard.filteredEntries.length === 0

            text:
                Clipboard.entries.length === 0
                    ? "Clipboard is empty"
                    : "No matching items found"
        }

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 24

            Layout.alignment:
                Qt.AlignHCenter

            horizontalAlignment:
                Text.AlignHCenter

            font.pixelSize: 13

            textColor:
                Theme.colors.danger

            visible:
                !Clipboard.available

            text:
                "cliphist is not installed or available."
        }

        // --------------------------------------------------------
        // List
        // --------------------------------------------------------

        ListView {
            id: listView

            Layout.fillWidth: true

            Layout.preferredHeight:
                Math.min(
                    360,
                    Math.max(
                        52,
                        count * 52
                    )
                )

            clip: true

            model: root.results

            currentIndex:
                root.selectedIndex

            boundsBehavior:
                Flickable.StopAtBounds

            spacing: 2

            delegate: Item {
                id: rowDelegate

                required property var modelData
                required property int index

                width: listView.width
                height: 50

                readonly property bool isSelected:
                    index === root.selectedIndex

                readonly property bool isHovered:
                    rowHover.hovered

                // ------------------------------------------------
                // Selection background
                // ------------------------------------------------

                Rectangle {
                    anchors.fill: parent

                    radius: 12

                    color:
                        rowDelegate.isSelected
                            ? Theme.colors.surfaceAlt
                            : (
                                rowDelegate.isHovered
                                    ? Qt.rgba(
                                        1,
                                        1,
                                        1,
                                        0.04
                                      )
                                    : "transparent"
                              )

                    Behavior on color {
                        ColorAnimation {
                            duration:
                                MotionConfig.hover()
                        }
                    }
                }

                // ------------------------------------------------
                // Active accent
                // ------------------------------------------------

                Rectangle {
                    width: 3
                    radius: 2

                    color:
                        Theme.colors.accent

                    anchors.left:
                        parent.left

                    anchors.leftMargin: 2

                    anchors.verticalCenter:
                        parent.verticalCenter

                    height:
                        parent.height * 0.5

                    opacity:
                        rowDelegate.isSelected
                            ? 1
                            : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration:
                                MotionConfig.hover()
                        }
                    }
                }

                // ------------------------------------------------
                // Content
                // ------------------------------------------------

                RowLayout {
                    anchors.fill: parent

                    anchors.leftMargin: 14
                    anchors.rightMargin: 12

                    spacing: 12

                    // ------------------------------------------------
                    // Thumbnail / icon
                    // ------------------------------------------------

                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34

                        // Image thumbnail

                        Rectangle {
                            anchors.fill: parent

                            radius: 8

                            color:
                                Qt.rgba(
                                    1,
                                    1,
                                    1,
                                    0.06
                                )

                            visible:
                                rowDelegate.modelData.isImage

                            clip: true

                            Image {
                                anchors.fill: parent

                                visible:
                                    rowDelegate.modelData
                                        .thumbnailReady === true

                                source:
                                    rowDelegate.modelData
                                        .thumbnailReady === true
                                        ? rowDelegate.modelData.thumbnail
                                        : ""

                                fillMode:
                                    Image.PreserveAspectCrop

                                smooth: true
                                asynchronous: true
                                cache: true
                            }

                            // Only show an icon while
                            // the thumbnail is unavailable.

                            Icon {
                                anchors.centerIn: parent

                                visible:
                                    rowDelegate.modelData
                                        .thumbnailReady !== true

                                icon:
                                    "image"

                                size: 16

                                iconColor:
                                    Theme.colors.accent
                            }

                            Rectangle {
                                anchors.fill: parent

                                radius: 8

                                color:
                                    "transparent"

                                border.color:
                                    Qt.rgba(
                                        1,
                                        1,
                                        1,
                                        0.1
                                    )

                                border.width: 0.5
                            }
                        }

                        // ------------------------------------------------
                        // Text content icon
                        // ------------------------------------------------

                        Rectangle {
                            anchors.fill: parent

                            radius: 8

                            color:
                                Qt.rgba(
                                    1,
                                    1,
                                    1,
                                    0.06
                                )

                            visible:
                                !rowDelegate.modelData.isImage

                            Icon {
                                anchors.centerIn: parent

                                icon:
                                    "content_paste"

                                size: 16

                                iconColor:
                                    Qt.rgba(
                                        1,
                                        1,
                                        1,
                                        0.8
                                    )
                            }
                        }
                    }

                    // ------------------------------------------------
                    // Text
                    // ------------------------------------------------

                    ColumnLayout {
                        Layout.fillWidth: true

                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true

                            font.pixelSize: 13

                            font.weight:
                                rowDelegate.modelData.isImage
                                    ? Font.DemiBold
                                    : Font.Normal

                            textColor:
                                Qt.rgba(
                                    1,
                                    1,
                                    1,
                                    0.9
                                )

                            elide:
                                Text.ElideRight

                            maximumLineCount: 1

                            text:
                                rowDelegate.modelData.isImage
                                    ? "Image"
                                    : rowDelegate
                                        .modelData
                                        .preview
                        }

                        StyledText {
                            Layout.fillWidth: true

                            font.pixelSize: 11

                            textColor:
                                Qt.rgba(
                                    1,
                                    1,
                                    1,
                                    0.5
                                )

                            elide:
                                Text.ElideRight

                            maximumLineCount: 1

                            text:
                                rowDelegate.modelData.isImage
                                    ? rowDelegate
                                        .modelData
                                        .preview
                                    : ""

                            visible:
                                rowDelegate.modelData.isImage
                        }
                    }

                    // ------------------------------------------------
                    // Delete
                    // ------------------------------------------------

                    IconButton {
                        icon: "close"

                        size: 26
                        iconSize: 13

                        opacity:
                            rowDelegate.isHovered ||
                            rowDelegate.isSelected
                                ? 0.8
                                : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration:
                                    MotionConfig.hover()
                            }
                        }

                        onClicked:
                            Clipboard.deleteEntry(
                                rowDelegate
                                    .modelData
                                    .id
                            )
                    }
                }

                HoverHandler {
                    id: rowHover

                    cursorShape:
                        Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.selectedIndex =
                            index

                        root.activateSelection()
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // Startup
    // ------------------------------------------------------------

    Component.onCompleted: {
        Clipboard.refresh()
        searchFieldFocus()

        if (MotionConfig.reduceMotion) {
            root.opacity = 1
            root.scale = 1
        } else {
            appearAnimation.start()
        }
    }
}