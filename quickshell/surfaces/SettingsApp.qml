import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "settings/pages"

// 1320px settings window: searchable sidebar left, scrolling page right.

PopupPanel {
    id: root

    open: UiState.settingsOpen
    width: 1320
    cornerRadius: 24
    backgroundColor: Theme.colors.background

    readonly property int sidebarWidth: 220
    readonly property int bottomInset: 16
    implicitHeight: contentFlick.y + contentFlick.contentHeight + bottomInset

    readonly property var navItems: [
        { title: "Bar & Island", icon: "crop_landscape", page: 0 },
        { title: "Clock & Date", icon: "schedule", page: 1 },
        { title: "Appearance", icon: "palette", page: 2 },
        { title: "Motion", icon: "sensors", page: 3 },
        { title: "Notifications", icon: "notifications", page: 4 },
        { title: "System", icon: "settings", page: 5 }
    ]

    // A stored index from an older build falls back to the first page.
    readonly property int current: (Config.currentPage >= 0 && Config.currentPage < navItems.length)
        ? Config.currentPage : 0
    readonly property string query: search.text
    readonly property var visibleNav: query.length === 0 ? navItems
        : navItems.filter(function (n) { return n.title.toLowerCase().indexOf(query.toLowerCase()) !== -1 })

    function select(page) { Config.set("currentPage", page) }
    function step(delta) {
        const next = Math.max(0, Math.min(navItems.length - 1, current + delta));
        if (next !== current) select(next);
    }

    onCurrentChanged: contentFlick.contentY = 0

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
                    color: Theme.cc.card

                    SearchField {
                        id: search
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        fieldHeight: 36
                        placeholderText: "Search Settings"
                    }
                }

                ListView {
                    id: navList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 5
                    model: root.visibleNav

                    delegate: Rectangle {
                        id: navRow
                        required property var modelData

                        readonly property bool active: root.current === navRow.modelData.page

                        width: navList.width
                        height: 40
                        radius: 10
                        color: navRow.active ? Qt.alpha(Theme.colors.accent, 0.18)
                            : (navHover.containsMouse ? Theme.cc.itemHover : "transparent")
                        Behavior on color { ColorAnimation { duration: Config.hover() } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: Theme.colors.accent
                                opacity: navRow.active ? 1 : 0.3
                                Behavior on opacity { NumberAnimation { duration: Config.fade() } }

                                Icon {
                                    anchors.centerIn: parent
                                    icon: navRow.modelData.icon
                                    size: 15
                                    iconColor: Theme.colors.accentText
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: navRow.modelData.title
                                font.pixelSize: Theme.px(13)
                                font.weight: navRow.active ? Font.DemiBold : Font.Normal
                                color: navRow.active ? Theme.colors.text
                                                     : Theme.withAlpha(Theme.colors.text, 0.75)
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: navHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.select(navRow.modelData.page)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: root.visibleNav.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "No matches"
                    font.pixelSize: Theme.px(12)
                    color: Theme.withAlpha(Theme.colors.text, 0.4)
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.cc.border
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

                    Repeater {
                        model: ["arrow_back", "arrow_forward"]

                        Rectangle {
                            required property var modelData
                            required property int index

                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 8
                            color: stepHover.containsMouse ? Theme.cc.itemHover : Theme.cc.item
                            Behavior on color { ColorAnimation { duration: Config.hover() } }

                            Icon {
                                anchors.centerIn: parent
                                icon: modelData
                                size: 15
                                iconColor: Theme.withAlpha(Theme.colors.text, 0.7)
                            }

                            MouseArea {
                                id: stepHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.step(index === 0 ? -1 : 1)
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
                        spacing: 12

                        // One page laid out at a time; the rest take no height.
                        BarIslandPage   { Layout.fillWidth: true; visible: root.current === 0 }
                        ClockDatePage   { Layout.fillWidth: true; visible: root.current === 1 }
                        AppearancePage  { Layout.fillWidth: true; visible: root.current === 2 }
                        MotionPage      { Layout.fillWidth: true; visible: root.current === 3 }
                        NotificationsPage { Layout.fillWidth: true; visible: root.current === 4 }
                        SystemPage      { Layout.fillWidth: true; visible: root.current === 5 }
                    }
                }
            }
        }
    }
}
