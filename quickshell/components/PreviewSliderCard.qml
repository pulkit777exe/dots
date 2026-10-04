import QtQuick
import "../services"

// The arranger's stand-in for a full-width value control: a card with a
// title, a read-only filled track, and a floating value chip.
//
// Deliberately NOT the same thing as CcSliderCard, which is the live control
// in the panel itself -- that one is a Rectangle with a MouseArea, takes
// cardLabel/sliderValue and emits sliderMoved. This one is an Item that only
// draws, because in the arranger it is covered by the slot's drag MouseArea
// and clicking it must move the whole card rather than scrub a value. The two
// were briefly both called `SliderCard`, which made "the SliderCard" ambiguous
// across the repo; the distinct Preview*/Cc* prefixes end that.
Item {
    id: root

    property string title: ""
    property string iconName: ""
    property real fraction: 0
    property string chipText: ""
    property bool chipOn: true

    implicitHeight: 68

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.withAlpha(Theme.colors.text, 0.055)
    }

    StyledText {
        id: titleText
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.topMargin: 11
        text: root.title
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: Theme.colors.text
    }

    Icon {
        anchors.right: parent.right
        anchors.verticalCenter: titleText.verticalCenter
        anchors.rightMargin: 14
        icon: "chevron_right"
        size: 16
        iconColor: Theme.withAlpha(Theme.colors.text, 0.45)
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        height: 22

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.withAlpha(Theme.colors.text, 0.11)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.max(0, Math.min(1, root.fraction))
            height: 6
            radius: 3
            color: Theme.colors.accent
        }
        Icon {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: root.iconName
            size: 15
            iconColor: Theme.colors.accent
        }

        Rectangle {
            visible: root.chipText.length > 0
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width,
                                     parent.width * root.fraction - width / 2))
            width: chipLabel.implicitWidth + 26
            height: 22
            radius: 11
            color: root.chipOn ? Theme.colors.accent : Theme.withAlpha(Theme.colors.text, 0.12)
            StyledText {
                id: chipLabel
                anchors.centerIn: parent
                text: root.chipText
                font.pixelSize: 11
                font.weight: Font.Medium
                color: root.chipOn ? Theme.colors.accentText : Theme.colors.text
            }
        }
    }
}
