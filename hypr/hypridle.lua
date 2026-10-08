-- hypridle.lua
-- Idle lifecycle: active -> idle -> lock -> display off -> suspend.
--
-- Hypridle is configured through the `hypridle` daemon directly, not via
-- Hyprland's Lua API (no `hl.idle{}` exists). The cleanest way to drive it
-- from a Lua config is to drop hypridle's `hypridle.conf` (hyprlang; hypridle
-- finds it in `~/.config/hypr/`) and start the daemon at session boot.
-- `autostart.lua` already launches Hyprland-managed daemons; this file just
-- writes the conf and registers the start command.
--
-- This module was never required by hyprland.lua, so none of the below ever
-- ran: the daemon was not started and the config was not written. The whole
-- idle chain -- lock, display off, suspend -- was dead. It is now required
-- from hyprland.lua, and the work is scoped to `hyprland.start` so that a
-- `hyprctl reload` neither rewrites the config nor re-checks the daemon.

local home = os.getenv("HOME")
local conf_path = home .. "/.config/hypr/hypridle.conf"

hl.on("hyprland.start", function()
-- 1. Write the hypridle config.
-- The chain mirrors the spec (Idle -> lock -> display off -> suspend):
--   - 120s idle: lock via `hyprlock` (auth owned by the system, not the shell)
--   - 300s idle: turn off displays via DPMS
--   - 600s idle: suspend via logind (kernel-level, logind is the authority)
--
-- The spec's 90s "dim the screen" step is cut, not shipped broken: neither
-- `hyprctl hyprland dispatch dim` nor any dim dispatcher exists -- Hyprland
-- only dims via decoration rules (dim_inactive/dim_special), never globally.
--
-- Commands are the 0.56+ lua form: `hyprctl dispatch` is shorthand for
-- `hyprctl eval 'hl.dispatch(...)'`, so it takes a dispatcher expression,
-- not the retired hyprlang "dispatcher args" spelling.
--
-- `before_sleep_cmd` runs `loginctl lock-session` so unlocking brings us
-- straight back into the lock screen rather than an unlocked session.
--
-- The on-resume dpms listeners keep the daemon from leaving the display off
-- when activity comes back.
local conf = [[

general {
    lock_cmd = pidof hyprlock || ~/.config/hypr/hyprlock/scripts/lock.sh   # don't spawn a second lock; lock.sh scrubs the fallback on exit
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
}

# Display power management — wake/blank on activity
listener {
    timeout = 300
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
}

# Suspend — kernel level via logind
listener {
    timeout = 600
    on-timeout = systemctl suspend
}

# Lock — secure, delegated to hyprlock (system auth, not shell)
listener {
    timeout = 120
    on-timeout = loginctl lock-session
}
]]

local f = assert(io.open(conf_path, "w"))
f:write(conf)
f:close()

-- 2. Ensure hypridle is running. `pgrep -x hypridle` is idempotent — if it's
-- already up we don't spawn a second copy. If it isn't, start it via
-- exec-once style: detach so it survives Hyprland's session restart.
local pid = io.popen("pgrep -x hypridle"):read("*l")
if not pid or pid == "" then
    -- Detach: hypridle runs as its own daemon, not a Hyprland child. We use
    -- `setsid` so it survives Hyprland exit, then `disown` semantics via the
    -- trailing `&` and redirected stdio.
    os.execute("setsid hypridle >/dev/null 2>&1 &")
end
end)
