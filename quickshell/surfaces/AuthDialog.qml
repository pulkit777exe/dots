import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

Surface {
    id: root

    // ─────────────────────────────────────────────────────────────
    // Geometry
    //
    // Measured 1:1 off 2026-09-20_22-28-58.png. The references are 1:1
    // crops of a native 1920x1080 session, so these are live pixels --
    // nothing here is a capture measurement to be scaled.
    //
    // The dialog's black fill spans x 173..602 and y 13..277; its own 1px
    // hairline sits just outside that at x 172 and x 603, and the
    // wallpaper-to-edge half-way crossings fall at x 173.05 / 603.00 and
    // y 12.0 / 280.0. So the card is 430 x 266 of fill inside a 432 x 268
    // outline, and 430 x 266 is what the code takes.
    //
    // The vertical stack sums to the same 266 exactly:
    //   14 top + 30 title row + 10 + 74 message card + 12 + 15 label
    //   + 11 + 42 field + 11 + 32 buttons + 15 bottom.
    // Every one of those is a measured edge: the card's top at y 66.3 and
    // bottom at 140.3, the field at y 178.5..220.9, the buttons at
    // y 231.6..264.6.
    // ─────────────────────────────────────────────────────────────

    // 430, measured off 2026-09-20_22-28-58. The dialog's fill is exactly
    // (0,0,0) and the dimmed wallpaper behind it is about (3,22,17), so a
    // threshold of sum<20 separates them cleanly: at the vertical centre the
    // dialog spans x 173..601, i.e. 429-430px.
    //
    // This was 392, from a scan that read the dialog as x 192..583. That is
    // the same centre, inset ~19px per side, so it was taken at a row where
    // the 26px corner radius had already cut in -- the figure it corrected
    // (430) was right and the correction made the dialog 38px too narrow.
    // The lesson matches the rest of this repo's measurement notes: take the
    // widest row, never a row near a rounded corner.
    width: 430
    implicitHeight: column.implicitHeight + 31

    cornerRadius: 26

    // Pure black, like the control-centre panel. Theme.colors.surface is
    // the ariadne teal, which made this dialog read as a bright card on a
    // dark desktop; the reference dialog is #000000.
    backgroundColor: "#000000"

    property color accent: Theme.colors.accent

    // The inset surfaces the dialog is built from. The message card and the
    // Cancel button share a fill (16,14,12) off the reference; the input
    // field is a true black inset inside it, picked out only by its hairline.
    readonly property color insetFill: "#100e0c"
    readonly property color fieldFill: "#000000"
    readonly property color badgeInset: "#211c1b"

    readonly property var pendingRequest: Auth.pending

    readonly property string dialogTitle: "Authentication required"

    readonly property string message:
        pendingRequest ? pendingRequest.message : ""

    readonly property string actionId:
        pendingRequest ? pendingRequest.actionId : ""

    readonly property string errorText:
        pendingRequest ? pendingRequest.errorText : ""

    signal authenticateRequested(string password)
    signal cancelled()

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        anchors.topMargin: 14
        anchors.bottomMargin: 15

        spacing: 0

        // ========================================================
        // TITLE
        // ========================================================

        RowLayout {
            Layout.fillWidth: true
            // 30, so the 29px badge disc fits without overflowing the row:
            // the reference's disc runs y 25.97..55.74 and the dialog's top
            // edge is at 12, i.e. 14 down -- exactly topMargin.
            Layout.preferredHeight: 30
            spacing: 13

            // A filled accent disc carrying a dark glyph, not a bare
            // accent-coloured icon. 29x30 in the reference: the teal's own
            // half-way edge falls at x 187.73 / 216.97 and y 25.97 / 55.74,
            // so 29.2 x 29.8. The dialog's left edge is 172, putting the
            // disc 15.7 in -- the same inset as the column's margin.
            Rectangle {
                Layout.preferredWidth: 29
                Layout.preferredHeight: 29
                radius: width / 2

                color: root.accent

                Icon {
                    anchors.centerIn: parent
                    icon: "lock"
                    size: 16
                    iconColor: Theme.colors.accentText
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                text: root.dialogTitle

                font.pixelSize: 18
                font.weight: Font.DemiBold

                color: "#FFFFFF"

                elide: Text.ElideRight
            }
        }

        // ========================================================
        // MESSAGE CARD
        //
        // The reference sets the message and the action id inside a
        // slightly lighter inset well rather than letting them run
        // straight down the dialog.
        // ========================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 12

            // 74 in the reference: the well runs y 66.3..140.3.
            implicitHeight: messageCol.implicitHeight + 21
            radius: 14

            color: root.insetFill

            ColumnLayout {
                id: messageCol

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 11
                anchors.bottomMargin: 10

                spacing: 0

                StyledText {
                    Layout.fillWidth: true

                    visible: root.message.length > 0

                    text: root.message

                    color: "#FFFFFF"

                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    // Qt scales the FONT's line spacing by this, and SF Pro's
                    // spacing at 15px is already ~28px. 1.0 lands the two
                    // reference lines 17px apart, which is what the capture
                    // shows (ink baselines at y 91.5 and 108.5).
                    lineHeight: 1.0

                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    visible: root.actionId.length > 0

                    text: root.actionId

                    color: "#8a8a8a"

                    font.pixelSize: 13

                    elide: Text.ElideRight
                }
            }
        }

        // ========================================================
        // PASSWORD LABEL
        // ========================================================

        StyledText {
            Layout.fillWidth: true

            visible: root.message.length > 0 || root.actionId.length > 0

            text: "Password"

            color: "#7a7a7a"

            font.pixelSize: 13
        }

        // ========================================================
        // PASSWORD FIELD
        //
        // A black pill with a faint accent hairline and a dark lock disc
        // inset at its left edge.
        // ========================================================

        Rectangle {
            id: passwordBox

            Layout.fillWidth: true
            Layout.topMargin: 11
            // 42: the reference field's teal hairline crosses half-way at
            // y 178.5 and 220.9, so 42.4.
            Layout.preferredHeight: 42

            radius: height / 2

            color: root.fieldFill

            border.width: 1
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)

            Behavior on border.color {
                ColorAnimation { duration: MotionConfig.hover() }
            }

            Rectangle {
                id: fieldBadge

                anchors.left: parent.left
                // 5, not 9: the reference disc's edge starts 5.2px in
                // (x 192.55 against the field's 187.4) and is 26 across.
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter

                width: 26
                height: 26
                radius: width / 2

                color: root.badgeInset

                Icon {
                    anchors.centerIn: parent
                    icon: "lock"
                    size: 14
                    iconColor: "#9a9a9a"
                }
            }

            TextInput {
                id: passwordField

                anchors.fill: parent
                // 38, so the caret clears the 26px disc that starts 5 in
                // and ends at 31 -- the reference keeps the same 7px gap
                // between the disc and the placeholder that this had.
                anchors.leftMargin: 38
                anchors.rightMargin: 15

                verticalAlignment: TextInput.AlignVCenter

                // Always masked, unconditionally.
                //
                // This used to be keyed off `responseHidden`, which is
                // `!pendingRequest.responseVisible` -- i.e. "is this a response flow". That
                // conflates two unrelated things: whether a response is
                // *needed* says nothing about whether the text should be
                // legible. Every real password prompt is a response flow, so
                // that condition was true exactly when it mattered and the
                // password rendered in plain text, in the one place it must
                // never be.
                //
                // responseHidden had no other use, so it is gone rather than
                // repurposed. If the field's visibility ever needs to follow
                // the flow, bind `visible` to isResponseRequired and leave the
                // echo mode alone.
                echoMode: TextInput.Password

                color: "#FFFFFF"

                font.family: "SF Pro Display"
                font.pixelSize: 16

                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnTab: true

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    visible:
                        passwordField.text.length === 0

                    // Not polkit's inputPrompt: for the auth_admin action
                    // that is literally "Password:", which just repeats the
                    // label sitting directly above the field. The reference
                    // uses a fixed prompt.
                    text: "Enter your password"

                    font.family: "SF Pro Display"
                    font.pixelSize: 16
                    color: "#8a8a8a"
                }

                onAccepted:
                    root.authenticateRequested(text)

                Component.onCompleted: {
                    if (Auth.pending)
                        forceActiveFocus()
                }

                onVisibleChanged: {
                    if (visible && Auth.pending)
                        forceActiveFocus()
                }

                Connections {
                    target: Auth

                    function onRequestBegan() {
                        passwordField.text = ""

                        Qt.callLater(function() {
                            passwordField.forceActiveFocus()
                        })
                    }
                }
            }
        }

        // ========================================================
        // ERROR
        // ========================================================

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 6

            visible: root.errorText.length > 0

            text: root.errorText

            color: Theme.colors.danger

            font.pixelSize: 12

            wrapMode: Text.WordWrap
        }

        // ========================================================
        // BUTTONS
        // ========================================================

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 11

            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            // ----------------------------------------------------
            // CANCEL
            // ----------------------------------------------------

            Rectangle {
                id: cancelButton

                // 73 x 32: the reference pill's own half-way edge runs
                // x 396.8..469.6 and y 231.6..264.6.
                Layout.preferredWidth: 73
                Layout.preferredHeight: 32

                radius: height / 2

                color:
                    cancelMouse.containsMouse
                        ? "#1c1917"
                        : root.insetFill

                Behavior on color {
                    ColorAnimation {
                        duration: MotionConfig.hover()
                    }
                }

                StyledText {
                    anchors.centerIn: parent

                    text: "Cancel"

                    font.pixelSize: 15
                    font.weight: Font.Medium

                    color: "#e6e6e6"
                }

                MouseArea {
                    id: cancelMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onClicked:
                        root.cancelled()
                }
            }

            // ----------------------------------------------------
            // AUTHENTICATE
            // ----------------------------------------------------

            Rectangle {
                id: authenticateButton

                // 110 x 32: the reference pill is a solid teal shape, so it
                // measures directly -- its own edge falls at x 477.8/588.6
                // and y 231.9/263.9.
                Layout.preferredWidth: 110
                Layout.preferredHeight: 32

                radius: height / 2

                color:
                    authenticateMouse.pressed
                        ? Theme.colors.accentAlt
                        : root.accent

                Behavior on color {
                    ColorAnimation {
                        duration: MotionConfig.hover()
                    }
                }

                StyledText {
                    anchors.centerIn: parent

                    text: "Authenticate"

                    font.pixelSize: 15
                    font.weight: Font.DemiBold

                    color: Theme.colors.accentText
                }

                MouseArea {
                    id: authenticateMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onClicked:
                        root.authenticateRequested(
                            passwordField.text
                        )
                }
            }
        }
    }
}
