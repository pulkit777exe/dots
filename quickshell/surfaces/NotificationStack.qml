import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

// NotificationStack
// Vertical stack of Notification.qml cards. Backed 1:1 by
// Notifications.popups -- nothing here polls; cards appear/disappear
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
            // popups, not active. `active` is every entry the service knows
            // about, which includes the history restored from notifs.json at
            // startup -- and those are explicitly marked popup:false, since
            // yesterday's notifications are not popups. Rendering `active`
            // showed that history as live cards that no expire timer would
            // ever remove, so the stack filled with undismissable toasts
            // (observed: the two Wi-Fi toasts from a previous session
            // reappearing on every start and staying forever).
            //
            // DND and "the launcher or control centre is open" also mark
            // entries popup:false, and both now expire on their own timer, so
            // suppressing them here no longer leaks them.
            model: Notifications.popups

            Notification {
                required property var modelData
                Layout.fillWidth: true

                // The reference toast shows the app's own icon and falls
                // back to the app name's initial, so a synthetic glyph is
                // only supplied for the urgencies the reference singles
                // out. Leaving `icon` empty for Normal/Low is what lets the
                // "N" fallback appear instead of a generic bell.
                icon: modelData.urgency === 2 ? "priority_high" : ""
                iconColor: Theme.colors.accent
                iconBackground: "#211c1b"

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
