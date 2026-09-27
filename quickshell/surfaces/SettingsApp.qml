pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "settings/pages"

Surface {
    id: root

    width: 820
    implicitHeight: 580
    cornerRadius: 24
    backgroundColor: Qt.rgba(0.06, 0.06, 0.06, 0.98)

    property int currentPage: ConfigStore.currentPage
    property real sidebarWidth: 230

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
        { title: "Display", icon: "brightness_high", page: 1 },
        { title: "Clock & Date", icon: "schedule", page: 2 },
        { title: "Appearance", icon: "palette", page: 3 },
        { title: "Motion", icon: "sensors", page: 4 },
        { title: "Launcher", icon: "search", page: 5 },
        { title: "Notifications", icon: "notifications", page: 6 },
        { title: "Media", icon: "music_note", page: 10 },
        { title: "Control Center", icon: "tune", page: 7 },
        { title: "Lock Screen", icon: "lock", page: 8 },
        { title: "System", icon: "settings", page: 9 }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ========================================================
        // LEFT SIDEBAR (Reference 5)
        // ========================================================
        Item {
            id: leftPane
            Layout.preferredWidth: root.sidebarWidth
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Search field
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.06)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Icon {
                            icon: "search"
                            size: 16
                            iconColor: Qt.rgba(1, 1, 1, 0.4)
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            clip: true
                            Text {
                                text: "Search Settings"
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font.pixelSize: 13
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }
                    }
                }

                // Nav List
                ListView {
                    id: navList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.navItems

                    delegate: Rectangle {
                        id: navRow
                        required property var modelData

                        width: navList.width
                        height: 38
                        radius: 10
                        color: root.currentPage === navRow.modelData.page ? Qt.rgba(1, 1, 1, 0.10) : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.currentPage = navRow.modelData.page }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            // Teal rounded square badge
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 7
                                color: Qt.rgba(Theme.colors.accent.r, Theme.colors.accent.g, Theme.colors.accent.b, 0.22)

                                Icon {
                                    anchors.centerIn: parent
                                    icon: navRow.modelData.icon
                                    size: 15
                                    iconColor: Theme.colors.accent
                                }
                            }

                            StyledText {
                                text: navRow.modelData.title
                                font.pixelSize: 13
                                font.weight: root.currentPage === navRow.modelData.page ? Font.DemiBold : Font.Normal
                                color: root.currentPage === navRow.modelData.page ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.75)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Splitter line
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // ========================================================
        // RIGHT MAIN PANE
        // ========================================================
        Item {
            id: rightPane
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Top Navigation Bar (Back / Forward arrows)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)

                        Icon {
                            anchors.centerIn: parent
                            icon: "arrow_back"
                            size: 15
                            iconColor: Qt.rgba(1, 1, 1, 0.6)
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const pages = [0, 1, 2, 3, 4, 5, 6, 10, 7, 8, 9]
                                const idx = pages.indexOf(root.currentPage)
                                if (idx > 0) root.currentPage = pages[idx - 1]
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)

                        Icon {
                            anchors.centerIn: parent
                            icon: "arrow_forward"
                            size: 15
                            iconColor: Qt.rgba(1, 1, 1, 0.6)
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                const pages = [0, 1, 2, 3, 4, 5, 6, 10, 7, 8, 9]
                                const idx = pages.indexOf(root.currentPage)
                                if (idx >= 0 && idx < pages.length - 1) root.currentPage = pages[idx + 1]
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Scrollable Content
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

                        // PAGE 0 — Bar & Island
                        PagePanel {
                            pageIndex: 0
                            currentPage: root.currentPage
                            BarIslandPage { width: parent.width }
                        }

                        // PAGE 1 — Display
                        PagePanel {
                            pageIndex: 1
                            currentPage: root.currentPage
                            DisplayPage { width: parent.width }
                        }

                        // PAGE 2 — Clock & Date
                        PagePanel {
                            pageIndex: 2
                            currentPage: root.currentPage
                            ClockDatePage { width: parent.width }
                        }

                        // PAGE 3 — Appearance
                        PagePanel {
                            pageIndex: 3
                            currentPage: root.currentPage
                            AppearancePage { width: parent.width }
                        }

                        // PAGE 4 — Motion
                        PagePanel {
                            pageIndex: 4
                            currentPage: root.currentPage
                            MotionPage { width: parent.width }
                        }

                        // PAGE 5 — Launcher
                        PagePanel {
                            pageIndex: 5
                            currentPage: root.currentPage
                            LauncherPage { width: parent.width }
                        }

                        // PAGE 6 — Notifications
                        PagePanel {
                            pageIndex: 6
                            currentPage: root.currentPage
                            NotificationsPage { width: parent.width }
                        }

                        // PAGE 10 — Media
                        PagePanel {
                            pageIndex: 10
                            currentPage: root.currentPage
                            MediaPage { width: parent.width }
                        }

                        // PAGE 7 — Control Center
                        PagePanel {
                            pageIndex: 7
                            currentPage: root.currentPage
                            ControlCenterPage { width: parent.width }
                        }

                        // PAGE 8 — Lock Screen
                        PagePanel {
                            pageIndex: 8
                            currentPage: root.currentPage
                            LockScreenPage { width: parent.width }
                        }

                        // PAGE 9 — System
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
