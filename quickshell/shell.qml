import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "core"
import "components"
import "services"

/**
 * Entry point.
 *
 * The PanelWindow now spans the full monitor width (not just auto-sized to
 * content) because it hosts an always-present hot-zone strip at the top --
 * that's how the island can be brought back with the cursor even while its
 * actual content is hidden (workspace-aware auto-hide, see
 * HyprlandService.qml). The visible content itself stays centered and
 * sized to whatever's loaded, same as before.
 *
 * Visibility rule (confirmed): hidden whenever the active workspace has any
 * window AND the island isn't mid-interaction (peeking, expanded, a toast,
 * the launcher, or locked all force it visible regardless of workspace state).
 */
ShellRoot {
    PanelWindow {
        id: window
        anchors.top: true
        anchors.left: true
        anchors.right: true
        margins.top: 6

        implicitHeight: Math.max(Config.hotZoneHeight, content.implicitHeight + 12)
        color: "transparent"
        exclusiveZone: 0

        // Layer-shell surfaces get no keyboard focus by default. "OnDemand"
        // lets a child request it (e.g. Launcher's search TextInput) without
        // permanently stealing focus the rest of the time the island is
        // idle/minimal -- unlike "Exclusive", which would grab focus
        // continuously and break normal desktop use.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        readonly property bool islandVisible: HyprlandService.activeWorkspaceEmpty || IslandState.visible

        // Always-present proximity target. Only this thin strip captures
        // hover/clicks when the island's content is hidden -- everything
        // else in this transparent window passes clicks through to
        // whatever's underneath.
        MouseArea {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Config.hotZoneWidth
            height: Config.hotZoneHeight
            hoverEnabled: true
            onEntered: IslandState.onIslandHoverEntered()
            onExited: IslandState.onIslandHoverExited()
        }

        Loader {
            id: content
            anchors.horizontalCenter: parent.horizontalCenter
            y: window.islandVisible ? 6 : -(implicitHeight + 20)
            opacity: window.islandVisible ? 1 : 0

            Behavior on y { NumberAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Config.animNormal } }

            sourceComponent: {
                switch (IslandState.shape) {
                    case "idle":
                    case "mediaChange":
                        return idlePillComp
                    case "volumeToast":
                        return volumeToastComp
                    case "brightnessToast":
                        return brightnessToastComp
                    case "notifToast":
                        return notifToastComp
                    case "expanded":
                        return controlCenterComp
                    case "launcher":
                        return launcherComp
                    default:
                        return idlePillComp
                }
            }
        }

        Component { id: idlePillComp; IdlePill {} }
        Component { id: volumeToastComp; VolumeToast { isBrightness: false } }
        Component { id: brightnessToastComp; VolumeToast { isBrightness: true } }
        Component { id: notifToastComp; NotificationToast {} }
        Component { id: controlCenterComp; ControlCenter {} }
        Component { id: launcherComp; Launcher {} }
    }

    // -- Toast triggers --
    // IslandState.showToast() existed from the start but nothing ever
    // called it for volume/brightness/media -- these three Connections
    // blocks are the only thing that was missing to make the whole toast
    // system (Images 3/4) actually fire. Notification toasts are already
    // wired from inside NotificationService itself.

    Connections {
        target: AudioService
        function onVolumeChanged() { IslandState.showToast("volumeToast", Config.toastTimeout) }
        function onMutedChanged() { IslandState.showToast("volumeToast", Config.toastTimeout) }
    }

    Connections {
        target: BrightnessService
        function onBrightnessChanged() { IslandState.showToast("brightnessToast", Config.toastTimeout) }
    }

    Connections {
        target: MprisService
        // Guard against firing on every 1s metadata poll -- only when the
        // title actually changes to a new non-empty value while playing.
        property string _lastTitle: ""
        function onTitleChanged() {
            if (MprisService.title !== "" && MprisService.title !== _lastTitle && MprisService.playbackStatus === "Playing") {
                _lastTitle = MprisService.title
                IslandState.showToast("mediaChange", Config.toastTimeout)
            } else {
                _lastTitle = MprisService.title
            }
        }
    }

    // Global keybinds (Hyprland side: config/hyprland-island.conf) call
    // `qs ipc call island <fn>` via scripts/island-dispatch.sh, which lands
    // here. Confirm `qs ipc` is the right invocation for your installed
    // Quickshell version -- the IpcHandler target/function mechanism itself
    // is standard, the exact CLI spelling has shifted across versions.
    IpcHandler {
        target: "island"

        function expanded(): void {
            if (IslandState.shape === "expanded") IslandState.close()
            else IslandState.openExpanded()
        }
        function launcher(): void {
            if (IslandState.shape === "launcher") IslandState.close()
            else IslandState.openLauncher()
        }
        function theme(): void { IslandState.openThemeDirect() }
        function wallpaper(): void { IslandState.openWallpaperDirect() }
        function settings(): void { IslandState.openSettingsDirect() }
        function power(): void { IslandState.openPowerDirect() }
    }
}
