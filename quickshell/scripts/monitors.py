#!/usr/bin/env python3
"""Monitor info and per-monitor brightness for the shell's Display page.

    monitors.py info             one JSON array to stdout
    monitors.py set NAME PCT     set brightness (0-100), print the new value

Hyprland reports geometry/mode/scale/focus; brightness needs ddcutil for
external panels and brightnessctl for the laptop backlight, so this glues
the two together rather than making QML run three parsers.
"""

import json
import re
import shutil
import subprocess
import sys

BRIGHTNESS_VCP = "10"  # MCCS VCP code for Brightness


def run(cmd, timeout=8):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


def hyprctl_json(cmd):
    try:
        return json.loads(run(["hyprctl", "-j"] + cmd) or "[]")
    except Exception:
        return []


def ddc_buses():
    """connector name (card1-DP-1 -> DP-1) -> i2c bus number"""
    out = run(["ddcutil", "detect", "--brief"], timeout=10)
    buses = {}
    block, connector, bus = {}, None, None
    for line in out.splitlines():
        if line.startswith("Display") and connector is not None:
            buses[connector] = bus
            connector, bus = None, None
        m = re.search(r"I2C bus:\s*/dev/i2c-(\d+)", line)
        if m:
            bus = int(m.group(1))
        m = re.search(r"DRM connector:\s*(\S+)", line)
        if m:
            connector = re.sub(r"^card\d+-", "", m.group(1))
    if connector is not None:
        buses[connector] = bus
    return buses


def ddc_brightness(bus):
    out = run(["ddcutil", "-b", str(bus), "getvcp", BRIGHTNESS_VCP])
    m = re.search(r"current value\s*=\s*(\d+)\s*,\s*max value\s*=\s*(\d+)", out)
    if not m:
        return None
    cur, mx = int(m.group(1)), int(m.group(2))
    return round(cur / mx * 100) if mx else None


def backlight_brightness():
    """(current, max) of the laptop backlight, via brightnessctl."""
    if not shutil.which("brightnessctl"):
        return None
    out = run(["brightnessctl", "-m"])
    parts = out.strip().split(",")
    if len(parts) < 4:
        return None
    try:
        cur, mx = int(parts[2]), int(parts[3])
    except ValueError:
        return None
    return (cur, mx)


def info():
    monitors = hyprctl_json(["monitors"])
    buses = ddc_buses() if shutil.which("ddcutil") else {}
    panel = backlight_brightness()
    result = []
    for m in monitors:
        name = m.get("name", "")
        hz = m.get("refreshRate", m.get("refresh", 0))
        try:
            hz = float(hz)
        except (TypeError, ValueError):
            hz = 0.0
        if hz > 1000:  # millihertz
            hz /= 1000
        bus = buses.get(name)
        brightness = ddc_brightness(bus) if bus is not None else None
        if brightness is None and panel and name.startswith("eDP"):
            brightness = round(panel[0] / panel[1] * 100) if panel[1] else None
        result.append({
            "name": name,
            "width": m.get("width", 0),
            "height": m.get("height", 0),
            "hz": round(hz, 2),
            "scale": m.get("scale", 1.0),
            "focused": bool(m.get("focused", False)),
            "modes": m.get("availableModes", []),
            "brightness": brightness,
        })
    return result


def set_brightness(name, pct):
    pct = max(1, min(100, int(round(pct))))
    buses = ddc_buses() if shutil.which("ddcutil") else {}
    bus = buses.get(name)
    if bus is not None:
        run(["ddcutil", "-b", str(bus), "setvcp", BRIGHTNESS_VCP, str(pct)])
        value = ddc_brightness(bus)
    else:
        if not shutil.which("brightnessctl"):
            print("null")
            return
        run(["brightnessctl", "set", f"{pct}%"])
        panel = backlight_brightness()
        value = round(panel[0] / panel[1] * 100) if panel and panel[1] else pct
    print(json.dumps(value))


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "info":
        print(json.dumps(info()))
    elif len(sys.argv) == 4 and sys.argv[1] == "set":
        set_brightness(sys.argv[2], float(sys.argv[3]))
    else:
        sys.exit("usage: monitors.py info | monitors.py set NAME PCT")


if __name__ == "__main__":
    main()
