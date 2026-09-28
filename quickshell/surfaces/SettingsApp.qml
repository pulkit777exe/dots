pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "settings/pages"

Surface {
    id: root

    // 1320 x 969, measured off 2026-09-20_22-29-35 by matching the window
    // background colour exactly: the panel spans x 301..1620 and y 77..1043
    // on a 1920x1080 screen, i.e. dead centre horizontally.
    //
    // An earlier measurement of 1346 x 971 was wrong -- it was triggered by
    // the teal wallpaper bleeding past the panel's rounded corners, not by
    // the panel itself. Matching on a single interior colour is what makes
    // the bounds trustworthy.
    width: 1320
    implicitHeight: 969
    cornerRadius: 24
    // Pure black. The reference's content plane samples as exactly (0,0,0);
    // the sidebar is a separate, slightly lighter wash (see leftPane).
    backgroundColor: "#000000"

    property int currentPage: ConfigStore.currentPage
    // 220 in the reference: the nav column ends just past x 520, with the
    // window's left edge at 300.
    property real sidebarWidth: 220

    onCurrentPageChanged: ConfigStore.setCurrentPage(currentPage)

    Connections {
        target: ConfigStore
        function onCurrentPageChanged() {
            if (ConfigStore.currentPage !== root.currentPage)
                root.currentPage = ConfigStore.currentPage
        }
    }

    // The reference lists nine pages. Display (1) and Media (10) are absent
    // from its sidebar, so they are absent here too -- but both pages still
    // exist and are still reachable via ConfigStore.setCurrentPage; they are
    // only hidden from the nav, not deleted.
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

    // Sidebar order for the back / forward arrows, derived from navItems so
    // the two cannot drift apart. (The previous hardcoded list had to be
    // edited by hand in two places whenever a page moved.)
    readonly property var navOrder: navItems.map(function (n) { return n.page })

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

            // The sidebar is a shade lighter than the content plane: the
            // window is pure black, the reference's sidebar samples (7,7,7),
            // which is white at ~2.8% over black.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.028)
            }

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
                    // 40 + 5 = a 45px row pitch. Measured off the reference:
                    // badge centres sit at y 150 (Bar & Island) and y 284
                    // (Motion), three rows apart -- 44.7px per row. This was
                    // 38 + 4 = 42, so the whole nav sat ~8px tighter.
                    spacing: 5
                    model: root.navItems

                    delegate: Rectangle {
                        id: navRow
                        required property var modelData

                        readonly property bool active: root.currentPage === navRow.modelData.page

                        width: navList.width
                        height: 40
                        radius: 10
                        // The active row is a warm dark grey, (40,35,34) in
                        // the reference, against a (7,7,7) sidebar -- not a
                        // neutral white wash, which is what this used.
                        color: navRow.active ? Qt.rgba(1, 0.92, 0.88, 0.155)
                                             : (rowHover.hovered ? Qt.rgba(1, 0.92, 0.88, 0.06) : "transparent")

                        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

                        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.currentPage = navRow.modelData.page }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            // Teal disc. Inactive badges are the accent at 44%
                            // over the sidebar -- the reference samples them at
                            // (23,91,80) -- and the active one is the accent at
                            // full strength, (62,208,175). The icon inside is
                            // near-black either way.
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
                                    iconColor: navRow.active ? "#000000" : Qt.rgba(0, 0.165, 0.098, 1)
                                }
                            }

                            StyledText {
                                text: navRow.modelData.title
                                font.pixelSize: 13
                                font.weight: navRow.active ? Font.DemiBold : Font.Normal
                                color: navRow.active ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.85)
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
                // 24 left / 25 right, not a uniform 16. The reference's content
                // card spans x 546..1595 (2026-09-20_22-30-13); a uniform 16 put
                // mine at 537..1603 -- the right width, but 9px too far left and
                // 8 too far right. The window's rounded corner eats into the
                // right margin, which is why the two sides are not equal.
                anchors.leftMargin: 24
                anchors.rightMargin: 25
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                // 6, not 12. The reference's first card starts 52px below the
                // window's top edge, and 16 (margin) + 30 (button row) + 6
                // lands exactly there. At 12 the whole page sat 6px low.
                spacing: 6

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
                                const idx = root.navOrder.indexOf(root.currentPage)
                                if (idx > 0) root.currentPage = root.navOrder[idx - 1]
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
                                const idx = root.navOrder.indexOf(root.currentPage)
                                if (idx >= 0 && idx < root.navOrder.length - 1) root.currentPage = root.navOrder[idx + 1]
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
