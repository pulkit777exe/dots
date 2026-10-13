#!/usr/bin/env python3
"""Re-adopt orphaned StatusNotifierItems after a shell restart.

Tray clients are supposed to re-register with a new watcher/host on
their own, but several (Proton VPN, various Electron apps) register
once at startup and never again. Their item objects stay alive on the
session bus, so the new watcher can adopt them: registering on an
app's behalf is legitimate here -- the watcher validates that the
service still owns its name and skips duplicates.

Usage: adopt-tray-items.py [--list]
  --list prints candidate services without registering them.
"""

import re
import sys

ITEM_RE = re.compile(
    r"^(org\.kde|org\.freedesktop)\.StatusNotifierItem(-.+)?$")
WATCHER = "org.kde.StatusNotifierWatcher"
WATCHER_PATH = "/StatusNotifierWatcher"


def session_bus():
    try:
        import dbus
    except ImportError:
        print("adopt-tray: python dbus bindings not available",
              file=sys.stderr)
        return None
    try:
        return dbus.SessionBus()
    except Exception as e:
        print(f"adopt-tray: cannot reach session bus: {e}",
              file=sys.stderr)
        return None


def candidates(bus):
    names = bus.list_names()
    return sorted(n for n in names
                  if ITEM_RE.match(n) and n != WATCHER)


def adopt(bus, services, dry_run=False):
    watcher = bus.get_object(WATCHER, WATCHER_PATH)
    adopted = []
    for service in services:
        if dry_run:
            adopted.append(service)
            continue
        try:
            watcher.RegisterStatusNotifierItem(
                service,
                dbus_interface="org.kde.StatusNotifierWatcher")
            adopted.append(service)
        except Exception as e:
            print(f"adopt-tray: {service}: {e}", file=sys.stderr)
    return adopted


def main():
    dry_run = "--list" in sys.argv
    bus = session_bus()
    if bus is None:
        return 1
    try:
        bus.get_object(WATCHER, WATCHER_PATH)
    except Exception:
        print("adopt-tray: no StatusNotifierWatcher on the bus yet",
              file=sys.stderr)
        return 1
    services = candidates(bus)
    for service in adopt(bus, services, dry_run):
        print(f"adopt-tray: {service}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
