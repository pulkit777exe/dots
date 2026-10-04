import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// AuthPasswordField.qml -- the password box and the "Password" label above it.
//
// One concern: getting a character into the polkit request. That covers the
// rounded box, the lock badge, the placeholder, and the two ways the caret has
// to be asked for, which is why this is a file rather than forty lines in
// AuthDialog.qml:
//
//   * `focusInput()`, called by AuthDialog when Auth raises a request. The
//     overlay window takes keyboard focus in the same change that shows this
//     dialog (shell.qml sets focusable/keyboardFocus from Auth.pending), and
//     a forceActiveFocus() issued before the window has it is discarded, so
//     AuthDialog asks again on the next event-loop turn.
//   * `active`, which is Auth.pending !== null as the dialog sees it. The
//     field asks for the caret itself on completion and whenever it becomes
//     visible while active, which covers the request that was already pending
//     when the shell loaded.
//
// There is no polkit in this file. `Auth.requestBegan` is handled one level up
// because it is the dialog's business -- it also clears the field, and only the
// dialog knows whether anything else has to be reset with it.

ColumnLayout {
    id: root

    spacing: 0

    // What the dialog types. An alias onto the input rather than a property
    // with a write-back handler, so there is exactly one copy of the string:
    // AuthDialog reads it to answer the Authenticate button and writes "" when
    // a new request arrives, which is the only thing that empties the field.
    property alias text: input.text

    // Whether a request is waiting for an answer. Not read from Auth here --
    // see the header.
    property bool active: false

    // Whether the dialog has anything else to show above this field, which is
    // what decides whether the label earns its height. See `label` below.
    property bool labelVisible: true

    // Enter, in the box. The dialog turns this into the same thing the
    // Authenticate button does; the field does not know what an Authenticate
    // is.
    signal submitted()

    function focusInput() {
        input.forceActiveFocus()
    }

    Component.onCompleted: {
        if (root.active)
            root.focusInput()
    }

    onVisibleChanged: {
        if (visible && root.active)
            root.focusInput()
    }

    // Hidden when the dialog has no message and no action id to show: the
    // field is then the only thing on screen and an unlabelled box explains
    // itself. Visible items are the only ones a layout gives space to, so this
    // takes the label's height with it rather than leaving a gap.
    StyledText {
        id: label

        Layout.fillWidth: true

        visible: root.labelVisible

        text: "Password"

        color: Theme.withAlpha(Theme.colors.text, 0.48)

        font.pixelSize: 13
    }

    Rectangle {
        id: box

        Layout.fillWidth: true
        Layout.topMargin: 11

        Layout.preferredHeight: 42

        radius: height / 2

        color: Theme.colors.surface

        border.width: 1

        // Tinted with the accent rather than a fixed value: this is the only
        // element in the dialog that says "type here", and it should follow
        // the palette like everything else.
        border.color: Theme.withAlpha(Theme.colors.accent, 0.25)

        Behavior on border.color {
            ColorAnimation {
                duration: MotionConfig.hover()
            }
        }

        // A lock inset into the left of the box, sitting under the text: the
        // 38 in the TextInput's left margin is this badge's 26 plus 5 of inset
        // plus 7 of gap. Changing one without the other overlaps them.
        Rectangle {
            id: fieldBadge

            anchors.left: parent.left

            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter

            width: 26
            height: 26
            radius: width / 2

            color: Theme.colors.surfaceAlt

            Icon {
                anchors.centerIn: parent

                icon: "lock"
                size: 14

                iconColor:
                    Theme.withAlpha(Theme.colors.text, 0.6)
            }
        }

        TextInput {
            id: input

            anchors.fill: parent

            anchors.leftMargin: 38
            anchors.rightMargin: 15

            verticalAlignment: TextInput.AlignVCenter

            // Never echoed, and never logged: this string is the user's
            // password and the dialog is the only place it exists.
            echoMode: TextInput.Password

            color: Theme.colors.text

            font.family: "SF Pro Display"
            font.pixelSize: 16

            clip: true
            selectByMouse: true
            focus: true
            activeFocusOnTab: true

            onAccepted: root.submitted()

            // The placeholder is a child of the input rather than a sibling
            // so it tracks the caret horizontally: at any non-empty text this
            // is invisible, and it costs nothing while hidden.
            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                visible: input.text.length === 0

                text: "Enter your password"

                font.family: "SF Pro Display"
                font.pixelSize: 16

                color:
                    Theme.withAlpha(Theme.colors.text, 0.55)
            }
        }
    }
}
