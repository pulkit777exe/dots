pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
PowerManager -- lid and suspend state. Logic only, zero visual children: a
service never contains pixels.

CONTRACT
--------
Values below come from one read-only spawn of scripts/power-state.py, which
prints a single JSON object. Every property is populated on construction with a
value inside its own documented vocabulary, so the pane can bind on the first
frame and never has to render `undefined`.

  suspendState             "idle" before the first refresh, then "ready" |
                           "unavailable" | "error". "idle" means nobody has
                           asked yet, which is the service's own steady state
                           when no pane is open -- it spawns nothing unprompted.
  suspendDetail            one human line, always non-empty.
  suspendCapabilityClass   "read-only". This reads logind's answer to a question
                           and never suspends anything itself.

  lidState                 "unknown" before the first refresh, then
                           "available" | "absent" | "unknown" | "error".
  lidPosition              "unknown" before the first refresh, then "open" |
                           "closed" | "unknown".
  lidCapabilityClass       "read-only".
  lidDetail                one human line, always non-empty.

  lidPolicyState           "idle" before the first refresh, then "ready" |
                           "error". Shares suspendState's vocabulary on purpose:
                           both answer "have we read this yet, and did it work".
  lidPolicy                HandleLidSwitch (the on-battery condition).
  lidExternalPowerPolicy   HandleLidSwitchExternalPower.
  lidDockedPolicy          HandleLidSwitchDocked.
                           All three render logind's empty string as
                           "logind default", never as an empty label: "" is
                           logind saying it has no override configured here, and
                           a blank row reads as a bug in the pane.
  lidPolicyCapabilityClass "privileged". The one load-bearing choice in this
                           file; see WHY PRIVILEGED below.
  lidPolicyDetail          one human line naming the only write route there is.

  lidActions               the 11 actions logind accepts, declared ONCE here.
                           The UI builds its selectors from this list; nothing
                           else in the tree may spell these strings out again.
  validLidAction(value)    membership test against lidActions, not a second
                           hand-written list of string literals.

Error states
------------
power-state.py has exactly one error channel: `error` is null, or it is a
string describing what could not be read. A non-null error means the other keys
in that object are the script's DEFAULTS, not readings -- so any error sets the
three *State properties to "error" and lidPosition to "unknown", rather than
letting a defaulted `lidClosed: false` be reported to the user as a lid that is
open. That single channel is the script's whole contract; per-field success
flags would be a second contract, and nothing here would read them.

On an error the three policy strings keep their last successfully read values
instead of being blanked. A stale "suspend" next to an error line is useful; an
empty row next to an error line is indistinguishable from the bug above.

THIS MACHINE AND lidState
------------------------
logind reports LidClosed but exposes no presence flag, and UPower's
org.freedesktop.UPower.Device exposes no Lid* property at all here -- checked
across every device object `upower -e` enumerates, not just the first. Absence
of both is not proof of a machine without a lid, because some firmware surfaces
the switch only as a key event. So "absent" is not emitted from a guess: it
requires the script to have found a real source, and the script only reports
"yes"/"unknown". On this machine it finds the ACPI lid button under
/proc/acpi/button/lid and an evdev "Lid Switch", so "available" is a
measurement. lidPosition is believed only when lidState is "available",
precisely because LidClosed === false is also what an open lid reports.

WHY lidPolicyCapabilityClass IS "privileged" AND THERE IS NO SETTER
------------------------------------------------------------------
logind exposes HandleLidSwitch, HandleLidSwitchExternalPower and
HandleLidSwitchDocked as const, and offers no setter for them. The only Set*
methods on org.freedesktop.login1.Manager are SetRebootParameter,
SetRebootToBootLoaderEntry, SetRebootToBootLoaderMenu,
SetRebootToBootLoaderFirmwareSetup, SetUserLinger and SetWallMessage. There is
no D-Bus write path at all; the only route is root-owned --
`systemctl set-property org.freedesktop.login1-handle-lid-switch <action>`,
which lands as a drop-in under /etc/systemd/logind.conf.d/. Verified here: that
unit is currently LoadState=not-found, which is consistent with
HandleLidSwitchExternalPower reading as the empty string.

