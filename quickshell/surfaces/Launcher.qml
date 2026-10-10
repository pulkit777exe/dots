import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

PopupPanel {
    id: root

    open: UiState.launcherOpen

    width: 550
    cornerRadius: open ? 22 : pillRadius
    backgroundColor: Theme.panelFill

    readonly property var results: AppLauncher.results
    property int selectedIndex: 0

    readonly property int rowHeight: 52
    readonly property int maxVisibleRows: 7

    implicitHeight: column.implicitHeight + 32

    function moveSelection(delta: int) {
        if (results.length === 0) return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        ensureVisible(selectedIndex);
    }

    function ensureVisible(index: int) {
        const top = index * rowHeight;
        if (top < list.contentY)
            list.contentY = top;
        else if (top + rowHeight > list.contentY + list.height)
            list.contentY = Math.max(0, Math.min(top + rowHeight - list.height, list.contentHeight - list.height));
    }

    function launchIndex(index: int) {
        if (index < 0 || index >= results.length) return;
        selectedIndex = index;
        AppLauncher.launch(results[index]);
        UiState.close();
    }

    onOpenChanged: {
        if (open) {
            search.text = "";
            AppLauncher.setQuery("");
            selectedIndex = 0;
            list.contentY = 0;
            focusRetry.restart();
        } else {
            focusRetry.stop();
        }
    }

    Timer {
        id: focusRetry
        interval: 60
        repeat: true
        onTriggered: {
            if (!root.open || search.inputFocused) { stop(); return; }
            search.forceInputFocus();
        }
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        SearchField {
            id: search

            Layout.fillWidth: true
            placeholderText: "Search…"

            onNavigateUp: root.moveSelection(-1)
            onNavigateDown: root.moveSelection(1)
            onAccepted: root.launchIndex(root.selectedIndex)

            onTextChanged: {
                AppLauncher.setQuery(text);
                root.selectedIndex = 0;
                list.contentY = 0;
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 10
            Layout.bottomMargin: 4
            color: Theme.cc.border
        }

        Flickable {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight:
                Math.min(Math.max(1, root.results.length), root.maxVisibleRows) * root.rowHeight

            Behavior on Layout.preferredHeight {
                enabled: !Config.reduceMotion
                NumberAnimation { duration: Config.movement(0.35); easing.type: Easing.OutQuint }
            }

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            contentWidth: width
            contentHeight: Math.max(1, root.results.length) * root.rowHeight

            Repeater {
                model: root.results

                delegate: Item {
                    id: row

                    required property int index
                    required property var modelData

                    x: 0
                    y: index * root.rowHeight
                    width: list.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: row.index === root.selectedIndex
                        radius: 12
                        color: Theme.cc.card
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.index === root.selectedIndex
                        width: 3
                        height: 24
                        radius: 2
                        color: Theme.accentFor("launcher")
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 8
                            clip: true
                            color: Theme.withAlpha(Theme.colors.text, 0.07)

                            Icon {
                                anchors.centerIn: parent
                                icon: row.modelData.glyph
                                size: 15
                                iconColor: Theme.withAlpha(Theme.colors.text, 0.85)
                                visible: iconImage.status !== Image.Ready
                            }

                            Image {
                                id: iconImage
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: row.modelData.iconSource
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                font.pixelSize: Theme.px(14)
                                font.weight: Font.Medium
                                color: Theme.withAlpha(Theme.colors.text, 0.95)
                                elide: Text.ElideRight
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: row.modelData.subtitle
                                font.pixelSize: Theme.px(11)
                                color: Theme.withAlpha(Theme.colors.text, 0.45)
                                elide: Text.ElideRight
                            }
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) root.selectedIndex = row.index;
                        }
                    }

                    TapHandler {
                        onTapped: root.launchIndex(row.index)
                    }
                }
            }
        }
    }
}
