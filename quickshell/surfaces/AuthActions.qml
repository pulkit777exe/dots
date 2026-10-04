import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// AuthActions.qml -- Cancel and Authenticate.
//
// The dialog's two ways out, and nothing else. Neither signal carries a
// password and neither one knows what polkit is: pressing Authenticate emits
// `authenticatePressed` and AuthDialog.qml answers it with whatever is in the
// field. That is the whole reason these two are a file rather than a nested
// pair of Rectangles -- the authenticate button's job used to be reaching
// across the dialog for `passwordField.text`, which meant the layout could not
// be read without also reading the field.
//
// Cancel is the left button on purpose, even though it is the one nobody wants
// to press by accident: it is the wide end of the row and Authenticate is the
// narrow, accented one, so the default-looking button is the safe one.

RowLayout {
    id: root

    spacing: 8

    // Passed in rather than read from Theme, so this file has no opinion about
    // which colour a dialog is: one accent, chosen once by AuthDialog and used
    // by the header badge, the field's border and this button.
    property color accent: Theme.colors.accent

    // Neither signal carries a password and neither knows what polkit is.
    signal cancelPressed()
    signal authenticatePressed()

    // Spacer. The dialog's column is 430 wide and the two buttons are 73 and
    // 110, so this is what right-aligns them rather than a right margin that
    // would have to be kept in step with the button widths.
    Item {
        Layout.fillWidth: true
    }

    Rectangle {
        id: cancelButton

        Layout.preferredWidth: 73
        Layout.preferredHeight: 32

        radius: height / 2

        color:
            cancelMouse.containsMouse
                ? Theme.colors.surfaceAlt
                : Theme.colors.surface

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

            color: Theme.withAlpha(Theme.colors.text, 0.9)
        }

        MouseArea {
            id: cancelMouse

            anchors.fill: parent

            hoverEnabled: true

            onClicked: root.cancelPressed()
        }
    }

    Rectangle {
        id: authenticateButton

        Layout.preferredWidth: 110
        Layout.preferredHeight: 32

        radius: height / 2

        // Qt.darker, not accentVariant: no palette's accentVariant is
        // a shade of its accent -- 5 of 6 are lighter, and ariadne's
        // is 106deg off-hue -- so naming one flashed the button a
        // second colour on press. Same pressed-accent shape as
        // IconButton.qml.
        color:
            authenticateMouse.pressed
                ? Qt.darker(root.accent, 1.1)
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

            onClicked: root.authenticatePressed()
        }
    }
}
