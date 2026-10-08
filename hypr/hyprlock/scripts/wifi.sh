#!/bin/sh
# Wifi glyph for the lock screen (nerd font). Carrier is 1 only while
# the interface is actually linked to an access point, so this reads
# "connected" rather than merely "wifi is on".
if [ "$(cat /sys/class/net/wlo1/carrier 2>/dev/null)" = "1" ]; then
    printf '󰖩'
else
    printf '󰖪'
fi
