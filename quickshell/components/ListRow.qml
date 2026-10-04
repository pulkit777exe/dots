import QtQuick
import QtQuick.Layouts
import "../services"

Item {
    id: root

    property string icon: "apps"
    property string iconSource: ""

    property color iconBackground:
        Theme.withAlpha(Theme.colors.text, 0.08)

    property color iconColor:
        Theme.withAlpha(Theme.colors.text, 0.85)

    property string title: ""
    property string subtitle: ""

    property bool selected: false
    property bool solidBackground: false

    
    property bool animateAppearance: true
    property int appearDelay: 0

    readonly property bool hasThemedIcon:
        iconSource.length > 0

    readonly property string resolvedIconSource: {
        if (!hasThemedIcon)
            return ""

        if (iconSource.startsWith("file://") ||
            iconSource.startsWith("image://"))
            return iconSource

        if (iconSource.startsWith("/"))
            return "file://" + iconSource

        return "image://icon/" + iconSource
    }

    property bool themedIconFailed: false

    signal clicked()
    signal hovered()

    implicitHeight: 52
    height: implicitHeight

    opacity: animateAppearance ? 0 : 1

    
    
    

    SequentialAnimation {
        id: appearAnimation

        running: root.animateAppearance

        PauseAnimation {
            duration:
                MotionConfig.reduceMotion
                    ? 0
                    : root.appearDelay
        }

        NumberAnimation {
            target: root
            property: "opacity"

            to: 1

            duration: MotionConfig.fade()

            easing.type: Easing.OutCubic
        }
    }

    
    
    

    Rectangle {
        anchors.fill: parent

        radius: 12

        color:
            root.solidBackground
                ? Theme.surfaceRaised
                : "transparent"
    }

    
    
    

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: 16
        anchors.rightMargin: 16

        spacing: 12

        StyledRect {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            radius: 8

            baseColor:
                root.iconBackground

            clip: true

            Icon {
                anchors.centerIn: parent

                visible:
                    !root.hasThemedIcon ||
                    root.themedIconFailed

                icon: root.icon
                size: 16
                iconColor: root.iconColor
            }

            Image {
                id: themedIcon

                anchors.centerIn: parent

                width: 20
                height: 20

                visible:
                    root.hasThemedIcon &&
                    !root.themedIconFailed

                source:
                    root.resolvedIconSource

                fillMode:
                    Image.PreserveAspectFit

                smooth: true
                asynchronous: true
                cache: true

                onStatusChanged: {
                    if (status === Image.Error)
                        root.themedIconFailed = true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true

            spacing: 1

            StyledText {
                Layout.fillWidth: true

                variant: "mediaTitle"
                font.pixelSize: 13

                text: root.title

                elide:
                    Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true

                variant: "mediaSubtitle"
                font.pixelSize: 11

                text: root.subtitle

                elide:
                    Text.ElideRight

                visible:
                    root.subtitle.length > 0
            }
        }
    }

    
    
    

    HoverHandler {
        id: hoverHandler

        cursorShape:
            Qt.PointingHandCursor

        onHoveredChanged: {
            if (hovered)
                root.hovered()
        }
    }

    TapHandler {
        id: tapHandler

        onTapped: {
            root.clicked()
        }
    }

    
    
    

    scale:
        tapHandler.pressed
            ? 0.97
            : 1.0

    Behavior on scale {
        enabled:
            !MotionConfig.reduceMotion

        SpringAnimation {
            spring: 5
            damping: MotionConfig.springDamping
            mass: 0.5
        }
    }

    onIconSourceChanged: {
        themedIconFailed = false
    }
}