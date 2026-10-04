import QtQuick

import "../services"

// WallpaperCard.qml -- one wallpaper thumbnail.
//
// Extracted from WallpaperPicker.qml. The picker owns which wallpaper is
// current, how the strip scrolls and what applying one means; this file owns
// how a single thumbnail looks: the frame and its border, the image, the dim
// over it, the dot on the wallpaper the theme is currently using, and the
// hover tint.
//
// `source` and `selected` are required properties rather than ones the
// delegate assigns, because they are model roles -- services/ThemeRows.qml's
// wallpaperRows builds both, and asking the view for them by name is how the
// card stays a card rather than something that knows about the strip.
//
// The dim over the image is Qt.rgba black and is not a palette key: a
// wallpaper is arbitrary unknown pixels, and tinting it with a theme colour
// would make the preview lie about what you are about to apply.
//
// cardWidth/cardHeight are properties rather than constants because the
// picker sizes its highlight range and viewport off the same two numbers. It
// passes them in, so the numbers are written down once, in the picker, and
// this file has no copy to fall out of step.

Item {
    id: root

    required property string source
    required property bool selected

    property int cardWidth: 170
    property int cardHeight: 113

    readonly property bool current:
        ListView.isCurrentItem

    signal picked()

    width: cardWidth
    height: cardHeight

    opacity:
        current
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


    Rectangle {
        anchors.fill: parent

        radius: 12
        clip: true

        color:
            Theme.colors.surfaceAlt

        border.width:
            root.selected ? 2 : 1

        border.color:
            root.selected
                ? Theme.colors.accent
                : Theme.colors.border

        Image {
            anchors.fill: parent

            source:
                root.source

            fillMode:
                Image.PreserveAspectCrop

            asynchronous: true
            cache: true
            smooth: true

            // Decoded at about twice the card, so the strip scrolls and snaps
            // without re-decoding a 4K wallpaper per frame.
            sourceSize:
                Qt.size(
                    392,
                    236
                )
        }

        Rectangle {
            anchors.fill: parent

            // A dim over the wallpaper thumbnail, which is
            // arbitrary unknown pixels. Neutral black on
            // purpose: a palette key would tint the photo.
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
                root.selected

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


    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent

        radius: 12

        color:
            hover.hovered &&
            !root.current
                ? Theme.colors.surface
                : "transparent"
    }


    TapHandler {
        onTapped:
            root.picked()
    }
}
