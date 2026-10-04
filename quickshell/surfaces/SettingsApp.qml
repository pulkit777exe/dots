pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "settings/pages"

Surface {
    id: root

    
    
    
    
    
    
    
    
    width: 1320

    // The window follows its content instead of a height kept in step by hand.
    // A hand-kept 969 outlived the tallest page by ~270px and had to be nudged
    // upward by hand every time a page gained a row -- the drift is invisible in
    // the source and obvious on screen as dead space under the last card. This
    // is the same bug class Phase 3 of todos.md records for the bar window.
    //
    // contentFlick.y rather than a measured header height, so the chrome above
    // the scroller is accounted for by the layout itself and cannot drift.
    // contentHeight, not the Flickable's own height: that one is derived from
    // the window, so reading it back would feed the result into its own input.
    readonly property real bottomInset: 16
    implicitHeight: contentFlick.y
        + contentFlick.contentHeight
        + bottomInset

    cornerRadius: 24
    
    
    backgroundColor: Theme.colors.background

    property int currentPage: ConfigStore.currentPage
    
    
    property real sidebarWidth: 220

    onCurrentPageChanged: ConfigStore.setCurrentPage(currentPage)

    Connections {
        target: ConfigStore
        function onCurrentPageChanged() {
            if (ConfigStore.currentPage !== root.currentPage)
                root.currentPage = ConfigStore.currentPage
        }
    }

    
    
    
    
    readonly property var navItems: [
        { title: "Bar & Island", icon: "crop_landscape", page: 0 },
        { title: "Clock & Date", icon: "schedule", page: 2 },
        { title: "Appearance", icon: "palette", page: 3 },
        { title: "Motion", icon: "sensors", page: 4 },
        { title: "Launcher", icon: "search", page: 5 },
        { title: "Notifications", icon: "notifications", page: 6 },
        { title: "Control Center", icon: "tune", page: 7 },
        { title: "Lock Screen", icon: "lock", page: 8 },
        { title: "System", icon: "settings", page: 9 }
    ]

    
    
    
    readonly property var navOrder: navItems.map(function (n) { return n.page })

    RowLayout {
        anchors.fill: parent
        spacing: 0

        
        
        
        Item {
            id: leftPane
            Layout.preferredWidth: root.sidebarWidth
            Layout.fillHeight: true

            
            
            
            Rectangle {
                anchors.fill: parent
                color: Theme.withAlpha(Theme.colors.text, 0.028)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Theme.colors.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Icon {
                            icon: "search"
                            size: 16
                            iconColor: Theme.withAlpha(Theme.colors.text, 0.4)
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: Theme.colors.text
                            font.pixelSize: 13
                            clip: true
                            Text {
                                text: "Search Settings"
                                color: Theme.withAlpha(Theme.colors.text, 0.35)
                                font.pixelSize: 13
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }
                    }
                }

                
                ListView {
                    id: navList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    
                    
                    
                    spacing: 5
                    model: root.navItems

                    delegate: Rectangle {
                        id: navRow
                        required property var modelData

                        readonly property bool active: root.currentPage === navRow.modelData.page

                        width: navList.width
                        height: 40
                        radius: 10
                        
                        
                        
                        color: navRow.active ? Theme.colors.surfaceAlt
                                             : (rowHover.hovered ? Theme.colors.surface : "transparent")

                        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.currentPage = navRow.modelData.page }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            
                            
                            
                            
                            
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: width / 2
                                color: Theme.colors.accent
                                opacity: navRow.active ? 1.0 : 0.44

                                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade() } }

                                Icon {
                                    anchors.centerIn: parent
                                    icon: navRow.modelData.icon
                                    size: 15
                                    // Both branches were a dark glyph on the
                                    // accent dot -- #000000 and a dark green --
                                    // which is what accentText is; the dot's own
                                    // opacity already carries the state.
                                    iconColor: Theme.colors.accentText
                                }
                            }

                            StyledText {
                                text: navRow.modelData.title
                                font.pixelSize: 13
                                font.weight: navRow.active ? Font.DemiBold : Font.Normal
                                color: navRow.active ? Theme.colors.text : Theme.withAlpha(Theme.colors.text, 0.85)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.colors.divider
        }

        
        
        
        Item {
            id: rightPane
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                
                
                
                
                
                anchors.leftMargin: 24
                anchors.rightMargin: 25
                anchors.topMargin: 16
                anchors.bottomMargin: root.bottomInset
                
                
                
                spacing: 6

                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 8
                        color: Theme.colors.surface

                        Icon {
                            anchors.centerIn: parent
                            icon: "arrow_back"
                            size: 15
                            iconColor: Theme.withAlpha(Theme.colors.text, 0.6)
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const idx = root.navOrder.indexOf(root.currentPage)
                                if (idx > 0) root.currentPage = root.navOrder[idx - 1]
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 8
                        color: Theme.colors.surface

                        Icon {
                            anchors.centerIn: parent
                            icon: "arrow_forward"
                            size: 15
                            iconColor: Theme.withAlpha(Theme.colors.text, 0.6)
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const idx = root.navOrder.indexOf(root.currentPage)
                                if (idx >= 0 && idx < root.navOrder.length - 1) root.currentPage = root.navOrder[idx + 1]
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                
                Flickable {
                    id: contentFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: flickCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: flickCol
                        width: contentFlick.width

                        
                        PagePanel {
                            pageIndex: 0
                            currentPage: root.currentPage
                            BarIslandPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 1
                            currentPage: root.currentPage
                            DisplayPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 2
                            currentPage: root.currentPage
                            ClockDatePage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 3
                            currentPage: root.currentPage
                            AppearancePage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 4
                            currentPage: root.currentPage
                            MotionPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 5
                            currentPage: root.currentPage
                            LauncherPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 6
                            currentPage: root.currentPage
                            NotificationsPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 10
                            currentPage: root.currentPage
                            MediaPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 7
                            currentPage: root.currentPage
                            ControlCenterPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 8
                            currentPage: root.currentPage
                            LockScreenPage { width: parent.width }
                        }

                        
                        PagePanel {
                            pageIndex: 9
                            currentPage: root.currentPage
                            SystemPage { width: parent.width }
                        }
                    }
                }
            }
        }
    }
}
