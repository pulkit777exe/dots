pragma Singleton
pragma ComponentBehavior: Bound





import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io



Singleton {
    id: root

    

    property var active: []

    signal notificationAdded(var notification)
    signal notificationRemoved(int id)

    

    property alias dnd: props.dnd

    property bool loaded: false

    readonly property var notClosed:
        active

    readonly property var popups:
        active.filter(n => n.popup !== false)

    property int defaultExpireTimeout: ConfigStore.notifPopupTimeoutMs
    property int fullscreenExpireTimeout: 3000
    property int urgentExpireTimeout: ConfigStore.notifUrgentTimeoutMs

    property bool expire: true

    function hasFullscreen(): bool {
        return false
    }

    function shouldShowPopup(): bool {
        if (props.dnd)
            return false

        try {
            if (
                UiState &&
                (
                    UiState.launcherOpen ||
                    UiState.controlCenterOpen
                )
            ) {
                return false
            }
        } catch (e) {}

        if (hasFullscreen())
            return false

        return true
    }

    
    
    
    
    
    
    
    function playNotifySound(): void {
        if (!ConfigStore.notifSoundEnabled) return
        soundPlayer.command = [
            "bash", "-c",
            "canberra-gtk-play -i message-new-instant 2>/dev/null || " +
            "paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga 2>/dev/null"
        ]
        soundPlayer.running = true
    }

    Process {
        id: soundPlayer
    }

    onDndChanged: {
        if (dnd) {
            console.log(
                "Do not disturb enabled — popup notifications disabled"
            )
        } else {
            console.log(
                "Do not disturb disabled — popup notifications enabled"
            )
        }
    }

    onActiveChanged: {
        if (loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer

        interval: 1000

        onTriggered: {
            storage.setText(
                JSON.stringify(
                    root.notClosed.map(n => ({
                        time: new Date().toISOString(),

                        id: n.id,
                        summary: n.summary,
                        body: n.body,

                        appIcon: n.appIcon,
                        appName: n.appName,

                        image: n.image,

                        expireTimeout:
                            n.expireTimeout ??
                            root.defaultExpireTimeout,

                        urgency: n.urgency,
                        actions: n.actions
                    }))
                )
            )
        }
    }

    PersistentProperties {
        id: props

        reloadableId: "notifs"

        property bool dnd: false
    }

    

    NotificationServer {
        id: server

        keepOnReload: false

        bodySupported: true
        bodyMarkupSupported: true

        actionsSupported: true

        imageSupported: true
        persistenceSupported: true

        bodyHyperlinksSupported: true
        bodyImagesSupported: true

        onNotification: (notification) => {
            const shouldPopup =
                root.shouldShowPopup()

            const entry = {
                id: notification.id,

                appName:
                    notification.appName || "",

                appIcon:
                    notification.appIcon || "",

                summary:
                    notification.summary || "",

                body:
                    notification.body || "",

                urgency:
                    notification.urgency,

                actions:
                    (notification.actions || [])
                        .map(a => ({
                            id: a.identifier,
                            label: a.text
                        })),

                image:
                    notification.image || "",

                popup:
                    shouldPopup,

                expireTimeout:
                    notification.expireTimeout
            }

            let list =
                root.active.slice()

            list.push(entry)

            root.active = list

            root.notificationAdded(entry)

            if (shouldPopup) root.playNotifySound()

            const isCritical =
                notification.urgency ===
                NotificationUrgency.Critical

            const timeoutMs =
                notification.expireTimeout > 0
                    ? notification.expireTimeout
                    : (
                        isCritical
                            ? root.urgentExpireTimeout
                            : (
                                root.hasFullscreen()
                                    ? root.fullscreenExpireTimeout
                                    : root.defaultExpireTimeout
                            )
                    )

            
            
            
            
            
            
            expireTimerComponent.createObject(
                root,
                {
                    targetId: entry.id,
                    interval: timeoutMs
                }
            )

            notification.tracked = true
        }
    }

    Component {
        id: expireTimerComponent

        Timer {
            property int targetId: -1

            running: true
            repeat: false

            onTriggered: {
                root.dismiss(targetId)
                destroy()
            }
        }
    }

    

    function dismiss(id: int): void {
        const idx =
            root.active.findIndex(
                n => n.id === id
            )

        if (idx === -1)
            return

        let list =
            root.active.slice()

        list.splice(idx, 1)

        root.active = list

        root.notificationRemoved(id)

        

        const handle =
            Array.from(
                server.trackedNotifications?.values ?? []
            ).find(
                n => n.id === id
            )

        if (handle)
            handle.dismiss()
    }

    function invokeAction(
        id: int,
        actionId: string
    ): void {
        

        const handle =
            Array.from(
                server.trackedNotifications?.values ?? []
            ).find(
                n => n.id === id
            )

        if (handle)
            handle.invokeAction(actionId)

        dismiss(id)
    }

    function clearAll(): void {
        for (const n of root.active.slice())
            dismiss(n.id)
    }

    

    FileView {
        id: storage

        printErrors: true

        path:
            Quickshell.statePath(
                "notifs.json"
            )

        onLoaded: {
            try {
                const data =
                    JSON.parse(text())

                let list =
                    root.active.slice()

                for (const notif of data) {
                    list.push({
                        id:
                            notif.id ??
                            notif.notificationId ??
                            Math.floor(
                                Math.random() * 1000000
                            ),

                        appName:
                            notif.appName ?? "",

                        appIcon:
                            notif.appIcon ?? "",

                        summary:
                            notif.summary ?? "",

                        body:
                            notif.body ?? "",

                        urgency:
                            notif.urgency ??
                            NotificationUrgency.Normal,

                        actions:
                            notif.actions ?? [],

                        image:
                            notif.image ?? "",

                        popup:
                            false
                    })
                }

                root.active = list
            } catch (e) {
                console.warn(
                    "Notifications: failed to parse state",
                    path,
                    e
                )
            }

            root.loaded = true
        }

        onLoadFailed: (err) => {
            console.warn(
                "Notifications: failed to load",
                path,
                err
            )

            root.loaded = true

            if (
                err ===
                FileViewError.FileNotFound
            ) {
                Qt.callLater(
                    () => setText("[]")
                )
            }
        }
    }

    

    function notify(
        summary,
        body,
        appName,
        appIcon,
        urgency,
        actions
    ) {
        
        
        
        
        const name =
            appName || "System"

        const icon =
            appIcon || "notifications"

        const level =
            urgency !== undefined
                ? urgency
                : NotificationUrgency.Normal

        const actionList =
            actions || []

        const notifId =
            Math.floor(
                Math.random() * 899999
            ) + 100000

        const shouldPopup =
            root.shouldShowPopup()

        const entry = {
            id: notifId,

            appName: name,
            appIcon: icon,

            summary:
                summary || "",

            body:
                body || "",

            urgency:
                level,

            actions:
                actionList,

            image:
                "",

            popup:
                shouldPopup,

            expireTimeout:
                level === NotificationUrgency.Critical
                    ? root.urgentExpireTimeout
                    : root.defaultExpireTimeout
        }

        let list =
            root.active.slice()

        list.push(entry)

        root.active = list

        root.notificationAdded(entry)

        if (shouldPopup) {
            root.playNotifySound()
        }

        
        
        
        
        
        
        expireTimerComponent.createObject(
            root,
            {
                targetId: notifId,
                interval: entry.expireTimeout
            }
        )

        return notifId
    }

    

    
    Connections {
        target: Battery

        property bool wasCharging:
            Battery.charging

        property bool initialised: false

        property bool warnedLow: false
        property bool warnedCritical: false

        function onChargingChanged() {
            if (!initialised) {
                initialised = true
                wasCharging =
                    Battery.charging
                return
            }

            if (
                Battery.charging !==
                wasCharging
            ) {
                wasCharging =
                    Battery.charging

                if (Battery.charging) {
                    warnedLow = false
                    warnedCritical = false

                    root.notify(
                        "Charger Connected",

                        "Battery is now charging (" +
                        Battery.percentage +
                        "%)",

                        "Power",

                        "battery_charging_full"
                    )
                } else {
                    root.notify(
                        "Charger Disconnected",

                        "Running on battery power (" +
                        Battery.percentage +
                        "%)",

                        "Power",

                        "battery_alert"
                    )
                }
            }
        }

        function onBatteryLow() {
            if (warnedLow)
                return

            warnedLow = true

            root.notify(
                "Low Battery",

                Battery.percentage +
                "% remaining. Consider connecting a charger.",

                "Power",

                "battery_saver",

                NotificationUrgency.Critical
            )
        }

        function onBatteryCritical() {
            if (warnedCritical)
                return

            warnedCritical = true

            root.notify(
                "Critical Battery",

                Battery.percentage +
                "% remaining. Plug in immediately to avoid shutdown!",

                "Power",

                "battery_alert",

                NotificationUrgency.Critical
            )
        }
    }

    property bool systemNotifsReady: false

    Timer {
        interval: 3000

        running: true
        repeat: false

        onTriggered:
            root.systemNotifsReady = true
    }

    
    Connections {
        target: Bluetooth

        property bool wasEnabled:
            Bluetooth.enabled

        function onEnabledChanged() {
            if (!root.systemNotifsReady) {
                wasEnabled =
                    Bluetooth.enabled
                return
            }

            if (
                Bluetooth.enabled !==
                wasEnabled
            ) {
                wasEnabled =
                    Bluetooth.enabled

                if (Bluetooth.enabled) {
                    root.notify(
                        "Bluetooth Enabled",
                        "Bluetooth adapter turned on",
                        "Bluetooth",
                        "bluetooth"
                    )
                } else {
                    root.notify(
                        "Bluetooth Disabled",
                        "Bluetooth adapter turned off",
                        "Bluetooth",
                        "bluetooth_disabled"
                    )
                }
            }
        }
    }

    
    Connections {
        target: Wifi

        property bool wasConnected:
            Wifi.connected

        function onConnectedChanged() {
            if (!root.systemNotifsReady) {
                wasConnected =
                    Wifi.connected
                return
            }

            if (
                Wifi.connected !==
                wasConnected
            ) {
                wasConnected =
                    Wifi.connected

                if (Wifi.connected) {
                    root.notify(
                        "Wi-Fi Connected",

                        "Connected to " +
                        (Wifi.ssid || "network"),

                        "Network",

                        "wifi"
                    )
                } else {
                    root.notify(
                        "Wi-Fi Disconnected",

                        "Disconnected from network",

                        "Network",

                        "wifi_off"
                    )
                }
            }
        }
    }

    
    Connections {
        target: PowerProfile

        property bool initialised: false

        function onProfileChanged(profile) {
            if (!initialised) {
                initialised = true
                return
            }

            const activeProfile =
                profile ||
                PowerProfile.active

            const modeName =
                activeProfile.charAt(0).toUpperCase()
                +
                activeProfile.slice(1)

            root.notify(
                "Power Profile Changed",

                "Switched to " +
                modeName +
                " mode",

                "Power",

                "speed"
            )
        }
    }

    
    Connections {
        target: NightLight

        property bool initialised: false

        function onToggled(enabled) {
            if (!initialised) {
                initialised = true
                return
            }

            root.notify(
                "Night Light",

                enabled
                    ? "Screen warmth enabled"
                    : "Screen warmth disabled",

                "Display",

                "nightlight"
            )
        }
    }

    
    Connections {
        target: IdleInhibit

        property bool initialised: false

        property bool wasActive:
            IdleInhibit.active

        function onActiveChanged() {
            if (!initialised) {
                initialised = true
                wasActive =
                    IdleInhibit.active
                return
            }

            if (
                IdleInhibit.active !==
                wasActive
            ) {
                wasActive =
                    IdleInhibit.active

                root.notify(
                    "Keep-Awake Inhibitor",

                    IdleInhibit.active
                        ? "Screen sleep inhibited"
                        : "Screen sleep allowed",

                    "System",

                    "coffee"
                )
            }
        }
    }

    
    Connections {
        target: Theme

        property bool initialised: false

        property string lastName:
            Theme.currentName

        function onThemeChanged(name) {
            if (!initialised) {
                initialised = true
                lastName = name
                return
            }

            if (name !== lastName) {
                lastName = name

                root.notify(
                    "Theme Changed",

                    "Applied " +
                    (
                        Theme.displayName ||
                        name
                    ) +
                    " theme",

                    "Appearance",

                    "palette"
                )
            }
        }
    }

    
    Connections {
        target: Volume

        property bool initialised: false

        property bool wasMuted:
            Volume.muted

        function onMutedChanged() {
            if (!initialised) {
                initialised = true
                wasMuted =
                    Volume.muted
                return
            }

            if (
                Volume.muted !==
                wasMuted
            ) {
                wasMuted =
                    Volume.muted

                if (Volume.muted) {
                    root.notify(
                        "Audio Muted",

                        "Sound output muted",

                        "Audio",

                        "volume_mute"
                    )
                } else {
                    root.notify(
                        "Audio Unmuted",

                        "Sound output at " +
                        Volume.volumePercent +
                        "%",

                        "Audio",

                        "volume_up"
                    )
                }
            }
        }
    }

    
    Connections {
        target: Media

        property bool initialised: false
        property string lastTrackKey: ""

        function maybeToast() {
            if (
                !ConfigStore.mediaShowToast
            )
                return

            if (!Media.playing)
                return

            const key =
                Media.title +
                "|" +
                Media.artist

            if (
                !Media.title ||
                key === lastTrackKey ||
                key === "|"
            )
                return

            lastTrackKey = key

            if (!initialised) {
                initialised = true
                return
            }

            const body =
                Media.artist
                    ? Media.artist +
                      (
                          Media.album
                              ? " · " +
                                Media.album
                              : ""
                      )
                    : ""

            root.notify(
                "Now Playing",

                Media.title +
                (
                    body
                        ? "\n" + body
                        : ""
                ),

                "Music",

                "music_note"
            )
        }

        function onTitleChanged() {
            maybeToast()
        }

        function onArtistChanged() {
            maybeToast()
        }

        function onPlayingChanged() {
            if (Media.playing) {
                initialised = true
                maybeToast()
            }
        }
    }

    
    
    
    
    Connections {
        target: Clipboard

        property bool initialised: false

        function onEntryCopied(text) {
            if (!initialised) {
                initialised = true
                return
            }

            const preview =
                text.length > 60
                    ? text.slice(0, 60) + "…"
                    : text

            root.notify(
                "Copied to Clipboard",

                preview,

                "System",

                "content_copy"
            )
        }
    }

    

    IpcHandler {
        target: "notifs"

        function clear(): void {
            for (
                const n of root.active.slice()
            ) {
                root.dismiss(n.id)
            }
        }

        function isDndEnabled(): bool {
            return root.dnd
        }

        function toggleDnd(): void {
            root.dnd =
                !root.dnd
        }

        function enableDnd(): void {
            root.dnd = true
        }

        function disableDnd(): void {
            root.dnd = false
        }

        function list(): string {
            return root.active
                .map(
                    n =>
                        `${n.appName}: ${n.summary}`
                )
                .join("\n")
        }
    }

    IpcHandler {
        target: "notifications"

        function clear(): void {
            root.clearAll()
        }

        function toggleDnd(): void {
            root.dnd =
                !root.dnd
        }
    }
}