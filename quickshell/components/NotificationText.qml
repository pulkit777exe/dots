import QtQuick
import QtQuick.Layouts
import "../services"

// A notification's text lines: sender, summary, body. The toast card
// and the control-center history list both render exactly this;
// `sender` empty (the list's case) hides the top line.

ColumnLayout {
    id: root

    property string sender: ""
    property string summary: ""
    property string body: ""

    spacing: 1

    Label {
        // the sender, small and dim above the summary
        Layout.fillWidth: true
        visible: root.sender !== "" && root.summary !== ""
        text: root.sender
        font.pixelSize: Theme.px(10)
        color: Theme.withAlpha(Theme.colors.text, 0.45)
        elide: Text.ElideRight
    }
    Label {
        Layout.fillWidth: true
        text: root.summary
        font.pixelSize: Theme.px(13)
        font.weight: Font.DemiBold
        color: Theme.colors.text
        elide: Text.ElideRight
    }
    Label {
        Layout.fillWidth: true
        visible: Config.notifShowBodyText && root.body !== ""
        text: root.body
        font.pixelSize: Theme.px(11)
        color: Theme.withAlpha(Theme.colors.text, 0.55)
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
}
