import QtQuick

Item {
    id: root

    property string text: ""
    property string variant: "clock"
    property real pixelSize: 0
    property int flipDuration: 280
    property int spacing: 0

    
    StyledText {
        id: digitMeasure

        visible: false
        text: "8"
        variant: root.variant

        font.pixelSize: root.pixelSize > 0
            ? root.pixelSize
            : variantPixelSize
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: root.spacing

        Repeater {
            model: root.text.length

            delegate: Item {
                id: charItem

                required property int index

                readonly property string value: root.text[index] || ""
                readonly property bool isSeparator:
                    value === ":" ||
                    value === "." ||
                    value === " "

                property string displayed: value
                property bool initialized: false

                width: isSeparator
                    ? separator.implicitWidth
                    : digitMeasure.implicitWidth

                height: Math.max(
                    separator.implicitHeight,
                    digitMeasure.implicitHeight
                )

                clip: true

                StyledText {
                    id: separator

                    visible: charItem.isSeparator

                    anchors.fill: parent

                    text: charItem.value
                    variant: root.variant

                    font.pixelSize: root.pixelSize > 0
                        ? root.pixelSize
                        : variantPixelSize

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                StyledText {
                    id: digit

                    visible: !charItem.isSeparator

                    anchors.fill: parent

                    text: charItem.displayed
                    variant: root.variant

                    font.pixelSize: root.pixelSize > 0
                        ? root.pixelSize
                        : variantPixelSize

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    
                    renderType: Text.QtRendering

                    transform: Rotation {
                        id: rotation

                        axis.x: 1
                        axis.y: 0
                        axis.z: 0

                        origin.x: digit.width / 2
                        origin.y: digit.height

                        angle: 0
                    }
                }

                Component.onCompleted: {
                    displayed = value
                    initialized = true
                }

                onValueChanged: {
                    if (!initialized)
                        return

                    if (isSeparator || displayed === value)
                        return

                    flip.restart()
                }

                SequentialAnimation {
                    id: flip

                    NumberAnimation {
                        target: rotation
                        property: "angle"

                        from: 0
                        to: -90

                        duration: root.flipDuration / 2
                        easing.type: Easing.InCubic
                    }

                    ScriptAction {
                        script: {
                            charItem.displayed = charItem.value
                            rotation.angle = 90
                        }
                    }

                    NumberAnimation {
                        target: rotation
                        property: "angle"

                        from: 90
                        to: 0

                        duration: root.flipDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}