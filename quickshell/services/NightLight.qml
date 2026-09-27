pragma Singleton
// qmllint disable import
// qmllint disable signal-handler-parameters

import QtQuick
import Quickshell
import Quickshell.Io

/*
  NightLight service.

  Wraps hyprsunset — the Hyprland-ecosystem blue-light/color-temperature
  daemon — via `hyprctl hyprsunset ...`.

  IMPORTANT — this is NOT the same shape as the other services:
    - hyprsunset must already be RUNNING as its own daemon (typically
      started once via `exec-once = hyprsunset` in hyprland.conf) for
      `hyprctl hyprsunset ...` to have any effect. This service does not
      launch it. (Theme.qml's wallpaper daemon is a counter-example —
      it owns swaybg itself — but swaybg is a self-contained one-off
      child process, not a session-long stateful IPC peer the way
      hyprsunset is.)
    - There is no documented `hyprctl hyprsunset get`/status query, so
      unlike Wifi/Bluetooth/PowerProfile (which stay in sync via a
      monitor process), `enabled` here is optimistic local state, not
      a confirmed read-back — if hyprsunset isn't actually running,
      the toggle will silently do nothing and this service has no way
      to know that. `available` is only a binary-presence check
      (`command -v hyprsunset`), not proof the daemon is live.

  On why this exists instead of a wallpaper-colour extractor: those tools
  are either X11-only or need an external daemon we don't want in the
  loop, and colours are now purely static anyway. hyprsunset is the
  Wayland/Hyprland-native equivalent.
*/

Singleton {
    id: root

    property bool available: false
    property bool enabled: false
    property int dayTemperature: 6000
    property int nightTemperature: 4000

    signal toggled(bool enabled)

    function toggle() {
        setEnabled(!enabled)
    }

    function setEnabled(value) {
        if (!available) return
        enabled = value
        if (value) {
            setter.command = ["hyprctl", "hyprsunset", "temperature", String(nightTemperature)]
        } else {
            setter.command = ["hyprctl", "hyprsunset", "identity"]
        }
        setter.running = true
        toggled(enabled)
    }

    function setTemperature(kelvin) {
        nightTemperature = kelvin
        if (available && enabled) {
            setter.command = ["hyprctl", "hyprsunset", "temperature", String(kelvin)]
            setter.running = true
        }
    }

    Process { id: setter; onExited: (code) => { if (code !== 0) console.warn("NightLight: redshift set failed (exit", code, ")") } }

    // Best-effort presence check only — see docstring above.
    Process {
        id: probe
        command: ["bash", "-c", "command -v hyprsunset >/dev/null && echo yes || echo no"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => { if (line.trim() === "yes") root.available = true }
        }
    }
    Component.onCompleted: probe.running = true

    IpcHandler {
        target: "nightlight"
        function isEnabled(): bool { return root.enabled; }
        function toggle(): void { root.toggle(); }
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function setTemp(k: string): void { root.setTemperature(parseInt(k)); }
    }

}
