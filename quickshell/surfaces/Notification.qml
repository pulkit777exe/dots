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

    property color iconBackground: Theme.colors.surface
    property color iconColor: Theme.colors.accent

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
    // ─────────────────────────────────────────────────────────────

    width: 380

    implicitHeight:
        content.implicitHeight + 24

    cornerRadius: 16

    backgroundColor:
        Theme.withAlpha(
            Theme.colors.background,
            0.97
        )

    borderWidth: 1
    borderColor: Theme.colors.border

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

    // ─────────────────────────────────────────────────────────────
    // Content
    // ─────────────────────────────────────────────────────────────

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12

        spacing: 10

        // ─────────────────────────────────────────────────────────
        // Header
        // ─────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Icon
            Item {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                Rectangle {
                    anchors.fill: parent

                    radius: 11

                    color:
                        root.iconBackground
                }

                Icon {
                    anchors.centerIn: parent

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

                    size: 19

                    iconColor:
                        root.iconColor
                }
            }

            // Text
            ColumnLayout {
                Layout.fillWidth: true

                spacing: 1

                StyledText {
                    Layout.fillWidth: true

                    text:
                        root.entry.appName ||
                        "Notification"

                    textColor:
                        Theme.colors.textMuted

                    font.pixelSize: 11
                    font.weight: Font.Medium

                    elide:
                        Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true

                    text:
                        root.entry.title ||
                        root.entry.summary ||
                        ""

                    textColor:
                        Theme.colors.text

                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    maximumLineCount: 2

                    wrapMode:
                        Text.Wrap

                    elide:
                        Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true

                    visible:
                        Boolean(root.entry.subtitle)

                    text:
                        root.entry.subtitle || ""

                    textColor:
                        Theme.colors.textMuted

                    font.pixelSize: 11

                    maximumLineCount: 1

                    elide:
                        Text.ElideRight
                }
            }

            // Close
            IconButton {
                Layout.alignment:
                    Qt.AlignTop

                icon: "close"

                size: 28
                iconSize: 15

                iconColor:
                    Theme.colors.textMuted

                onClicked:
                    root.dismissed()
            }
        }

        // ─────────────────────────────────────────────────────────
        // Image
        // ─────────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150

            visible:
                Boolean(root.entry.image)

            radius: 12

            color:
                Theme.colors.surfaceAlt

            clip: true

            Image {
                anchors.fill: parent

                source:
                    root.entry.image || ""

                fillMode:
                    Image.PreserveAspectCrop

                asynchronous: true
                cache: true
                smooth: true
            }
        }

        // ─────────────────────────────────────────────────────────
        // Body
        // ─────────────────────────────────────────────────────────

        StyledText {
            Layout.fillWidth: true

            visible:
                Boolean(root.entry.body)

            text:
                root.entry.body || ""

            textColor:
                Theme.withAlpha(
                    Theme.colors.text,
                    0.76
                )

            font.pixelSize: 12

            wrapMode:
                Text.Wrap

            maximumLineCount: 5

            elide:
                Text.ElideRight
        }

        // ─────────────────────────────────────────────────────────
        // Actions
        // ─────────────────────────────────────────────────────────

        Flow {
            Layout.fillWidth: true

            spacing: 6

            visible:
                Array.isArray(root.entry.actions) &&
                root.entry.actions.length > 0

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