"privileged" is therefore the honest answer, and "read-only" would be a lie by
omission: this pane may DESCRIBE the policy but cannot SET it unprivileged, and a
capability class that said otherwise is what would let a caller build a control
that cannot work.

So there is deliberately no setter function here either. A write path that could
only ever succeed through pkexec, owned by a root agent that does not exist,
would be an abstraction for a hypothetical future -- and this file is the place
where that temptation is strongest, because every other property on it is a
perfectly ordinary bindable. `lidActions` exists so the UI can build its
selectors and show the user what logind would accept, not so it can send it.
*/

Singleton {
    id: root

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/power-state.py"

    // ---- suspend -----------------------------------------------------
    property string suspendState: "idle"
    property string suspendDetail: "Not read yet."
    readonly property string suspendCapabilityClass: "read-only"

    // ---- lid sensor --------------------------------------------------
    property string lidState: "unknown"
    property string lidPosition: "unknown"
    readonly property string lidCapabilityClass: "read-only"
    property string lidDetail: "Not read yet."

    // ---- lid policy --------------------------------------------------
    property string lidPolicyState: "idle"
    property string lidPolicy: ""
    property string lidExternalPowerPolicy: ""
    property string lidDockedPolicy: ""
    readonly property string lidPolicyCapabilityClass: "privileged"
    readonly property string lidPolicyDetail:
        "logind exposes no setter for this: the HandleLidSwitch properties are const, and the only "
        + "Set* methods on org.freedesktop.login1.Manager are reboot, bootloader, linger and wall "
        + "message. Changing the lid policy needs root -- `systemctl set-property "
        + "org.freedesktop.login1-handle-lid-switch <action>`, which lands as a drop-in in "
        + "/etc/systemd/logind.conf.d/. This shell only reports it."

    // ---- the lid action vocabulary -----------------------------------
    // The single declaration site for these 11 strings. `validLidAction` reads
    // this list rather than repeating the literals, so a list that gains or
    // loses an entry cannot disagree with the test that validates against it.
    readonly property var lidActions: [
        "ignore",
        "suspend",
        "hibernate",
        "hybrid-sleep",
        "suspend-then-hibernate",
        "lock",
        "poweroff",
        "reboot",
        "halt",
        "kexec",
        "default"
    ]

    function validLidAction(value): bool {
        return root.lidActions.indexOf(value) !== -1;
    }

    // ---- refreshing ---------------------------------------------------

    // Set by the settings pane while it is on screen. Nothing is spawned until
    // something asks, which is why there is no Component.onCompleted refresh:
    // a service whose subject is "settings about power" has no reason to spend a
    // process on every shell start.
    property bool watching: false

    // Why a Timer and not a permanent `busctl monitor`.
    //
    // A monitor is a Process that never exits, which is exactly the shape
    // recovery.sh exists to clean up: `powerprofilesctl monitor` and
    // `nmcli monitor` outlived the shell, got reparented to init, and had to be
    // added to a hand-maintained reap list. None of these values is worth that.
    // The lid policy changes only when someone edits a root-owned drop-in, and
    // LidClosed changes when a human picks the laptop up -- both of which happen
    // while somebody is looking at the pane, which is the only time any of this
    // is on screen. So the timer is gated on `watching`, and with the pane
    // closed there is no process and no bus traffic at all.
    //
    // The stop path is the `running` binding itself: the pane sets watching
    // false on close and the timer stops, with no separate teardown step to
    // forget. Watching for the pane to reopen triggers an immediate refresh,
    // because a repeating timer does not fire on the tick that started it.
    property int refreshIntervalMs: 4000

    onWatchingChanged: if (watching) refresh();

    // Dropped rather than queued if a refresh is already in flight. `probe`
    // takes ~100ms (measured: six busctl round trips); without this a fast
    // watcher and a slow bus would stack copies of the same one-shot process,
    // which is the accumulation recovery.sh was written for.
    function refresh() {
        if (probe.running) return;
        probe.running = true;
    }

    Timer {
        id: poller
        interval: root.refreshIntervalMs
        repeat: true
        running: root.watching
        onTriggered: root.refresh()
    }

    // One-shot: the script prints its object and exits. This is deliberately
    // NOT in recovery.sh's reap list, and that is the correct entry rather than
    // an omission. That list exists for processes that OUTLIVE the shell --
    // watchers reparented to init that go on holding a watch. This one exits
    // within milliseconds of every launch by construction and cannot pile up,
    // and adding it would repeat the exact drift that list has already suffered
    // once, when it named a `bluetoothctl monitor` the service never spawned.
    //
    // `python3` is named explicitly rather than relying on the script's own
    // shebang or its exec bit, matching how Theme.qml runs list-themes.py.
    Process {
        id: probe
        command: ["python3", root.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyState(JSON.parse(text));
                } catch (e) {
                    root.fail("could not parse the state script's output");
                    console.warn("PowerManager: unparseable power-state.py output:", e, text.slice(0, 200));
                }
            }
        }
        onExited: (code) => {
            // The script exits 0 whenever it printed an object, including one
            // describing a failure, so a non-zero status means it never printed
            // anything at all. Report it once; the parse handler above has
            // already failed the state if that is what happened.
            if (code !== 0) {
                root.fail("the state script exited " + code);
                console.warn("PowerManager: power-state.py exited", code);
            }
        }
    }

    // ---- mapping ------------------------------------------------------

    function applyState(data) {
        if (!data || typeof data !== "object") {
            fail("the state script did not return an object");
            return;
        }
        if (data.error !== null && data.error !== undefined && data.error !== "") {
            fail(String(data.error));
            return;
        }
        applySuspend(data.canSuspend);
        applyLid(data.lidPresent, data.lidClosed);
        applyPolicy(data);
    }

    function applySuspend(raw) {
        const answer = String(raw ?? "");
        if (answer === "yes") {
            suspendState = "ready";
            suspendDetail = "This machine can suspend.";
            return;
        }
        // "na" is no hardware support; "no" and "challenge" are real logind
        // answers too, and neither means it can, so all of them land here. The
        // raw value is kept because "no" (something stands in the way) and
        // "challenge" (authentication is required) are different problems for
        // whoever is reading the pane.
        suspendState = "unavailable";
        suspendDetail = answer
            ? "This machine cannot suspend right now (logind reports " + answer + ")."
            : "This machine cannot suspend right now.";
    }

    function applyLid(lidPresent, lidClosed) {
        if (lidPresent === "yes") {
            lidState = "available";
            lidDetail = "A lid switch is present.";
        } else if (lidPresent === "no") {
            lidState = "absent";
            lidDetail = "No lid switch on this machine.";
        } else {
            // Not a failure: the script found no source that can prove presence,
            // and guessed nothing. Saying so is the honest answer.
            lidState = "unknown";
            lidDetail = "No lid-presence source on this machine. The lid reports open when "
                + "there is no lid at all, so presence is left unclaimed.";
        }

        // Believed only once presence is established. Otherwise `false` is
        // indistinguishable from "no lid exists", and reporting "open" would be
        // a claim this machine never made.
        lidPosition = lidState === "available" ? (lidClosed ? "closed" : "open") : "unknown";
    }

    function applyPolicy(data) {
        lidPolicy = policyLabel(data.handleLidSwitch);
        lidExternalPowerPolicy = policyLabel(data.handleLidSwitchExternalPower);
        lidDockedPolicy = policyLabel(data.handleLidSwitchDocked);
        lidPolicyState = "ready";
    }

    function policyLabel(raw) {
        // One implementation for all three conditions, because "" means the same
        // thing in each of them and an empty label is never the right rendering.
        const value = String(raw ?? "");
        return value === "" ? "logind default" : value;
    }

    function fail(message) {
        suspendState = "error";
        suspendDetail = "Could not read suspend state: " + message;
        lidState = "error";
        lidDetail = "Could not read lid state: " + message;
        lidPolicyState = "error";
        // Not touched: the last successfully read policy values stay, because a
        // stale value beside an error line is information and a blank one is
        // indistinguishable from the false "open" this branch exists to avoid.
        lidPosition = "unknown";
    }
}
