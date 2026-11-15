#!/usr/bin/env bash
# Capability/provider helpers and alternative mappings for Fedora.

# shellcheck shell=bash

# Format: "capability|preferred_package|alt_cmd1,alt_cmd2|note"
DOTS_CAPABILITY_MAP=(
  "grimblast|grimblast|grimblast|Screenshot helper (package preferred, upstream script fallback)"
  "polkit-agent|hyprpolkitagent|hyprpolkitagent,/usr/libexec/hyprpolkitagent,/usr/lib/polkit-kde-authentication-agent-1|Session polkit authentication agent"
  "terminal|kitty|kitty,alacritty,foot,wezterm|Terminal emulator"
  "audio-user-session|pipewire|pipewire|PipeWire user audio stack (socket/service units may vary)"
)

capability_has_cmd() {
    local cmd
    IFS=',' read -r -a cmds <<<"${1:-}"
    for cmd in "${cmds[@]}"; do
        [ -z "$cmd" ] && continue
        if command -v "$cmd" >/dev/null 2>&1 || [ -x "$cmd" ]; then
            return 0
        fi
    done
    return 1
}

capability_pkg_installed() {
    rpm -q "$1" >/dev/null 2>&1
}

capability_status() {
    local cap="${1:?capability required}" row c pkg alts note
    for row in "${DOTS_CAPABILITY_MAP[@]}"; do
        IFS='|' read -r c pkg alts note <<<"$row"
        [ "$c" = "$cap" ] || continue
        if capability_pkg_installed "$pkg" || capability_has_cmd "$alts"; then
            printf 'ok\t%s\t%s\n' "$cap" "${note:-}"
            return 0
        fi
        printf 'missing\t%s\tprefer:%s alts:%s %s\n' "$cap" "$pkg" "$alts" "${note:-}"
        return 1
    done
    printf 'unknown\t%s\tno mapping\n' "$cap"
    return 2
}

print_capability_report() {
    local row c pkg alts note state rest
    log "capability/provider checks"
    for row in "${DOTS_CAPABILITY_MAP[@]}"; do
        IFS='|' read -r c pkg alts note <<<"$row"
        if state="$(capability_status "$c")"; then
            IFS=$'\t' read -r state c rest <<<"$state"
            log "capability ok: $c"
        else
            IFS=$'\t' read -r state c rest <<<"$(capability_status "$c" || true)"
            warn "capability missing: $c ($rest)"
        fi
    done
}
