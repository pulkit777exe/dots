#!/bin/sh
# Lock the session, then scrub Hyprland's "crashed lockscreen" fallback.
#
# On this Hyprland build, hyprlock leaving the session lock -- successful
# password, crash, or kill -- is treated as a dead lock client, so the
# "Oopsie daisy" screen stays up over an otherwise usable session. Clearing
# it right after the lock client exits is the only reliable fix; the retries
# cover the beat between the client vanishing and the compositor flagging it.

hyprlock "$@"

tries=0
while [ "$tries" -lt 4 ]; do
    hyprctl eval 'hl.clear_crashed_lockscreen()' 2>/dev/null | grep -q '^ok' && break
    tries=$((tries + 1))
    sleep 0.3
done
