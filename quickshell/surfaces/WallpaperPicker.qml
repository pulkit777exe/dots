import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// Wallpaper strip: title + theme name, a centred run of thumbnails kept
// centred by the highlight range, and a caption + n/total footer.
PopupPanel {
    id: root

    open: UiState.wallpaperPickerOpen
    width: 1000
    implicitHeight: 238
    cornerRadius: Config.expandedRadius
    backgroundColor: Theme.colors.background

    readonly property var walls: Theme.wallpapers
    readonly property int applied: Theme.wallpaperIndexCurrent
    readonly property string themeName: Theme.displayName
    property int currentIndex: 0

    readonly property real itemW: 170
    readonly property real itemH: 113

    function fileName(path) {
        const parts = String(path).split("/")
        return parts[parts.length - 1]
    }

    function resetSelection() {
        currentIndex = walls.length > 0 ? Math.min(applied, walls.length - 1) : 0
    }

    function moveSelection(delta) {
        if (list.count === 0)
            return

        currentIndex = (currentIndex + delta + list.count) % list.count
    }

    function applySelection() {
        if (currentIndex < 0 || currentIndex >= walls.length)
            return

        Theme.setWallpaper(currentIndex)
        UiState.close()
    }

    onOpenChanged: if (open) {
        resetSelection()
        Qt.callLater(() => {
            if (list.count > 0)
                list.positionViewAtIndex(currentIndex, ListView.Center)
        })
    }

    onWallsChanged: resetSelection()

    Keys.onLeftPressed: e => { root.moveSelection(-1); e.accepted = true }
    Keys.onRightPressed: e => { root.moveSelection(1); e.accepted = true }
    Keys.onReturnPressed: e => { root.applySelection(); e.accepted = true }
    Keys.onEnterPressed: e => { root.applySelection(); e.accepted = true }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Wallpaper"
                font.pixelSize: Theme.px(17)
                font.weight: Font.DemiBold
                color: Theme.withAlpha(Theme.colors.text, 0.95)
            }

            Item { Layout.fillWidth: true }

            Label {
                Layout.alignment: Qt.AlignVCenter
                text: root.themeName
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.45)
                elide: Text.ElideRight
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: root.itemH
            orientation: ListView.Horizontal
            spacing: 16
            clip: true
            model: root.walls

            // The current card stays centred and the strip never scrolls past
            // either end, so there is empty panel either side of the ends.
            currentIndex: root.currentIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - root.itemW) / 2
            preferredHighlightEnd: (width - root.itemW) / 2
            highlightMoveDuration: Config.movement(0.7)
            snapMode: ListView.SnapToItem

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                width: root.itemW
                height: root.itemH

                readonly property bool current: ListView.isCurrentItem
                readonly property bool selected: index === root.applied

                opacity: current ? 1 : 0.86
                Behavior on opacity { NumberAnimation { duration: Config.hover() } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    clip: true
                    color: Theme.cc.trackCard
                    border.width: card.selected ? 2 : 1
                    border.color: card.selected ? Theme.colors.accent : Theme.cc.border

                    Image {
                        anchors.fill: parent
                        source: Theme.fileUrl(card.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize: Qt.size(392, 236)
                    }

                    // Neutral dim: a wallpaper is arbitrary unknown pixels.
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.08)
                    }

                    Rectangle {
                        visible: card.selected
                        width: 7
                        height: 7
                        radius: 3.5
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        color: Theme.colors.accent
                    }
                }

                HoverHandler { id: hover }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: hover.hovered && !card.current ? Qt.rgba(0, 0, 0, 0.18) : "transparent"
                }

                TapHandler {
                    onTapped: {
                        root.currentIndex = card.index
                        root.applySelection()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: root.currentIndex >= 0 && root.currentIndex < root.walls.length
                    ? root.fileName(root.walls[root.currentIndex])
                    : ""
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.50)
                elide: Text.ElideMiddle
            }

            Label {
                Layout.alignment: Qt.AlignVCenter
                text: root.walls.length > 0
                    ? (root.currentIndex + 1) + "/" + root.walls.length + " · Enter to apply"
                    : "0/0"
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.35)
            }
        }
    }
}
