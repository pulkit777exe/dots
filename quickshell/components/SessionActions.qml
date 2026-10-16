import QtQuick
import QtQuick.Layouts
import "../services"

// Lock / Suspend action row, plus the power menu when asked.
RowLayout {
    id: root

    property bool powerMenu: false

    spacing: 8
    Layout.fillWidth: true

    StyledButton {
        Layout.fillWidth: true
        label: "Lock"
        accent: Theme.accentFor("settings")
        onClicked: Power.lock()
    }

    StyledButton {
        Layout.fillWidth: true
        label: "Suspend"
        accent: Theme.accentFor("settings")
        onClicked: Power.suspend()
    }

    StyledButton {
        visible: root.powerMenu
        Layout.fillWidth: true
        label: "Power menu"
        accent: Theme.accentFor("settings")
        filled: true
        onClicked: UiState.togglePowerMenu()
    }
}
