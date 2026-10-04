import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// The Control Center settings page. Three sections, in order: how wide the
// grid is, the grid itself, and what you can add to it.
//
// This file is the composition and the keyboard contract, and nothing else.
// The grid arithmetic lives with the grid (ArrangerCanvas); the widgets the
// grid draws live in components/ as Preview*. What stays here is the section
// order, the focus policy -- the page holds focus, the sections ask for it --
// and the Keys handler that turns arrows, [ ] and Delete into layout edits.
ColumnLayout {
    id: root

    spacing: 10

    function takeFocus() { root.forceActiveFocus(); }

    Keys.onPressed: (e) => {
        const id = ControlCenterLayout.selectedId;
        if (!id) return;
        const step = e.key === Qt.Key_Shift ? 3 : 1;
        if (e.key === Qt.Key_Left)             { ControlCenterLayout.nudge(id, -step, 0); e.accepted = true; }
        else if (e.key === Qt.Key_Right)       { ControlCenterLayout.nudge(id,  step, 0); e.accepted = true; }
        else if (e.key === Qt.Key_Up)          { ControlCenterLayout.nudge(id, 0, -step); e.accepted = true; }
        else if (e.key === Qt.Key_Down)        { ControlCenterLayout.nudge(id, 0,  step); e.accepted = true; }
        else if (e.key === Qt.Key_BracketLeft)  { ControlCenterLayout.cycleSize(id, -1); e.accepted = true; }
        else if (e.key === Qt.Key_BracketRight) { ControlCenterLayout.cycleSize(id,  1); e.accepted = true; }
        else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
            ControlCenterLayout.remove(id); e.accepted = true;
        }
    }

    SettingsSectionLabel { label: "Layout" }

    ArrangerToolbar {
        onWantFocus: root.takeFocus()
    }

    ArrangerCanvas {
        onWantFocus: root.takeFocus()
    }

    SettingsSectionLabel {
        label: "Add a control"
        Layout.topMargin: 6
    }

    ArrangerPalette {
        onWantFocus: root.takeFocus()
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: "Drag a control to move it, pull its corner to resize, right-click for every size it supports. With one selected: arrows nudge, [ and ] step through sizes, Delete removes."
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        textColor: Theme.withAlpha(Theme.colors.text, 0.42)
    }
}
