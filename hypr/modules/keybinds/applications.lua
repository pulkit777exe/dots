-- modules/keybinds/applications.lua
--
-- Application launching and basic session actions.

local mod = "SUPER"

-- Terminal
hl.bind(
    mod .. " + Return",
    hl.dsp.exec_cmd("kitty")
)

-- Application launcher — Quickshell's own, not rofi. (This used to run
-- `rofi -show drun`; repointed so the "everything goes through
-- Quickshell" goal actually holds for the single most-used launcher
-- keybind, not just the newer modules.keybinds.quickshell additions.)
--
-- qs-call, not `quickshell ipc call`: the latter launches a second Qt
-- process per press, which is 39ms here against qs-call's 16ms for the
-- same call. qs-call falls back to the real client by itself if the
-- socket is not there, so this cannot become a way to lose a keypress.
hl.bind(
    mod .. " + slash",
    hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-call shell toggleLauncher")
)

-- Lock -- lock.sh runs hyprlock, then clears Hyprland's crashed-lockscreen
-- fallback, which otherwise stays up after a successful unlock.
hl.bind(
    mod .. " + L",
    hl.dsp.exec_cmd("~/.config/hypr/hyprlock/scripts/lock.sh")
)

-- Close focused window
hl.bind(
    mod .. " + Q",
    hl.dsp.window.close()
)