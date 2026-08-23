import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"
import "."

/** One row in Control Center's persistent notification list (Image 2). Same
 *  underlying entry shape as NotificationToast -- one data model, two views.
 *  Uses SemanticIcon (severity-by-shape on e-ink, severity-by-color
 *  elsewhere) rather than a plain initial-letter circle -- this was built
 *  in ui/SemanticIcon.qml but never actually wired into anything until now. */
Rectangle {
    id: root
    property var entry: null
    implicitHeight: col.implicitHeight + 16
    radius: 12
    color: Theme.colors.surfaceHover

    // D-Bus notification urgency (0=low, 1=normal, 2=critical) mapped to our
    // severity vocabulary. Falls back to "info" if the field isn't present
    // -- confirm `urgency` is the actual property name your Quickshell
    // version's NotificationServer exposes; this is the least-verified part
    // of this component.
    readonly property string severity: {
        if (!root.entry || root.entry.urgency === undefined) return "info"
        if (root.entry.urgency >= 2) return "danger"
        if (root.entry.urgency === 0) return "info"
        return "info"
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            SemanticIcon {
                severity: root.severity
            }
            Text { text: root.entry ? root.entry.appName : ""; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 4; font.family: Theme.fontFamily; Layout.fillWidth: true }
            Text {
                text: "\u2715"
                color: Theme.colors.textMuted
                font.pixelSize: Theme.fontSize - 3
                font.family: Theme.fontFamily
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: NotificationService.clearOne(root.entry.id) }
            }
        }
        Text { text: root.entry ? root.entry.summary : ""; color: Theme.colors.text; font.pixelSize: Theme.fontSize - 2; font.family: Theme.fontFamily; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { text: root.entry ? root.entry.body : ""; color: Theme.colors.textMuted; font.pixelSize: Theme.fontSize - 3; font.family: Theme.fontFamily; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
    }
}
