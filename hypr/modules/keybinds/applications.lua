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
hl.bind(
    mod .. " + slash",
    hl.dsp.exec_cmd("quickshell ipc call shell toggleLauncher")
)

-- Lock
hl.bind(
    mod .. " + L",
    hl.dsp.exec_cmd("hyprlock")
)

-- Close focused window
hl.bind(
    mod .. " + Q",
    hl.dsp.window.close()
)