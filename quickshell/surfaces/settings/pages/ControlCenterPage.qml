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
    }
}
