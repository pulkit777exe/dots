-- modules/keybinds/quickshell.lua
--
-- Quickshell surface toggles — Hyprland `global` dispatcher (zero-fork).
--
-- Source of truth for names: ~/.config/quickshell/modules/Keybinds.qml
--   IpcHandler  : `quickshell ipc call shell <name>`      (any compositor, exec path)
--   GlobalShortcut: `global, quickshell:<name>`           (Hyprland-only, preferred)
--     → in hyprland.lua: hl.dsp.global("quickshell:<name>")
--
-- This file uses `global` (no process spawn, visible in `hyprctl globalshortcuts`).
-- Keep the `exec` fallback in comments if you run on Sway/Mutter.
-- Requires: ~/.config/quickshell/modules/qmldir → `singleton Keybinds 1.0 Keybinds.qml`
--   + shell.qml `property var _keybinds: Keybinds` (or `Keybinds {}` child).
--   After fixing qmldir, `quickshell ipc show` must list `shell`/`uis`,
--   and `hyprctl globalshortcuts` must list `quickshell:*`.
--
-- Key choices avoid existing binds in applications.lua/navigation.lua/
-- window.lua/mouse.lua/resize.lua/workspaces.lua/screenshots.lua:
--   - L is `hyprlock` in applications.lua → power menu on SUPER+SHIFT+L
--

local mod = "SUPER"

-- helper: bind SUPER+<key> → global quickshell:<name>
local function qs_global(key, name, opts)
    hl.bind(
        mod .. " + " .. key,
        hl.dsp.global("quickshell:" .. name),
        opts
    )
end

-- Surfaces — must match Keybinds.qml GlobalShortcut names 1:1
-- Super alone for easier access (tap Super) — release so SUPER+D etc still work
hl.bind("Super_L", hl.dsp.global("quickshell:toggleLauncher"), { release = true })
hl.bind("Super_R", hl.dsp.global("quickshell:toggleLauncher"), { release = true })
qs_global("D", "toggleLauncher")        -- launcher (Command Palette) — kept as alternative
qs_global("N", "toggleControlCenter")   -- control center
qs_global("S", "toggleSettings")        -- settings app
qs_global("T", "toggleThemePicker")     -- theme picker (Island morph)
qs_global("W", "toggleWallpaperPicker") -- wallpaper picker
qs_global("C", "toggleClipboard")       -- clipboard manager (cliphist)
-- SUPER+M and SUPER+SHIFT+C used to reach the media card and calendar;
-- both surfaces are still gone from the shell, so those binds stay
-- removed rather than left to fire at names nothing registers.

-- Power menu — SHIFT+L (plain L is lock)
hl.bind(
    mod .. " + SHIFT + L",
    hl.dsp.global("quickshell:togglePowerMenu")
)

-- Close all overlays — ESCAPE (matches README's `SUPER+ESCAPE → closeAll`)
hl.bind(
    mod .. " + ESCAPE",
    hl.dsp.global("quickshell:closeAll")
)

-- ── Optional hardware/media globals (uncomment if you want quickshell's
-- -- OSD/Bluetooth/NightLight handlers instead of the raw wpctl/brightnessctl
-- -- /playerctl commands in media.lua). These 9 have IpcHandler aliases too,
-- -- but are normally reachable only via `global`:
--
-- hl.bind("XF86MonBrightnessUp",   hl.dsp.global("quickshell:brightnessUp"),   { locked = true })
-- hl.bind("XF86MonBrightnessDown", hl.dsp.global("quickshell:brightnessDown"), { locked = true })
-- hl.bind("XF86AudioPlay",         hl.dsp.global("quickshell:mediaToggle"),    { locked = true })
-- hl.bind("XF86AudioPrev",         hl.dsp.global("quickshell:mediaPrev"),      { locked = true })
-- hl.bind("XF86AudioNext",         hl.dsp.global("quickshell:mediaNext"),      { locked = true })
-- hl.bind("XF86AudioStop",         hl.dsp.global("quickshell:mediaStop"),      { locked = true })
-- hl.bind(mod .. " + B",           hl.dsp.global("quickshell:bluetoothToggle"))
-- hl.bind(mod .. " + SHIFT + N",   hl.dsp.global("quickshell:nightLightToggle"))
-- hl.bind(mod .. " + SHIFT + C",   hl.dsp.global("quickshell:clearNotifs"))

-- ── Fallback exec path (portable, any compositor) — keep for reference:
-- -- local function qs_exec(key, fn) hl.bind(mod.." + "..key, hl.dsp.exec_cmd("quickshell ipc call shell "..fn)) end
-- -- qs_exec("D","toggleLauncher") etc. — works after qmldir fix, but spawns `quickshell` per press.
