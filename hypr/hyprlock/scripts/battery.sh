#!/bin/sh
# Battery percent for the lock screen pill. Prints "AC" on machines
# without a battery so the label still resolves instead of erroring.
for b in /sys/class/power_supply/BAT*; do
    if [ -r "$b/capacity" ]; then
        printf '%s%%' "$(cat "$b/capacity")"
        exit 0
    fi
done
printf 'AC'
