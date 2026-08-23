import QtQuick
import "../../core"

/**
 * Semantic icon for e-ink theme: shape carries meaning, not color.
 * success → check circle, warning → alert circle, danger → close circle, info → info circle.
 * Falls back to colored circle for non-e-ink themes.
 */
Rectangle {
    id: root
    property string severity: "info"  // success | warning | danger | info
    property bool isEink: Theme.einkMode

    width: Config.iconSizeNormal + 6
    height: width
    radius: width / 2
    color: {
        if (isEink) return "transparent"
        switch (severity) {
            case "success": return Theme.colors.success
            case "warning": return Theme.colors.warning
            case "danger":  return Theme.colors.danger
            default:        return Theme.colors.accent
        }
    }
    border.width: isEink ? 2 : 0
    border.color: Theme.colors.text

    Text {
        anchors.centerIn: parent
        text: Config.semanticIcon(root.severity)
        color: root.isEink ? Theme.colors.text : Theme.colors.bg
        font.family: Config.iconFontFamily
        font.pixelSize: Config.iconSizeSmall
    }
}
