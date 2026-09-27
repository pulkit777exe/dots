-- hypridle.lua
-- Idle lifecycle: active -> idle -> dim -> lock -> display off -> suspend.
--
-- Hypridle is configured through the `hypridle` daemon directly, not via
-- Hyprland's Lua API (no `hl.idle{}` exists). The cleanest way to drive it
-- from a Lua config is to drop a TOML file and start the daemon at session
-- boot. `autostart.lua` already launches Hyprland-managed daemons; this
-- file just writes the TOML and registers the start command.
--
-- This module was never required by hyprland.lua, so none of the below ever
-- ran: the daemon was not started and the TOML was not written. The whole
-- idle chain -- dim, lock, display off, suspend -- was dead. It is now
-- required from hyprland.lua, and the work is scoped to `hyprland.start` so
-- that a `hyprctl reload` neither rewrites the TOML nor re-checks the daemon.

local home = os.getenv("HOME")
local toml_path = home .. "/.config/hypr/hypridle.toml"

hl.on("hyprland.start", function()
-- 1. Write the hypridle config.
-- The chain mirrors the spec (Idle -> dim -> lock -> display off -> suspend):
--   - 90s idle: dim via `hyprctl` keyword (compositor dim, not brightness)
--   - 120s idle: lock via `hyprlock` (auth owned by the system, not the shell)
--   - 300s idle: turn off displays via DPMS
--   - 600s idle: suspend via logind (kernel-level, logind is the authority)
--
-- `before_sleep_cmd` runs `loginctl lock-session` so unlocking brings us
-- straight back into the lock screen rather than an unlocked session.
--
-- Listeners on `dpms` keep the daemon from firing screen-off on resume.
local toml = [[
general {
    lock_cmd = pidof hyprlock || hyprlock          # don't spawn a second lock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

# Display power management — wake/blank on activity
listener {
    timeout = 300
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
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

# Dim — compositor-level dim only (do NOT touch brightness, the user is at
# the desk; brightnessctl dimming is destructive and surprising).
listener {
    timeout = 90
    on-timeout = hyprctl hyprland dispatch dim active
    on-resume = hyprctl hyprland dispatch dim 0
}
]]

local f = assert(io.open(toml_path, "w"))
f:write(toml)
f:close()

-- 2. Ensure hypridle is running. `pgrep -x hypridle` is idempotent — if it's
-- already up we don't spawn a second copy. If it isn't, start it via
-- exec-once style: detach so it survives Hyprland's session restart.
local pid = io.popen("pgrep -x hypridle"):read("*l")
if not pid or pid == "" then
    -- Detach: hypridle runs as its own daemon, not a Hyprland child. We use
    -- `setsid` so it survives Hyprland exit, then `disown` semantics via
    -- the trailing `&` and redirected stdio.
    os.execute("setsid hypridle >/dev/null 2>&1 &")
end
end)
