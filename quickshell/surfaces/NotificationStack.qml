import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"






Item {
    id: root

    width: ConfigStore.notifWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            
            
            
            
            
            
            
            
            
            
            
            
            model: Notifications.popups

            Notification {
                required property var modelData
                Layout.fillWidth: true

                
                
                
                
                
                icon: modelData.urgency === 2 ? "priority_high" : ""
                iconColor: Theme.colors.accent
                iconBackground: "#211c1b"

                appName: modelData.appName
                title: modelData.summary
                subtitle: ""
                body: ConfigStore.notifShowBodyText ? modelData.body : ""

                onDismissed: Notifications.dismiss(modelData.id)
                
                
                
                
                
                
                
                
                onClicked: {
                    const defaultAction =
                        modelData.actions.find((a) => a.id === "default");
                    if (defaultAction)
                        Notifications.invokeAction(modelData.id, "default");
                }
                onActionInvoked: (actionId) => Notifications.invokeAction(modelData.id, actionId)
            }
        }
    }
}
