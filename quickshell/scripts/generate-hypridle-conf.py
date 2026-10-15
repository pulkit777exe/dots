#!/usr/bin/env python3
"""Generate hypr/hypridle.conf from the desktop settings and power state.

Reads timeouts from the Quickshell settings store — the shell writes
per-instance state, so the newest by-shell/*/settings.json wins, with the
flat $XDG_STATE_HOME/quickshell/settings.json as a fallback — and picks
the battery or charging profile from the AC state
(/sys/class/power_supply/AC*/online, overridable with HYPRIDLE_AC_ONLINE
for tests). A timeout of 0 omits that listener (never). Tolerant of
missing/corrupt files.

Pure function of (settings, ac-state) -> file bytes: run it twice, get the
same conf. The shell regenerates on settings change and plug/unplug;
startup runs it before enabling the hypridle unit.
"""

from __future__ import annotations

import glob
import json
import os
import sys
from pathlib import Path

HOME = Path.home()
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state"))
CONF = (
    Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
    / "hypr"
    / "hypridle.conf"
)

DEFAULTS = {
    "lockTimeoutSec": 120,
    "displayTimeoutSec": 300,
    "suspendTimeoutSec": 600,
    "idleSeparateCharging": False,
    "cLockTimeoutSec": 300,
    "cDisplayTimeoutSec": 600,
    "cSuspendTimeoutSec": 1800,
}


def candidate_settings_paths() -> list[Path]:
    root = STATE_HOME / "quickshell"
    # The shell writes per-instance state (Quickshell.statePath resolves
    # under by-shell/<id>/), so take the most recently modified copy. The
    # flat path stays as a fallback for fresh checkouts and tests.
    by_shell = sorted(
        root.glob("by-shell/*/settings.json"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return [*by_shell, root / "settings.json"]


def load_settings() -> dict:
    for path in candidate_settings_paths():
        try:
            data = json.loads(path.read_text())
        except Exception:
            continue
        if isinstance(data, dict):
            return data
    return {}


def timeout_of(settings: dict, key: str) -> int:
    try:
        v = int(settings.get(key, DEFAULTS[key]))
    except (TypeError, ValueError):
        return DEFAULTS[key]
    return max(0, min(86400, v))


def on_ac_power() -> bool:
    override = os.environ.get("HYPRIDLE_AC_ONLINE")
    if override is not None:
        return override.strip() == "1"
    for node in glob.glob("/sys/class/power_supply/AC*/online"):
        try:
            if Path(node).read_text().strip() == "1":
                return True
        except OSError:
            continue
    return False


def listener(comment: str, timeout: int, on_timeout: str, on_resume: str = "") -> str:
    out = [f"\n# {comment}", "listener {", f"    timeout = {timeout}"]
    out.append(f"    on-timeout = {on_timeout}")
    if on_resume:
        out.append(f"    on-resume = {on_resume}")
    out.append("}")
    return "\n".join(out) + "\n"


def render(lock: int, display: int, suspend: int) -> str:
    conf = """
general {
    lock_cmd = pidof hyprlock || ~/.config/hypr/hyprlock/scripts/lock.sh   # don't spawn a second lock; lock.sh scrubs the fallback on exit
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
}
"""
    if display > 0:
        conf += listener(
            "Display power management — wake/blank on activity",
            display,
            """hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'""",
            """hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'""",
        )
    if suspend > 0:
        conf += listener(
            "Suspend — kernel level via logind", suspend, "systemctl suspend"
        )
    if lock > 0:
        conf += listener(
            "Lock — secure, delegated to hyprlock (system auth, not shell)",
            lock,
            "loginctl lock-session",
        )
    return conf


def main() -> int:
    settings = load_settings()
    separate = bool(settings.get("idleSeparateCharging", False))
    charging_profile = separate and on_ac_power()
    if charging_profile:
        lock = timeout_of(settings, "cLockTimeoutSec")
        display = timeout_of(settings, "cDisplayTimeoutSec")
        suspend = timeout_of(settings, "cSuspendTimeoutSec")
        profile = "charging"
    else:
        lock = timeout_of(settings, "lockTimeoutSec")
        display = timeout_of(settings, "displayTimeoutSec")
        suspend = timeout_of(settings, "suspendTimeoutSec")
        profile = "battery"
    CONF.parent.mkdir(parents=True, exist_ok=True)
    CONF.write_text(render(lock, display, suspend))
    print(f"hypridle: {profile} profile (lock={lock}s display={display}s suspend={suspend}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
