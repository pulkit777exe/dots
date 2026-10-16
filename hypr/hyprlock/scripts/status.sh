#!/bin/sh
# status.sh battery|wifi — one helper for the lock-screen labels.
case "$1" in
  battery)
    for b in /sys/class/power_supply/BAT*; do
      [ -r "$b/capacity" ] && { printf '%s%%' "$(cat "$b/capacity")"; exit 0; }
    done
    printf 'AC' ;;
  wifi)
    for d in /sys/class/net/*/wireless; do
      d="${d%/wireless}"; [ -d "$d" ] || continue
      [ "$(cat "$d/carrier" 2>/dev/null)" = "1" ] && { printf '󰖩'; exit 0; }
    done
    printf '󰖪' ;;
  *) echo "usage: $0 battery|wifi" >&2; exit 2 ;;
esac
