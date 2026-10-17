import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

// A drill-down page. Rows are added by the page via the default property and
// scroll when they overflow the fixed drill box, with a rail on the right.
Item {
    id: page

    signal back()

    default property alias rows: col.data

    RowLayout {
        anchors {
            fill: parent
            topMargin: 12
            bottomMargin: 14
            leftMargin: 14
            rightMargin: 14
        }
        spacing: 6

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: flick.width
                spacing: 0
            }
        }

        ScrollRail {
            flickable: flick
            accent: Theme.accentFor("control-center")
        }
    }
}
