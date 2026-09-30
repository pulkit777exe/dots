import QtQuick
import QtQuick.Layouts

import Quickshell.Services.Notifications

import "../components"
import "../services"

Surface {
    id: root

    
    
    

    property var notification: null
    property var modelData: null

    property string appName: ""
    property string appIcon: ""
    property string icon: ""
    property string title: ""
    property string summary: ""
    property string subtitle: ""
    property string body: ""

    property var urgency: NotificationUrgency.Normal
    property var actions: []
    property string image: ""

    property color iconBackground: "#211c1b"
    property color iconColor: Theme.colors.accent

    
    
    
    
    readonly property bool hasGlyph: (root.icon !== "" || root.appIcon !== "")
    readonly property string initial: {
        const n = String(root.entry.appName || "").trim();
        return n.length > 0 ? n.charAt(0).toUpperCase() : "";
    }

    readonly property var entry: {
        if (root.notification !== null)
            return root.notification

        if (root.modelData !== null)
            return root.modelData

        return {
            appName: root.appName,
            appIcon: root.appIcon,
            icon: root.icon,
            title: root.title,
            summary: root.summary,
            subtitle: root.subtitle,
            body: root.body,
            urgency: root.urgency,
            actions: root.actions,
            image: root.image
        }
    }

    
    
    

    signal clicked
    signal dismissed
    signal actionInvoked(string actionId)

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    width: 449

    
    
    
    
    implicitHeight:
        content.implicitHeight + 24

    cornerRadius: 27

    
    
    backgroundColor: "#000000"

    
    
    borderWidth: 0

    shadow: true

    opacity: 0
    scale: 0.97

    
    
    

    Component.onCompleted: {
        if (MotionConfig.reduceMotion) {
            root.opacity = 1
            root.scale = 1
        } else {
            appearAnimation.start()
        }
    }

    ParallelAnimation {
        id: appearAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: MotionConfig.fade()
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: MotionConfig.fade()
            easing.type: Easing.OutCubic
        }
    }

    
    
    

    TapHandler {
        onTapped: root.clicked()
    }

    HoverHandler { id: hover }

    
    
    

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 0
        anchors.leftMargin: 11
        anchors.rightMargin: 11
        anchors.topMargin: 11
        anchors.bottomMargin: 13

        spacing: 0

        
        
        

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            
            
            
            
            
            
            
            
            

            Rectangle {
                Layout.preferredWidth: 37
                Layout.preferredHeight: 37
                Layout.alignment: Qt.AlignVCenter

                radius: width / 2

                color: root.iconBackground

                Icon {
                    anchors.centerIn: parent

                    visible: root.hasGlyph

                    icon:
                        root.entry.icon
                            ? root.entry.icon
                            : (
                                root.entry.appIcon
                                    ? root.entry.appIcon
                                    : (
                                        root.entry.urgency ===
                                        NotificationUrgency.Critical
                                            ? "warning"
                                            : "notifications"
                                    )
                            )

                    size: 18

                    iconColor: root.iconColor
                }

                
                StyledText {
                    anchors.centerIn: parent

                    visible: !root.hasGlyph && root.initial !== ""

                    text: root.initial

                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold

                    color: root.iconColor
                }
            }

            
            
            
            
            
            
            
            
            
            
            
            

            Item {
                id: textCol

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                readonly property bool hasBody:
                    Boolean(root.entry.subtitle || root.entry.body)

                implicitHeight: hasBody ? 44 : 30
                height: implicitHeight

                StyledText {
                    width: parent.width
                    height: 12
                    verticalAlignment: Text.AlignVCenter

                    text:
                        root.entry.appName ||
                        "Notification"

                    textColor: "#8a8a8a"

                    font.pixelSize: 12
                    font.weight: Font.Medium

                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    height: 16
                    y: 14
                    verticalAlignment: Text.AlignVCenter

                    text:
                        root.entry.title ||
                        root.entry.summary ||
                        ""

                    textColor: "#FFFFFF"

                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    height: 14
                    y: 30
                    verticalAlignment: Text.AlignVCenter

                    visible: parent.hasBody

                    text:
                        root.entry.subtitle ||
                        root.entry.body ||
                        ""

                    textColor: "#8a8a8a"

                    font.pixelSize: 11

                    elide: Text.ElideRight
                }
            }

            
            
            
            
            
            
            
            

            IconButton {
                Layout.alignment: Qt.AlignVCenter

                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: MotionConfig.fade() }
                }

                icon: "close"

                size: 26
                iconSize: 15

                iconColor: "#8a8a8a"

                onClicked: root.dismissed()
            }
        }

        
        
        

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 160 : 0
            Layout.topMargin: visible ? 11 : 0

            visible: Boolean(root.entry.image)

            radius: 13

            color: "#181614"

            clip: true

            Image {
                anchors.fill: parent

                source: root.entry.image || ""

                fillMode: Image.PreserveAspectCrop

                asynchronous: true
                cache: true
                smooth: true
            }
        }

        
        
        

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: visible ? 9 : 0

            visible:
                Array.isArray(root.entry.actions) &&
                root.entry.actions.length > 0

            spacing: 6

            Repeater {
                model:
                    Array.isArray(root.entry.actions)
                        ? root.entry.actions
                        : []

                delegate: StyledButton {
                    required property var modelData

                    text:
                        modelData.label || ""

                    variant:
                        "ghost"

                    onClicked:
                        root.actionInvoked(
                            modelData.id || ""
                        )
                }
            }
        }
    }
}
