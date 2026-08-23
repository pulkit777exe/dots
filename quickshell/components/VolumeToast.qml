import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

/** Image 3: transient pill for volume/brightness. IslandState decides when
 *  this is shown and for how long -- this component is purely presentational.
 *  isBrightness switches BOTH the icon AND the data source -- previously
 *  only the icon branched, so a brightness toast showed your volume level. */
Rectangle {
    id: root
    property bool isBrightness: false

    readonly property int displayValue: isBrightness ? BrightnessService.brightness : AudioService.volume
    readonly property string displayIcon: isBrightness
        ? Config.iconBright
        : (AudioService.muted ? Config.iconVolMute : Config.iconVolHigh)

    implicitWidth: row.implicitWidth + 32
    implicitHeight: Theme.barHeight
    radius: height / 2
    color: Theme.colors.surface
    border.width: 1
    border.color: Qt.lighter(Theme.colors.surface, 1.3)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Text {
            text: root.displayIcon
            color: Theme.colors.accent
            font.pixelSize: Theme.fontSize
            font.family: Config.iconFontFamily
        }
        Rectangle {
            width: 160
            height: 6
            radius: 3
            color: Theme.colors.surfaceHover
            Rectangle {
                width: parent.width * (root.displayValue / 100)
                height: parent.height
                radius: parent.radius
                color: Theme.colors.accent
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
        Text {
            text: root.displayValue + "%"
            color: Theme.colors.textMuted
            font.pixelSize: Theme.fontSize - 2
            font.family: Theme.fontFamily
        }
    }
}
