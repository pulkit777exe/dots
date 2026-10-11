-- Loud require: a bare pcall(require, ...) discards the error, so a typo
-- silently drops lock/keybinds with nothing saying why. Failures append to
-- ~/.local/state/hypr/config-errors.log (outside the repo, so it never
-- dirties the checkout) and raise a notification when notify-send exists.
local function try_require(path)
    local ok, err = pcall(require, path)
    if ok then return end
    local logdir = os.getenv("HOME") .. "/.local/state/hypr"
    os.execute("mkdir -p '" .. logdir .. "'")
    local f = io.open(logdir .. "/config-errors.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " require failed: " .. path .. ": " .. tostring(err) .. "\n")
        f:close()
    end
    hl.exec_cmd("command -v notify-send >/dev/null && notify-send -u critical 'Hyprland config' 'Failed to load " .. path .. " (see ~/.local/state/hypr/config-errors.log)' &")
end

require("modules.environment")
require("modules.startup")

try_require((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/hyprlock.lua")

require("modules.monitors")
require("modules.input")

require("modules.colours")
require("modules.general")
require("modules.layout")
require("modules.decoration")
require("modules.animations")

require("modules.workspaces")
require("modules.rules")

require("modules.keybinds.applications")
require("modules.keybinds.navigation")
require("modules.keybinds.resize")
require("modules.keybinds.mouse")
require("modules.keybinds.window")
require("modules.keybinds.workspaces")
require("modules.keybinds.screenshots")
require("modules.keybinds.media")
require("modules.keybinds.quickshell")

try_require((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/openwhispr-binds.lua")
