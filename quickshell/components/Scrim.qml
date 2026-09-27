import QtQuick

// Scrim
// Full-area dim backdrop, placed behind a modal (auth dialog, etc.).
// Fill the parent (usually the panel window's root) and stack the
// modal surface on top of it.
Rectangle {
    id: root

    property color scrimColor: Qt.rgba(0, 0, 0, 0.45)
    property bool dismissOnClick: true

    signal dismissed()

    color: scrimColor

    MouseArea {
        anchors.fill: parent
        enabled: root.dismissOnClick
        onClicked: root.dismissed()
    }

    // block clicks from reaching whatever is behind the scrim even
    // when dismissOnClick is false
    MouseArea {
        anchors.fill: parent
        enabled: !root.dismissOnClick
    }
}
