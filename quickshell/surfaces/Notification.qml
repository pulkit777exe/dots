import QtQuick
import QtQuick.Layouts

import Quickshell.Services.Notifications

import "../components"
import "../services"

Surface {
    id: root

    // ─────────────────────────────────────────────────────────────
    // Compatibility inputs
    // ─────────────────────────────────────────────────────────────

    property var notification: null
    property var modelData: null

    property string appName: ""
    property string appIcon: ""
    property string icon: ""
    property string title: ""
    property string summary: ""
    property string subtitle: ""
    property string body: ""

    property var urgency: NotificationUrgency.Normal
    property var actions: []
    property string image: ""

    property color iconBackground: "#211c1b"
    property color iconColor: Theme.colors.accent

    // The reference toast draws the app's own icon when there is one and
    // otherwise falls back to the first letter of the app name rather than
    // a generic bell. notify-send, which ships no icon, renders as a bare
    // accent-coloured "N" on a dark disc.
    readonly property bool hasGlyph: (root.icon !== "" || root.appIcon !== "")
    readonly property string initial: {
        const n = String(root.entry.appName || "").trim();
        return n.length > 0 ? n.charAt(0).toUpperCase() : "";
    }

    readonly property var entry: {
        if (root.notification !== null)
            return root.notification

        if (root.modelData !== null)
            return root.modelData

        return {
            appName: root.appName,
            appIcon: root.appIcon,
            icon: root.icon,
            title: root.title,
            summary: root.summary,
            subtitle: root.subtitle,
            body: root.body,
            urgency: root.urgency,
            actions: root.actions,
            image: root.image
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Signals
    // ─────────────────────────────────────────────────────────────

    signal clicked
    signal dismissed
    signal actionInvoked(string actionId)

    // ─────────────────────────────────────────────────────────────
    // Geometry
    //
    // Measured 1:1 off 2026-09-20_22-28-28.png. The card's outer edges sit
    // at x 258.98 / 708.17 and y 16.6 / 84.3 (half-way between the
    // wallpaper and the black fill), so 449 x 67.7 -- 449 x 68.
    //
    // The radius is 27, fitted against the card's own left-edge profile:
    // with the top edge at y 18 and the flat side at x 260, a circle of
    // r = 26.5 through the measured edge points has an rms residual of
    // 0.11px over 26 rows, and the flat side starts 27px in.
    //
    // The three text lines sit 16px and 15px apart, measured from their ink
    // centres at y 35, 51 and 66 against a card top of 18 -- i.e. 17, 33
    // and 48 from the top. That is tighter than SF Pro's own leading, so the
    // stack is positioned rather than laid out.
    // ─────────────────────────────────────────────────────────────

    width: 449

    // 11 above the first line, 13 below the last. The asymmetry is the
    // reference's, not a rounding artefact: with the text stack's boxes at
    // y 0/14/30 in a 44-tall column, those margins put the glyph centres at
    // 17/33/48 from the top and land the card on 68.
    implicitHeight:
        content.implicitHeight + 24

    cornerRadius: 27

    // Solid near-black, matching the control-centre panel rather than the
    // theme's teal background — the reference toast is pure #000000.
    backgroundColor: "#000000"

    // No hairline: the reference edge dissolves straight into the
    // backdrop, with only the drop shadow separating the two.
    borderWidth: 0

    shadow: true

    opacity: 0
    scale: 0.97

    // ─────────────────────────────────────────────────────────────
    // Entrance animation
    // ─────────────────────────────────────────────────────────────

    Component.onCompleted: {
        if (MotionConfig.reduceMotion) {
            root.opacity = 1
            root.scale = 1
        } else {
            appearAnimation.start()
        }
    }

    ParallelAnimation {
        id: appearAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: MotionConfig.fade()
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: MotionConfig.fade()
            easing.type: Easing.OutCubic
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Click
    // ─────────────────────────────────────────────────────────────

    TapHandler {
        onTapped: root.clicked()
    }

    HoverHandler { id: hover }

    // ─────────────────────────────────────────────────────────────
    // Content
    // ─────────────────────────────────────────────────────────────

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 0
        anchors.leftMargin: 11
        anchors.rightMargin: 11
        anchors.topMargin: 11
        anchors.bottomMargin: 13

        spacing: 0

        // ─────────────────────────────────────────────────────────
        // Header: badge + three-line text stack
        // ─────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // ─────────────────────────────────────────────────────
            // Badge — a 37px disc, on the card's own midline
            //
            // 37 is the reference: the disc's own edge, half-way between
            // the #211c1b fill and the card's black, falls at x 269.93 and
            // 307.64 and y 33.0 and 69.86, so 37.7 x 36.9. Cross-checked
            // against the live render, where a 35px disc measures 34.8 --
            // the same half-way rule, so the reference really is ~37.
            // ─────────────────────────────────────────────────────

            Rectangle {
                Layout.preferredWidth: 37
                Layout.preferredHeight: 37
                Layout.alignment: Qt.AlignVCenter

                radius: width / 2

                color: root.iconBackground

                Icon {
                    anchors.centerIn: parent

                    visible: root.hasGlyph

                    icon:
                        root.entry.icon
                            ? root.entry.icon
                            : (
                                root.entry.appIcon
                                    ? root.entry.appIcon
                                    : (
                                        root.entry.urgency ===
                                        NotificationUrgency.Critical
                                            ? "warning"
                                            : "notifications"
                                    )
                            )

                    size: 18

                    iconColor: root.iconColor
                }

                // App-icon fallback: the app name's initial.
                StyledText {
                    anchors.centerIn: parent

                    visible: !root.hasGlyph && root.initial !== ""

                    text: root.initial

                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold

                    color: root.iconColor
                }
            }

            // ─────────────────────────────────────────────────────
            // Text.
            //
            // Positioned rather than laid out: the reference stacks these
            // three lines 16px and 15px apart, which is tighter than SF
            // Pro's own line height, and a ColumnLayout would hand the card
            // its fonts' natural leading instead. The boxes are 12/16/14
            // tall at y 0/14/30, so their centres fall 6/22/37 down the
            // stack -- which, with the card's 11px top margin, is 17/33/48
            // from the card's top edge, matching the reference's ink
            // centres exactly.
            // ─────────────────────────────────────────────────────

            Item {
                id: textCol

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                readonly property bool hasBody:
                    Boolean(root.entry.subtitle || root.entry.body)

                implicitHeight: hasBody ? 44 : 30
                height: implicitHeight

                StyledText {
                    width: parent.width
                    height: 12
                    verticalAlignment: Text.AlignVCenter

                    text:
                        root.entry.appName ||
                        "Notification"

                    textColor: "#8a8a8a"

                    font.pixelSize: 12
                    font.weight: Font.Medium

                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    height: 16
                    y: 14
                    verticalAlignment: Text.AlignVCenter

                    text:
                        root.entry.title ||
                        root.entry.summary ||
                        ""

                    textColor: "#FFFFFF"

                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    height: 14
                    y: 30
                    verticalAlignment: Text.AlignVCenter

                    visible: parent.hasBody

                    text:
                        root.entry.subtitle ||
                        root.entry.body ||
                        ""

                    textColor: "#8a8a8a"

                    font.pixelSize: 11

                    elide: Text.ElideRight
                }
            }

            // ─────────────────────────────────────────────────────
            // Close
            //
            // The reference toast carries no visible close affordance,
            // so it only appears once the pointer is over the card. It
            // stays in the layout either way, so revealing it does not
            // reflow the text.
            // ─────────────────────────────────────────────────────

            IconButton {
                Layout.alignment: Qt.AlignVCenter

                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: MotionConfig.fade() }
                }

                icon: "close"

                size: 26
                iconSize: 15

                iconColor: "#8a8a8a"

                onClicked: root.dismissed()
            }
        }

        // ─────────────────────────────────────────────────────────
        // Image
        // ─────────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 160 : 0
            Layout.topMargin: visible ? 11 : 0

            visible: Boolean(root.entry.image)

            radius: 13

            color: "#181614"

            clip: true

            Image {
                anchors.fill: parent

                source: root.entry.image || ""

                fillMode: Image.PreserveAspectCrop

                asynchronous: true
                cache: true
                smooth: true
            }
        }

        // ─────────────────────────────────────────────────────────
        // Actions
        // ─────────────────────────────────────────────────────────

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: visible ? 9 : 0

            visible:
                Array.isArray(root.entry.actions) &&
                root.entry.actions.length > 0

            spacing: 6

            Repeater {
                model:
                    Array.isArray(root.entry.actions)
                        ? root.entry.actions
                        : []

                delegate: StyledButton {
                    required property var modelData

                    text:
                        modelData.label || ""

                    variant:
                        "ghost"

                    onClicked:
                        root.actionInvoked(
                            modelData.id || ""
                        )
                }
            }
        }
    }
}
