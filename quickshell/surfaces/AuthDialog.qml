import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

Surface {
    id: root

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    width: 430
    implicitHeight: column.implicitHeight + 31

    cornerRadius: 26

    
    
    
    backgroundColor: "#000000"

    property color accent: Theme.colors.accent

    
    
    
    readonly property color insetFill: "#100e0c"
    readonly property color fieldFill: "#000000"
    readonly property color badgeInset: "#211c1b"

    readonly property var pendingRequest: Auth.pending

    readonly property string dialogTitle: "Authentication required"

    readonly property string message:
        pendingRequest ? pendingRequest.message : ""

    readonly property string actionId:
        pendingRequest ? pendingRequest.actionId : ""

    readonly property string errorText:
        pendingRequest ? pendingRequest.errorText : ""

    signal authenticateRequested(string password)
    signal cancelled()

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        anchors.topMargin: 14
        anchors.bottomMargin: 15

        spacing: 0

        
        
        

        RowLayout {
            Layout.fillWidth: true
            
            
            
            Layout.preferredHeight: 30
            spacing: 13

            
            
            
            
            
            Rectangle {
                Layout.preferredWidth: 29
                Layout.preferredHeight: 29
                radius: width / 2

                color: root.accent

                Icon {
                    anchors.centerIn: parent
                    icon: "lock"
                    size: 16
                    iconColor: Theme.colors.accentText
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                text: root.dialogTitle

                font.pixelSize: 18
                font.weight: Font.DemiBold

                color: "#FFFFFF"

                elide: Text.ElideRight
            }
        }

        
        
        
        
        
        
        

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 12

            
            implicitHeight: messageCol.implicitHeight + 21
            radius: 14

            color: root.insetFill

            ColumnLayout {
                id: messageCol

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 11
                anchors.bottomMargin: 10

                spacing: 0

                StyledText {
                    Layout.fillWidth: true

                    visible: root.message.length > 0

                    text: root.message

                    color: "#FFFFFF"

                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    
                    
                    
                    
                    lineHeight: 1.0

                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    visible: root.actionId.length > 0

                    text: root.actionId

                    color: "#8a8a8a"

                    font.pixelSize: 13

                    elide: Text.ElideRight
                }
            }
        }

        
        
        

        StyledText {
            Layout.fillWidth: true

            visible: root.message.length > 0 || root.actionId.length > 0

            text: "Password"

            color: "#7a7a7a"

            font.pixelSize: 13
        }

        
        
        
        
        
        

        Rectangle {
            id: passwordBox

            Layout.fillWidth: true
            Layout.topMargin: 11
            
            
            Layout.preferredHeight: 42

            radius: height / 2

            color: root.fieldFill

            border.width: 1
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)

            Behavior on border.color {
                ColorAnimation { duration: MotionConfig.hover() }
            }

            Rectangle {
                id: fieldBadge

                anchors.left: parent.left
                
                
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter

                width: 26
                height: 26
                radius: width / 2

                color: root.badgeInset

                Icon {
                    anchors.centerIn: parent
                    icon: "lock"
                    size: 14
                    iconColor: "#9a9a9a"
                }
            }

            TextInput {
                id: passwordField

                anchors.fill: parent
                
                
                
                anchors.leftMargin: 38
                anchors.rightMargin: 15

                verticalAlignment: TextInput.AlignVCenter

                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                echoMode: TextInput.Password

                color: "#FFFFFF"

                font.family: "SF Pro Display"
                font.pixelSize: 16

                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnTab: true

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    visible:
                        passwordField.text.length === 0

                    
                    
                    
                    
                    text: "Enter your password"

                    font.family: "SF Pro Display"
                    font.pixelSize: 16
                    color: "#8a8a8a"
                }

                onAccepted:
                    root.authenticateRequested(text)

                Component.onCompleted: {
                    if (Auth.pending)
                        forceActiveFocus()
                }

                onVisibleChanged: {
                    if (visible && Auth.pending)
                        forceActiveFocus()
                }

                Connections {
                    target: Auth

                    function onRequestBegan() {
                        passwordField.text = ""

                        Qt.callLater(function() {
                            passwordField.forceActiveFocus()
                        })
                    }
                }
            }
        }

        
        
        

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 6

            visible: root.errorText.length > 0

            text: root.errorText

            color: Theme.colors.danger

            font.pixelSize: 12

            wrapMode: Text.WordWrap
        }

        
        
        

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 11

            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            
            
            

            Rectangle {
                id: cancelButton

                
                
                Layout.preferredWidth: 73
                Layout.preferredHeight: 32

                radius: height / 2

                color:
                    cancelMouse.containsMouse
                        ? "#1c1917"
                        : root.insetFill

                Behavior on color {
                    ColorAnimation {
                        duration: MotionConfig.hover()
                    }
                }

                StyledText {
                    anchors.centerIn: parent

                    text: "Cancel"

                    font.pixelSize: 15
                    font.weight: Font.Medium

                    color: "#e6e6e6"
                }

                MouseArea {
                    id: cancelMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onClicked:
                        root.cancelled()
                }
            }

            
            
            

            Rectangle {
                id: authenticateButton

                
                
                
                Layout.preferredWidth: 110
                Layout.preferredHeight: 32

                radius: height / 2

                color:
                    authenticateMouse.pressed
                        ? Theme.colors.accentAlt
                        : root.accent

                Behavior on color {
                    ColorAnimation {
                        duration: MotionConfig.hover()
                    }
                }

                StyledText {
                    anchors.centerIn: parent

                    text: "Authenticate"

                    font.pixelSize: 15
                    font.weight: Font.DemiBold

                    color: Theme.colors.accentText
                }

                MouseArea {
                    id: authenticateMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onClicked:
                        root.authenticateRequested(
                            passwordField.text
                        )
                }
            }
        }
    }
}
