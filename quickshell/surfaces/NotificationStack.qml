import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// NotificationStack
// Vertical stack of Notification.qml cards. Backed 1:1 by
// Notifications.active — nothing here polls; entries appear/disappear
// exactly when the service's list changes (a dbus notification arrived,
// expired, or was dismissed).
Item {
    id: root

    width: ConfigStore.notifWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            model: Notifications.active

            Notification {
                required property var modelData
                Layout.fillWidth: true

                icon: {
                    switch (modelData.urgency) {
                        case 2: return "priority_high"  // Critical
                        case 0: return "info"           // Low
                        default: return "notifications" // Normal
                    }
                }
                iconColor: modelData.urgency === 2 ? Theme.colors.danger : Theme.colors.accent
                iconBackground: modelData.urgency === 2
                    ? Theme.withAlpha(Theme.colors.danger, 0.18)
                    : Theme.withAlpha(Theme.colors.accent, 0.18)

                appName: modelData.appName
                title: modelData.summary
                subtitle: ""
                body: ConfigStore.notifShowBodyText ? modelData.body : ""

                onDismissed: Notifications.dismiss(modelData.id)
                // The card's own click covers its whole area,
                // including the action-button row below — so this
                // also fires when a specific action button is
                // pressed. Only treat a bare click on the card body as
                // the notification's implicit default action (XDG's
                // "default" action id); a labeled action button's own
                // press is handled correctly and exclusively by
                // onActionInvoked below.
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
