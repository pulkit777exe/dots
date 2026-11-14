#!/usr/bin/env python3
"""Collect read-only system information for the settings About page."""

from __future__ import annotations

import json
import os
import platform
import re
import shutil
import socket
import subprocess
from pathlib import Path


def run(cmd: list[str], timeout: int = 4) -> str:
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        ).stdout.strip()
    except Exception:
        return ""


def os_name() -> str:
    try:
        for line in Path("/etc/os-release").read_text().splitlines():
            if line.startswith("PRETTY_NAME="):
                return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return platform.system()


def cpu_name() -> str:
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "Unknown"


def memory() -> tuple[str, float]:
    values = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, _, rest = line.partition(":")
            values[key] = int(rest.strip().split()[0])
    except (OSError, ValueError, IndexError):
        return "Unknown", 0
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", total)
    used = max(0, total - available)
    if total == 0:
        return "Unknown", 0
    return f"{used / 1024 / 1024:.1f} GB of {total / 1024 / 1024:.1f} GB", used / total


def disk() -> str:
    try:
        usage = shutil.disk_usage("/")
    except OSError:
        return "Unknown"
    free = usage.free / 1024**3
    total = usage.total / 1024**3
    return f"{free:.0f} GB free of {total:.0f} GB"


def uptime() -> str:
    try:
        seconds = int(float(Path("/proc/uptime").read_text().split()[0]))
    except (OSError, ValueError, IndexError):
        return "Unknown"
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes = rem // 60
    if days:
        return f"{days}d {hours}h {minutes}m"
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def graphics() -> str:
    out = run(["lspci"], timeout=3)
    cards = [
        re.sub(r"\s*\(rev [^)]+\)", "", line.split(": ", 1)[1]).strip()
        for line in out.splitlines()
        if "VGA compatible controller" in line or "3D controller" in line
    ]
    return ", ".join(dict.fromkeys(cards)) or "Unknown"


def compositor_version() -> str:
    out = run(["hyprctl", "version"])
    match = re.search(r"Hyprland\s+v?([0-9][0-9.]*)", out)
    if match:
        return match.group(1)
    return out.splitlines()[0] if out else "Not running"


def shell_version() -> str:
    out = run(["quickshell", "--version"])
    match = re.search(r"([0-9]+\.[0-9]+\.[0-9]+)", out)
    return match.group(1) if match else (out.splitlines()[0] if out else "Unknown")


def device_model() -> str:
    for name in ("product_name", "product_version"):
        try:
            value = Path(f"/sys/devices/virtual/dmi/id/{name}").read_text().strip()
            if value and value.lower() != "none":
                return value
        except OSError:
            continue
    return ""


def main() -> int:
    mem_text, mem_fraction = memory()
    info = {
        "hostname": socket.gethostname(),
        "device": device_model(),
        "os": os_name(),
        "kernel": platform.release(),
        "arch": platform.machine(),
        "uptime": uptime(),
        "desktop": os.environ.get("XDG_CURRENT_DESKTOP", "Hyprland"),
        "session": os.environ.get("XDG_SESSION_TYPE", "wayland"),
        "cpu": cpu_name(),
        "cores": os.cpu_count() or 0,
        "gpu": graphics(),
        "memory": mem_text,
        "memoryFraction": mem_fraction,
        "disk": disk(),
        "hyprland": compositor_version(),
        "quickshell": shell_version(),
    }
    print(json.dumps(info))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
