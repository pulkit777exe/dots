import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// ControlCenterPage
// Hosts the arranger. The page's own header is the shared SettingsHeader; the
// page used to also carry standalone toggles for keep-awake and night-light
// warmth, but those are now two of the arranger's controls, so editing them
// happens on the canvas.
ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "tune"
        title: "Control Center"
        subtitle: "Arrange, resize, add and remove the controls."
    }

    ControlCenterArranger {
        id: arranger
        Layout.fillWidth: true
        // Zero the demand for width so fillWidth hands the arranger whatever
        // the content column has, instead of the two children splitting it.
        // The arranger asks for 728px implicitly (see the note on its own
        // root), which left the header card -- the other fillWidth child --
        // with 72px, truncating "Control Center" to "Con...".
        Layout.preferredWidth: 0
    }
}
