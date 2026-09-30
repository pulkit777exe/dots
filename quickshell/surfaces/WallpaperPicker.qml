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

    
    
    
    
    
    
    
    
    width: 1008
    implicitHeight: 222
    cornerRadius: 20

    
    
    
    
    
    readonly property real itemW: 170
    readonly property real itemH: 113
    readonly property real cardSpacing: 16

    
    
    

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

            delegate: Item {
                
                
                
                
                id: card

                required property string source
                required property bool selected
                required property string fileName
                required property int index

                width: root.itemW
                height: root.itemH

                
                
                
                
                
                
                
                
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
                            card.source

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