#!/usr/bin/env python3

import argparse
import json
import pathlib
import shutil
import subprocess
import sys

BUS_TIMEOUT_S = 5

LOGIND_SERVICE = "org.freedesktop.login1"
LOGIND_PATH = "/org/freedesktop/login1"
LOGIND_IFACE = "org.freedesktop.login1.Manager"

POLICY_PROPERTIES = {
    "handleLidSwitch": "HandleLidSwitch",
    "handleLidSwitchExternalPower": "HandleLidSwitchExternalPower",
    "handleLidSwitchDocked": "HandleLidSwitchDocked",
}

CAPABILITY_METHODS = {
    "canSuspend": "CanSuspend",
    "canHibernate": "CanHibernate",
}

ACPI_LID_ROOT = pathlib.Path("/proc/acpi/button/lid")
INPUT_ROOT = pathlib.Path("/sys/class/input")

def safe_defaults():
    return {
        "lidClosed": False,
        "lidPresent": "unknown",
        "handleLidSwitch": "",
        "handleLidSwitchExternalPower": "",
        "handleLidSwitchDocked": "",
        "canSuspend": "unknown",
        "canHibernate": "unknown",
        "error": None,
    }

def busctl_payload(busctl, verb, member):

    argv = [busctl, "--system", "--json=short", verb,
            LOGIND_SERVICE, LOGIND_PATH, LOGIND_IFACE, member]
    try:
        proc = subprocess.run(argv, capture_output=True, text=True,
                              timeout=BUS_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            f"{verb} {member}: timed out after {BUS_TIMEOUT_S}s")
    except OSError as e:
        raise RuntimeError(f"{verb} {member}: {e}")
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip().replace("\n", " ")
        raise RuntimeError(
            f"{verb} {member}: {detail or f'exit {proc.returncode}'}")
    try:
        return json.loads(proc.stdout)
    except ValueError as e:
        raise RuntimeError(f"{verb} {member}: unparseable output ({e})")

def read_string(busctl, prop):
    data = busctl_payload(busctl, "get-property", prop).get("data")
    if not isinstance(data, str):
        raise RuntimeError(f"{prop}: expected a string, got {type(data).__name__}")
    return data

def read_bool(busctl, prop):
    data = busctl_payload(busctl, "get-property", prop).get("data")
    if not isinstance(data, bool):
        raise RuntimeError(f"{prop}: expected a bool, got {type(data).__name__}")
    return data

def call_string(busctl, method):
    data = busctl_payload(busctl, "call", method).get("data")
    if isinstance(data, list):
        data = data[0] if data else ""
    if not isinstance(data, str):
        raise RuntimeError(f"{method}: expected a string, got {type(data).__name__}")
    return data

def detect_lid_present():
    try:
        for entry in sorted(ACPI_LID_ROOT.iterdir()):
            if entry.is_dir():
                return "yes"
    except OSError:
        pass

    try:
        name_files = sorted(INPUT_ROOT.glob("input*/name"))
    except OSError:
        name_files = []
    for name_file in name_files:
        try:
            device_name = name_file.read_text(errors="replace").strip()
        except OSError:
            continue
        if "lid" in device_name.lower():
            return "yes"

    return "unknown"

def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="power-state.py",
        description="Print this machine's lid and suspend state as one JSON object.",
    )
    parser.parse_args(argv)

    state = safe_defaults()
    problems = []

    busctl = shutil.which("busctl")
    if busctl is None:
        problems.append("busctl not found on PATH")
    else:
        try:
            state["lidClosed"] = read_bool(busctl, "LidClosed")
        except RuntimeError as e:
            problems.append(str(e))

        for key, prop in POLICY_PROPERTIES.items():
            try:
                state[key] = read_string(busctl, prop)
            except RuntimeError as e:
                problems.append(str(e))

        for key, method in CAPABILITY_METHODS.items():
            try:
                state[key] = call_string(busctl, method)
            except RuntimeError as e:
                problems.append(str(e))

    state["lidPresent"] = detect_lid_present()

    state["error"] = "; ".join(problems) if problems else None

    json.dump(state, sys.stdout)
    sys.stdout.write("\n")
    return 0

if __name__ == "__main__":
    sys.exit(main())
