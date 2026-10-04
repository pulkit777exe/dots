import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// ClipboardRow.qml -- one clipboard entry, as a row.
//
// Extracted from ClipboardHistory.qml. The panel owns which entry is
// selected, and what tapping or deleting one means; this file owns what a
// single entry looks like: the hover and selection backgrounds, the accent
// bar down the left, the thumbnail (or the paste icon when the entry is
// text), the one or two lines of preview, and the delete button that only
// appears once the row is hovered or selected.
//
// `entry` is one element of Clipboard.entries, the shape
// services/Clipboard.qml parses out of `cliphist list`: id, preview,
// isImage, thumbnail, thumbnailReady. `selected` is passed in rather than
// read from a shared index, so this file knows nothing about the list it
// happens to sit in.
//
// The height is this file's because the panel's ListView viewport is sized
// in rows (count * 52 -- 50 of row plus 2 of spacing). Changing one without
// the other is the mistake; only one of them can be read next to the other
// from here, so the 50 stays next to the arithmetic in ClipboardHistory.qml.

Item {
    id: root

    property var entry
    property bool selected: false

    signal activated()
    signal deleteRequested()

    height: 50

    readonly property bool isHovered:
        rowHover.hovered


    Rectangle {
        anchors.fill: parent

        radius: 12

        color:
            root.selected
                ? Theme.colors.surfaceAlt
                : (
                    root.isHovered
                        ? Theme.withAlpha(Theme.colors.text, 0.04)
                        : "transparent"
                  )

        Behavior on color {
            ColorAnimation {
                duration:
                    MotionConfig.hover()
            }
        }
    }


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
            root.selected
                ? 1
                : 0

        Behavior on opacity {
            NumberAnimation {
                duration:
                    MotionConfig.hover()
            }
        }
    }


    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: 14
        anchors.rightMargin: 12

        spacing: 12


        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34


            Rectangle {
                anchors.fill: parent

                radius: 8

                color:
                    Theme.colors.surface

                visible:
                    root.entry.isImage

                clip: true

                Image {
                    anchors.fill: parent

                    visible:
                        root.entry
                            .thumbnailReady === true

                    source:
                        root.entry
                            .thumbnailReady === true
                            ? root.entry.thumbnail
                            : ""

                    fillMode:
                        Image.PreserveAspectCrop

                    smooth: true
                    asynchronous: true
                    cache: true
                }


                Icon {
                    anchors.centerIn: parent

                    visible:
                        root.entry
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
                        Theme.colors.border

                    border.width: 0.5
                }
            }


            Rectangle {
                anchors.fill: parent

                radius: 8

                color:
                    Theme.colors.surface

                visible:
                    !root.entry.isImage

                Icon {
                    anchors.centerIn: parent

                    icon:
                        "content_paste"

                    size: 16

                    iconColor:
                        Theme.withAlpha(Theme.colors.text, 0.8)
                }
            }
        }


        ColumnLayout {
            Layout.fillWidth: true

            spacing: 2

            StyledText {
                Layout.fillWidth: true

                font.pixelSize: 13

                font.weight:
                    root.entry.isImage
                        ? Font.DemiBold
                        : Font.Normal

                textColor:
                    Theme.withAlpha(Theme.colors.text, 0.9)

                elide:
                    Text.ElideRight

                maximumLineCount: 1

                text:
                    root.entry.isImage
                        ? "Image"
                        : root.entry.preview
            }

            StyledText {
                Layout.fillWidth: true

                font.pixelSize: 11

                textColor:
                    Theme.withAlpha(Theme.colors.text, 0.5)

                elide:
                    Text.ElideRight

                maximumLineCount: 1

                text:
                    root.entry.isImage
                        ? root.entry.preview
                        : ""

                visible:
                    root.entry.isImage
            }
        }


        IconButton {
            icon: "close"

            size: 26
            iconSize: 13

            opacity:
                root.isHovered ||
                root.selected
                    ? 0.8
                    : 0

            Behavior on opacity {
                NumberAnimation {
                    duration:
                        MotionConfig.hover()
                }
            }

            onClicked:
                root.deleteRequested()
        }
    }


    HoverHandler {
        id: rowHover

        cursorShape:
            Qt.PointingHandCursor
    }

    TapHandler {
        onTapped:
            root.activated()
    }
}
