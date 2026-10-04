import QtQuick
import QtQuick.Layouts

import Quickshell.Services.Notifications

import "../components"
import "../services"

// Notification.qml -- one toast.
//
// What is in this file is the toast: its size and frame, the three ways it can
// be handed a notification, and the four pieces of chrome that belong to no
// one part of it. Three pieces each have a file of their own, because each is
// a separate thing to change:
//
//   NotificationBadge.qml    the circle: the notification's icon, or the first
//                            letter of its app name
//   NotificationText.qml     the three lines: sender, headline, body
//   NotificationActions.qml  the sender's action buttons
//
// What did NOT move is the interpretation of an entry. `entry` below is a
// property in this file rather than a fourth component because it is a question
// about where the toast was given its data -- as a Quickshell Notification, as
// a Notifications.popups row, or as loose properties -- and answering it needs
// the properties themselves. Moving it would have meant passing eleven values
// through to learn what the eleventh was for.
//
// The toast list itself is services/Notifications.qml, and it is the seam into
// NotificationState.qml (the list), NotificationWatchers.qml (what turns an
// event elsewhere into a toast) and NotificationHistory.qml (notifs.json).
// This file reads `Notifications.popups` through NotificationStack.qml and
// holds no notification state of its own.

Surface {
    id: root

    // The three sources, in the order they are consulted. `notification` takes
    // a Quickshell Notification object and `modelData` a plain row from
    // Notifications.popups; both are accepted so this file can be dropped
    // into either a NotificationServer delegate or a Repeater.
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

    property color iconBackground: Theme.colors.surfaceAlt
    property color iconColor: Theme.colors.accent

    // Deliberately NOT derived from `entry`, unlike every other read of an
    // entry's fields below: this asks whether a glyph was *supplied*, which
    // only the loose properties can say. With a notification or a modelData,
    // a toast with no supplied glyph falls back to the app's initial.
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

    // The two fallback chains, once, here. `title` before `summary` and
    // `subtitle` before `body` are both about the entry rather than about how
    // text is drawn, and NotificationStack.qml fills `title` with the summary
    // and leaves `subtitle` empty -- so both rungs are live today.
    readonly property string headline:
        root.entry.title || root.entry.summary || ""

    readonly property string bodyText:
        root.entry.subtitle || root.entry.body || ""

    // Which icon the badge shows, resolved to one name. Anything the sender
    // named wins; then its app icon; and a toast with neither is not a bare
    // grey disc -- a critical one says so, and the rest say "a notification".
    readonly property string glyph: {
        if (root.entry.icon)
            return root.entry.icon

        if (root.entry.appIcon)
            return root.entry.appIcon

        return root.entry.urgency === NotificationUrgency.Critical
            ? "warning"
            : "notifications"
    }

    signal clicked
    signal dismissed
    signal actionInvoked(string actionId)

    // 449 is ConfigStore.notifWidth's default, and in the one place this is
    // used -- NotificationStack's Repeater, with Layout.fillWidth -- the
    // layout overwrites it anyway. Left as a literal on purpose: making it
    // read the setting is a behaviour change, not a split.
    width: 449

    implicitHeight: content.implicitHeight + 24

    cornerRadius: 27

    backgroundColor: Theme.colors.background

    borderWidth: 0

    shadow: true

    opacity: 0
    scale: 0.97

    // Fade and lift together, from nothing: a toast that appears fully opaque
    // at 0.97 reads as a stuck panel rather than an arrival.
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

    // Over the whole toast rather than on the close button, so clicking
    // anywhere that is not a button runs the notification's default action --
    // which is what NotificationStack.qml does with `clicked`.
    TapHandler {
        onTapped: root.clicked()
    }

    HoverHandler { id: hover }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 0
        anchors.leftMargin: 11
        anchors.rightMargin: 11
        anchors.topMargin: 11
        anchors.bottomMargin: 13

        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            NotificationBadge {
                hasGlyph: root.hasGlyph
                glyph: root.glyph
                initial: root.initial

                badgeColor: root.iconBackground
                glyphColor: root.iconColor
            }

            NotificationText {
                appName: root.entry.appName
                headline: root.headline
                body: root.bodyText
            }

            // Hidden until the pointer is over the toast, and then only the
            // button -- a permanently visible close on every toast is a row of
            // crosses down the side of the screen.
            IconButton {
                Layout.alignment: Qt.AlignVCenter

                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: MotionConfig.fade()
                    }
                }

                icon: "close"

                size: 26
                iconSize: 15

                iconColor: Theme.withAlpha(Theme.colors.text, 0.55)

                onClicked: root.dismissed()
            }
        }

        // A sender may attach an image; most do not. The band is 0 when there
        // is none rather than merely invisible -- an invisible item in a layout
        // is skipped, but so is its top margin, and 11 is what separates an
        // image from the header above it.
        Rectangle {
            Layout.fillWidth: true

            Layout.preferredHeight: visible ? 160 : 0
            Layout.topMargin: visible ? 11 : 0

            visible: Boolean(root.entry.image)

            radius: 13

            color: Theme.colors.surface

            clip: true

            Image {
                anchors.fill: parent

                source: root.entry.image || ""

                // Cropped rather than fitted: an image that is not the shape of
                // 160px would otherwise letterbox inside a band sized for it,
                // and the band does not resize to suit the image.
                fillMode: Image.PreserveAspectCrop

                // A remote image must not hold the shell's frame budget while
                // it loads, and the same URL is very likely to arrive again.
                asynchronous: true
                cache: true
                smooth: true
            }
        }

        // `hasActions` rather than `visible`: the top margin is a layout
        // decision made by this file, and the visibility belongs to the row
        // that knows whether it has anything to show.
        NotificationActions {
            id: actionBar

            Layout.fillWidth: true
            Layout.topMargin: actionBar.hasActions ? 9 : 0

            actionList: root.entry.actions

            onInvoked: (actionId) => root.actionInvoked(actionId)
        }
    }
}
