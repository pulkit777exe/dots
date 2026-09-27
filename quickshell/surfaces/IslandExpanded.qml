import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

Item {
    id: root

    property string currentTime: ""
    property var weekModel: []

    signal interaction()

    anchors.fill: parent

    anchors.leftMargin: 14
    anchors.rightMargin: 14
    anchors.topMargin: 10
    anchors.bottomMargin: 10

    // Sunday is the only non-theme semantic color here.
    readonly property color sundayColor:
        Qt.rgba(1, 0.30, 0.30, 0.90)

    opacity: 1

    // ============================================================
    // MAIN LAYOUT
    // ============================================================

    RowLayout {
        anchors.fill: parent

        spacing: 14

        // ========================================================
        // MEDIA
        // ========================================================

        RowLayout {
            Layout.fillHeight: true
            spacing: 12

            // ----------------------------------------------------
            // ALBUM ART
            // ----------------------------------------------------

            Item {
                Layout.preferredWidth: 82
                Layout.preferredHeight: 82

                visible:
                    Media.artUrl.length > 0

                Rectangle {
                    anchors.fill: parent

                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.08)

                    clip: true

                    Image {
                        anchors.fill: parent

                        source: Media.artUrl

                        fillMode:
                            Image.PreserveAspectCrop

                        smooth: true
                        asynchronous: true
                        cache: true

                        sourceSize.width: 164
                        sourceSize.height: 164
                    }

                    Rectangle {
                        anchors.fill: parent

                        radius: 12

                        color: "transparent"

                        border.width: 1
                        border.color:
                            Qt.rgba(1, 1, 1, 0.08)
                    }
                }
            }

            // ----------------------------------------------------
            // EMPTY ART
            // ----------------------------------------------------

            Rectangle {
                Layout.preferredWidth: 82
                Layout.preferredHeight: 82

                radius: 12

                visible:
                    Media.artUrl.length === 0

                color:
                    Qt.rgba(1, 1, 1, 0.08)

                Icon {
                    anchors.centerIn: parent

                    icon: "music_note"
                    size: 26

                    iconColor:
                        Qt.rgba(1, 1, 1, 0.35)
                }
            }

            // ----------------------------------------------------
            // TRACK INFO
            // ----------------------------------------------------

            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 185

                spacing: 0

                StyledText {
                    Layout.fillWidth: true

                    variant: "mediaTitle"

                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    text:
                        Media.title || "Nothing playing"

                    elide:
                        Text.ElideRight

                    color:
                        Qt.rgba(1, 1, 1, 0.95)
                }

                StyledText {
                    Layout.fillWidth: true

                    variant: "mediaArtist"

                    font.pixelSize: 11

                    text:
                        Media.artist || ""

                    elide:
                        Text.ElideRight

                    visible:
                        text.length > 0

                    color:
                        Qt.rgba(1, 1, 1, 0.45)

                    topPadding: 2
                }

                Item {
                    Layout.fillHeight: true
                }

                // ------------------------------------------------
                // TRANSPORT
                // ------------------------------------------------

                RowLayout {
                    spacing: 2

                    IconButton {
                        icon: "skip_previous"

                        size: 28
                        iconSize: 15

                        enabled:
                            Media.canGoPrevious

                        onClicked: {
                            Media.previous()
                            root.interaction()
                        }
                    }

                    IconButton {
                        icon:
                            Media.playing
                                ? "pause"
                                : "play_arrow"

                        size: 30
                        iconSize: 16

                        enabled:
                            Media.canTogglePlaying

                        onClicked: {
                            Media.togglePlay()
                            root.interaction()
                        }
                    }

                    IconButton {
                        icon: "skip_next"

                        size: 28
                        iconSize: 15

                        enabled:
                            Media.canGoNext

                        onClicked: {
                            Media.next()
                            root.interaction()
                        }
                    }
                }
            }
        }

        // ========================================================
        // SPACER
        // ========================================================

        Item {
            Layout.fillWidth: true
        }

        // ========================================================
        // CLOCK + WEEK
        // ========================================================

        ColumnLayout {
            id: clockSection

            Layout.alignment:
                Qt.AlignVCenter | Qt.AlignRight

            Layout.preferredWidth: 160

            spacing: 5

            FlipText {
                Layout.alignment:
                    Qt.AlignRight

                variant: "clock"
                pixelSize: 24

                text:
                    root.currentTime
            }

            RowLayout {
                id: weekStrip

                Layout.alignment:
                    Qt.AlignRight

                spacing: 6

                Repeater {
                    model: root.weekModel

                    delegate: ColumnLayout {
                        id: day

                        required property var modelData

                        spacing: 2

                        Layout.alignment:
                            Qt.AlignVCenter |
                            Qt.AlignHCenter

                        // ----------------------------------------
                        // DAY LETTER
                        // ----------------------------------------

                        StyledText {
                            Layout.alignment:
                                Qt.AlignHCenter

                            variant: "dayLetter"

                            font.pixelSize:
                                day.modelData.isToday
                                    ? 9
                                    : 8

                            font.weight:
                                day.modelData.isToday
                                    ? Font.DemiBold
                                    : Font.Medium

                            text:
                                day.modelData.letter

                            color: {
                                if (day.modelData.isToday &&
                                    day.modelData.isSunday) {
                                    return root.sundayColor
                                }

                                if (day.modelData.isToday) {
                                    return Theme.colors.accent
                                }

                                if (day.modelData.isSunday) {
                                    return root.sundayColor
                                }

                                return Qt.rgba(
                                    1, 1, 1, 0.40
                                )
                            }
                        }

                        // ----------------------------------------
                        // DATE
                        // ----------------------------------------

                        Item {
                            Layout.alignment:
                                Qt.AlignHCenter

                            Layout.preferredWidth:
                                day.modelData.isToday
                                    ? 24
                                    : 20

                            Layout.preferredHeight:
                                day.modelData.isToday
                                    ? 24
                                    : 20

                            Behavior on Layout.preferredWidth {
                                enabled:
                                    !MotionConfig.reduceMotion

                                NumberAnimation {
                                    duration: MotionConfig.movement(0.35)
                                    easing.type:
                                        Easing.OutCubic
                                }
                            }

                            Behavior on Layout.preferredHeight {
                                enabled:
                                    !MotionConfig.reduceMotion

                                NumberAnimation {
                                    duration: MotionConfig.movement(0.35)
                                    easing.type:
                                        Easing.OutCubic
                                }
                            }

                            // ------------------------------------
                            // TODAY ACCENT CIRCLE
                            // ------------------------------------

                            Rectangle {
                                anchors.fill: parent

                                radius:
                                    width / 2

                                color:
                                    day.modelData.isToday
                                        ? Theme.colors.accent
                                        : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration:
                                            MotionConfig.fade()
                                    }
                                }
                            }

                            // ------------------------------------
                            // NUMBER
                            // ------------------------------------

                            StyledText {
                                anchors.centerIn: parent

                                variant:
                                    day.modelData.isToday
                                        ? "dayNumberActive"
                                        : "dayNumber"

                                font.pixelSize:
                                    day.modelData.isToday
                                        ? 12
                                        : 10

                                font.weight:
                                    day.modelData.isToday
                                        ? Font.DemiBold
                                        : Font.Normal

                                text:
                                    day.modelData.number

                                color: {
                                    if (day.modelData.isToday) {
                                        return Theme.colors.accentText
                                    }

                                    if (day.modelData.isSunday) {
                                        return root.sundayColor
                                    }

                                    return Qt.rgba(
                                        1, 1, 1, 0.80
                                    )
                                }
                            }
                        }
                    }
                }

                HoverHandler {
                    cursorShape:
                        Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped:
                        UiState.toggleCalendar()
                }
            }
        }
    }
}