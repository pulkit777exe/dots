import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "./pages"

PopupPanel {
    id: root

    open: UiState.settingsOpen
    width: 1320
    cornerRadius: open ? 24 : pillRadius
    backgroundColor: Theme.colors.background

    readonly property int sidebarWidth: 220
    readonly property int bottomInset: 16
    readonly property real chromeHeight: 16 + 30 + 6 + bottomInset
    property real maxHeight: 0
    implicitHeight: Math.min(chromeHeight + contentFlick.contentHeight,
                              maxHeight > 0 ? maxHeight : 1e9)

    readonly property var navItems: [
        { title: "Bar & Island", icon: "crop_landscape", page: 0 },
        { title: "Clock & Date", icon: "schedule", page: 1 },
        { title: "Appearance", icon: "palette", page: 2 },
        { title: "Motion", icon: "sensors", page: 3 },
        { title: "Notifications", icon: "notifications", page: 4 },
        { title: "System", icon: "settings", page: 5 },
        { title: "Sound", icon: "volume_up", page: 6 },
        { title: "Display", icon: "monitor", page: 7 },
        { title: "Network", icon: "wifi", page: 8 },
        { title: "Bluetooth", icon: "bluetooth", page: 9 },
        { title: "Power", icon: "power_settings_new", page: 10 }
    ]

    property var keyOf: ({})

    readonly property int current: (Config.currentPage >= 0 && Config.currentPage < navItems.length)
        ? Config.currentPage : 0

    function editDist(a, b) {
        const m = a.length, n = b.length;
        if (m === 0) return n;
        if (n === 0) return m;
        let prev = [];
        for (let j = 0; j <= n; j++) prev[j] = j;
        for (let i = 1; i <= m; i++) {
            let cur = [i];
            for (let j = 1; j <= n; j++)
                cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
            prev = cur;
        }
        return prev[n];
    }

    // Typo-tolerant hit test. Returns rank (lower is better) or -1:
    // title substring 0, key substring 1, title fuzzy 2, key fuzzy 3.
    // Fuzzy allows 1 edit on short words, 2 on longer ones.
    function hitRank(q, title, keys) {
        const t = title.toLowerCase();
        if (t.includes(q)) return 0;
        for (const k of keys)
            if (k.toLowerCase().includes(q)) return 1;
        const words = t.split(/[^a-z0-9]+/);
        for (const w of words) {
            if (!w) continue;
            if (root.editDist(q, w) <= (w.length <= 4 ? 1 : 2)) return 2;
        }
        for (const k of keys) {
            for (const w of k.toLowerCase().split(/[^a-z0-9]+/)) {
                if (!w) continue;
                if (root.editDist(q, w) <= (w.length <= 4 ? 1 : 2)) return 3;
            }
        }
        return -1;
    }

    function matchTerm(q, title, keys) {
        const t = title.toLowerCase();
        if (t.includes(q)) return "";
        for (const k of keys)
            if (k.toLowerCase().includes(q)) return k;
        return "≈ " + q;
    }

    readonly property string query: search.text
    readonly property var visibleNav: {
        if (query.length === 0) {
            for (const n of navItems) n.match = "";
            return navItems;
        }
        const q = query.trim().toLowerCase();
        const hits = [];
        for (const n of navItems) {
            const rank = root.hitRank(q, n.title, root.keyOf[n.page] || []);
            if (rank >= 0) {
                n.match = root.matchTerm(q, n.title, root.keyOf[n.page] || []);
                n.rank = rank;
                hits.push(n);
            }
        }
        hits.sort(function (a, b) { return a.rank - b.rank; });
        return hits;
    }

    Component.onCompleted: {
        keyOf = {
            0: barIslandPage.searchKeys, 1: clockPage.searchKeys,
            2: appearancePage.searchKeys, 3: motionPage.searchKeys,
            4: notifPage.searchKeys, 5: systemPage.searchKeys,
            6: soundPage.searchKeys, 7: displayPage.searchKeys,
            8: networkPage.searchKeys, 9: btPage.searchKeys,
            10: powerPage.searchKeys
        };
    }

    function select(page) { Config.set("currentPage", page) }
    function step(delta) {
        const next = Math.max(0, Math.min(navItems.length - 1, current + delta));
        if (next !== current) select(next);
    }

    onCurrentChanged: contentFlick.contentY = 0

    onOpenChanged: {
        if (open) {
            search.text = "";
            Qt.callLater(() => search.forceInputFocus());
        }
    }

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
                        onAccepted: {
                            if (root.visibleNav.length > 0) root.select(root.visibleNav[0].page);
                        }
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
                        color: navRow.active ? Qt.alpha(Theme.accentFor("settings"), 0.18)
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
                                color: Theme.accentFor("settings")
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

                            Label {
                                visible: root.query.length > 0 && navRow.modelData.match !== ""
                                text: navRow.modelData.match
                                font.pixelSize: Theme.px(11)
                                color: Theme.accentFor("settings")
                                elide: Text.ElideRight
                                Layout.maximumWidth: 110
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

                        BarIslandPage   { id: barIslandPage; Layout.fillWidth: true; visible: root.current === 0 }
                        ClockDatePage   { id: clockPage; Layout.fillWidth: true; visible: root.current === 1 }
                        AppearancePage  { id: appearancePage; Layout.fillWidth: true; visible: root.current === 2 }
                        MotionPage      { id: motionPage; Layout.fillWidth: true; visible: root.current === 3 }
                        NotificationsPage { id: notifPage; Layout.fillWidth: true; visible: root.current === 4 }
                        SystemPage      { id: systemPage; Layout.fillWidth: true; visible: root.current === 5 }
                        SoundPage       { id: soundPage; Layout.fillWidth: true; visible: root.current === 6 }
                        DisplayPage     { id: displayPage; Layout.fillWidth: true; visible: root.current === 7 }
                        NetworkPage     { id: networkPage; Layout.fillWidth: true; visible: root.current === 8 }
                        BluetoothPage   { id: btPage; Layout.fillWidth: true; visible: root.current === 9 }
                        PowerPage       { id: powerPage; Layout.fillWidth: true; visible: root.current === 10 }
                    }
                }
            }
        }
    }
}
