#!/bin/sh
# Wifi glyph for the lock screen (nerd font). Carrier is 1 only while
# the interface is actually linked to an access point, so this reads
# "connected" rather than merely "wifi is on". Picks the first wireless
# interface instead of assuming a name (wlo1/wlan0/wlp…s0 all occur).
iface=""
for d in /sys/class/net/*/wireless; do
    d="${d%/wireless}"
    [ -d "$d" ] || continue
    iface="$(basename "$d")"
    break
done
if [ -n "$iface" ] && [ "$(cat "/sys/class/net/$iface/carrier" 2>/dev/null)" = "1" ]; then
    printf '󰖩'
else
    printf '󰖪'
fi
