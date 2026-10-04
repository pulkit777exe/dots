#!/usr/bin/env python3
"""power-state.py -- this machine's lid and suspend state as one JSON object.

Read-only. Spawned as a one-shot Process by services/PowerManager.qml, which
parses the single object printed below. One script and one object exist so that
one refresh costs the shell one process rather than one per question.

Every key is always present. `error` is null on success and a short string
otherwise, and it is the only signal that a value below is a *default* rather
than a reading -- so a consumer should treat a non-null error as "nothing below
is trustworthy" rather than reading the fields anyway.

Verified on this machine, and the reason for several things below:

  * logind is on the SYSTEM bus. `busctl --user get-property ...` fails with
    "The name is not activatable" for every property, which reads exactly like
    a missing property and is not one. Hence the explicit `--system`.

  * `CanSuspend`/`CanHibernate` are METHODS. `busctl get-property` on them
    fails; they need `busctl call`. A call's JSON payload wraps its out-args in
    a list ("data": ["yes"]) where get-property's is the bare value
    ("data": "suspend"), so the two need different unwrapping.

  * `introspect --json=short` does not emit JSON -- it prints the same text
    table a plain introspect does -- so the per-property `--json=short` form is
    the only one parsed here. Scraping the text form would also mean
    re-implementing `s ""`'s quoting rules by hand.

On lidPresent, specifically:

  `LidClosed === false` is what a laptop with its lid OPEN reports, so it is not
  evidence of a lid-less machine and this script never treats it as such. It
  reports "yes" only from a source that proves a lid switch exists:

    1. /proc/acpi/button/lid/* -- the kernel's acpi-button node, which is
       created only when an ACPI LID device (PNP0C0D) is present.
    2. an evdev input device whose own `name` file mentions a lid.

  Otherwise it reports "unknown", and never "no": no negative source was found
  on this machine, and a lid can be missing from both paths above while still
  existing (some firmware surfaces the switch only as a key event). An honest
  "unknown" beats a confident wrong "no".

  Upower is not a fallback here: org.freedesktop.UPower.Device exposes no Lid*
  property at all on this machine, checked across every device object `upower -e`
  enumerates rather than just the first.

Exit status: 0 whenever a complete object was printed, including when that
object describes a failure. Non-zero only for a usage error.
"""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys

# A hung D-Bus call must not wedge the settings pane that asked for this.
BUS_TIMEOUT_S = 5

LOGIND_SERVICE = "org.freedesktop.login1"
LOGIND_PATH = "/org/freedesktop/login1"
LOGIND_IFACE = "org.freedesktop.login1.Manager"

# JSON key -> logind property. Verbatim, including the empty string: "" is
# logind's own "no override configured here", and normalising it to "default"
# would make an unset policy indistinguishable from one deliberately set to the
# action named "default".
POLICY_PROPERTIES = {
    "handleLidSwitch": "HandleLidSwitch",
    "handleLidSwitchExternalPower": "HandleLidSwitchExternalPower",
    "handleLidSwitchDocked": "HandleLidSwitchDocked",
}

# JSON key -> logind METHOD (not property). See the module docstring.
CAPABILITY_METHODS = {
    "canSuspend": "CanSuspend",
    "canHibernate": "CanHibernate",
}

ACPI_LID_ROOT = pathlib.Path("/proc/acpi/button/lid")
INPUT_ROOT = pathlib.Path("/sys/class/input")


def safe_defaults():
    """The object every path starts from, so no key is ever missing."""
    return {
        "lidClosed": False,
        "lidPresent": "unknown",
        "handleLidSwitch": "",
        "handleLidSwitchExternalPower": "",
        "handleLidSwitchDocked": "",
        # "unknown", not "yes": a default that grants a capability nobody
        # measured is the one default that could put a suspend button on screen
        # which then does not work.
        "canSuspend": "unknown",
        "canHibernate": "unknown",
        "error": None,
    }


def busctl_payload(busctl, verb, member):
    """Run one busctl call and return its parsed JSON. Raises on any failure.

    argv is a list and shell is never involved: these members are fixed
    constants, and there is no shell string for a value to be interpolated
    into. Callers degrade on RuntimeError rather than letting it escape.
    """
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
    # A call's out-args arrive as a list even for a single return value; a
    # get-property's data is the bare value. Verified above, not assumed.
    if isinstance(data, list):
        data = data[0] if data else ""
    if not isinstance(data, str):
        raise RuntimeError(f"{method}: expected a string, got {type(data).__name__}")
    return data


def detect_lid_present():
    """"yes" only when a source can prove a lid switch exists, else "unknown"."""
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

    # Not "no" -- see the module docstring. Absence of both sources is not proof
    # of a machine without a lid.
    return "unknown"


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="power-state.py",
        description="Print this machine's lid and suspend state as one JSON object.",
    )
    # No options exist, so this takes no arguments and rejects any that are
    # given. argparse exits 2 there, which is the only non-zero exit this script
    # has: a failed query is reported in `error`, not by the status, because the
    # status cannot distinguish "logind said no" from "logind is gone" and
    # guessing wrong there would look like success.
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

    # Runs whether or not logind answered. It costs no bus round trip, it does
    # not depend on logind, and when every D-Bus call above has failed this is
    # still the one question on this machine that can still be answered.
    state["lidPresent"] = detect_lid_present()

    state["error"] = "; ".join(problems) if problems else None

    json.dump(state, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
