import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import "../services"

Surface {
    id: root

    cornerRadius: 20
    backgroundColor: Theme.panelFill

    property var results: AppLauncher.results

    property int selectedIndex: 0
    property int hoverIndex: -1

    
    
    
    
    implicitHeight: column.implicitHeight + 38

    transformOrigin: Item.Center

    opacity: 0
    scale: 0.96

    signal activated(var result)

    
    
    

    Timer {
        id: searchDebounce

        interval: 180
        repeat: false

        onTriggered: {
            searchTransition.restart()
        }
    }

    function queueSearch() {
        
        
        searchDebounce.restart()
    }

    function applySearchImmediately() {
        AppLauncher.setQuery(searchField.text)

        selectedIndex = 0
        hoverIndex = -1

        resultsArea.opacity = 1
    }

    
    
    

    SequentialAnimation {
        id: searchTransition

        
        NumberAnimation {
            target: resultsArea
            property: "opacity"

            to: 0

            duration: MotionConfig.fade(0.275)
            easing.type: Easing.OutQuad
        }

        
        ScriptAction {
            script: {
                AppLauncher.setQuery(searchField.text)

                selectedIndex = 0
                hoverIndex = -1
            }
        }

        
        NumberAnimation {
            target: resultsArea
            property: "opacity"

            from: 0
            to: 1

            duration: MotionConfig.fade(0.45)
            easing.type: Easing.OutQuad
        }
    }

    
    
    

    function moveSelection(delta) {
        if (results.length === 0)
            return

        hoverIndex = -1

        selectedIndex = Math.max(
            0,
            Math.min(
                results.length - 1,
                selectedIndex + delta
            )
        )
    }

    function activateSelection() {
        if (results.length === 0)
            return

        root.activated(results[selectedIndex])
    }

    
    
    

    function searchFieldFocus() {
        searchField.text = ""

        selectedIndex = 0
        hoverIndex = -1

        searchField.focusInput()
    }

    function searchFieldHasFocus(): bool {
        return searchField.hasFocus
    }

    onVisibleChanged: {
        if (visible)
            focusRetry.restart()
    }

    Timer {
        id: focusRetry

        interval: 60
        repeat: true

        onTriggered: {
            if (!root.visible || searchField.hasFocus) {
                stop()
                return
            }

            root.searchFieldFocus()
        }
    }

    
    
    

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
            damping: MotionConfig.springDamping
            mass: 0.7
        }
    }

    
    
    

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        
        
        anchors.topMargin: 21
        anchors.bottomMargin: 17

        spacing: 0

        
        
        

        RowLayout {
            Layout.fillWidth: true
            
            Layout.preferredHeight: 32

            Layout.leftMargin: 8
            Layout.rightMargin: 8

            SearchField {
                id: searchField

                Layout.fillWidth: true

                placeholderText: "Search..."

                onNavigateDown: {
                    root.moveSelection(1)
                }

                onNavigateUp: {
                    root.moveSelection(-1)
                }

                Keys.onDownPressed: {
                    root.moveSelection(1)
                }

                Keys.onUpPressed: {
                    root.moveSelection(-1)
                }

                Keys.onEscapePressed: {
                    UiState.closeAll()
                }

                onAccepted: {
                    root.activateSelection()
                }

                onTextChanged: {
                    if (MotionConfig.reduceMotion) {
                        searchDebounce.stop()
                        root.applySearchImmediately()
                    } else {
                        root.queueSearch()
                    }
                }
            }
        }

        
        
        

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1

            
            
            
            Layout.topMargin: 8
            Layout.bottomMargin: 11

            color: Qt.rgba(1, 1, 1, 0.08)

            visible:
                root.results.length > 0
        }

        
        
        

        Item {
            id: resultsArea

            Layout.fillWidth: true

            
            Layout.preferredHeight:
                Math.min(
                    Math.max(1, root.results.length),
                    Math.max(1, ConfigStore.launcherRowsBeforeScrolling)
                ) * ConfigStore.launcherRowHeight

            clip: true

            opacity: 1

            Behavior on Layout.preferredHeight {
                enabled: !MotionConfig.reduceMotion

                NumberAnimation {
                    duration: MotionConfig.movement(0.35)
                    easing.type: Easing.OutCubic
                }
            }

            Flickable {
                id: resultsFlick
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: Math.max(1, root.results.length) * ConfigStore.launcherRowHeight

            
            
            

            Rectangle {
                id: selectionSurface

                z: 0

                x: 0
                width: resultsArea.width
                height: ConfigStore.launcherRowHeight

                radius: 12

                property int targetIndex:
                    root.hoverIndex >= 0
                        ? root.hoverIndex
                        : root.selectedIndex

                y: targetIndex * ConfigStore.launcherRowHeight

                
                
                
                
                
                color: "#2b2725"

                visible:
                    root.results.length > 0

                Behavior on y {
                    enabled: !MotionConfig.reduceMotion

                    NumberAnimation {
                        duration: MotionConfig.movement(0.425)
                        easing.type: Easing.OutCubic
                    }
                }

                
                
                Rectangle {
                    width: 3
                    height: 22

                    radius: 2

                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter

                    color: Theme.colors.accent
                }
            }

            
            
            

            Repeater {
                model: root.results

                delegate: ListRow {
                    id: row

                    required property int index
                    required property var modelData

                    z: 1

                    x: 0
                    y: index * ConfigStore.launcherRowHeight

                    width: resultsArea.width
                    height: ConfigStore.launcherRowHeight

                    icon: modelData.icon
                    iconSource: modelData.iconSource || ""

                    title: modelData.title
                    subtitle: modelData.subtitle

                    selected:
                        index === root.selectedIndex

                    
                    animateAppearance: false

                    onHovered: {
                        root.hoverIndex = index
                    }

                    onClicked: {
                        root.selectedIndex = index
                        root.hoverIndex = -1

                        root.activateSelection()
                    }
                }
            }

            
            HoverHandler {
                onHoveredChanged: {
                    if (!hovered)
                        root.hoverIndex = -1
                }
            }
            } 
        }
    }

    
    
    

    Component.onCompleted: {
        if (MotionConfig.reduceMotion) {
            root.opacity = 1
            root.scale = 1
            resultsArea.opacity = 1
        } else {
            appearAnimation.start()
        }
    }
}