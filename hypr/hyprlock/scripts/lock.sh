#!/bin/sh
# Lock the session, then scrub Hyprland's "crashed lockscreen" fallback.
#
# On the Hyprland builds this repo targets, hyprlock leaving the session
# lock -- successful password, crash, or kill -- is treated as a dead lock
# client, so the "Oopsie daisy" screen stays up over an otherwise usable
# session. Clearing it right after the lock client exits is the only
# reliable fix; the retries cover the beat between the client vanishing
# and the compositor flagging it.
#
# Version tolerance, not a version gate: the scrub is best-effort (any
# failure is swallowed) and hyprlock's own exit status is preserved, so on
# a build that no longer needs the workaround this degrades to four wasted
# hyprctl calls. If a future Hyprland removes the eval below, the grep
# simply never matches and nothing breaks.

hyprlock "$@"
rc=$?

tries=0
while [ "$tries" -lt 4 ]; do
    hyprctl eval 'hl.clear_crashed_lockscreen()' 2>/dev/null | grep -q '^ok' && break
    tries=$((tries + 1))
    sleep 0.3
done

exit "$rc"
