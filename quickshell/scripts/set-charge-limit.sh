#!/usr/bin/env bash
# set-charge-limit.sh PCT — write the battery charge_control_end_threshold.
# Runs as root via pkexec (the sysfs node is root-writable). Validates hard:
# pkexec runs this with privilege, so it must not trust its argument.
set -euo pipefail

v="${1:-}"
if ! [[ "$v" =~ ^[0-9]+$ ]] || [ "$v" -lt 40 ] || [ "$v" -gt 100 ]; then
    echo "set-charge-limit: want an integer 40-100, got '$v'" >&2
    exit 2
fi

node="$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1)"
if [ -z "$node" ]; then
    echo "set-charge-limit: no charge-control node on this machine" >&2
    exit 3
fi

echo "$v" > "$node"
echo "charge limit set to $v ($(basename "$(dirname "$node")"))"
