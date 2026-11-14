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

local conf_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
for _, m in ipairs({
    "modules.environment", "modules.startup",
    "modules.monitors", "modules.input",
    "modules.colours", "modules.general", "modules.layout", "modules.decoration",
    "modules.animations", "modules.workspaces", "modules.rules",
    "modules.keybinds.applications", "modules.keybinds.navigation", "modules.keybinds.resize",
    "modules.keybinds.mouse", "modules.keybinds.window", "modules.keybinds.workspaces",
    "modules.keybinds.screenshots", "modules.keybinds.media", "modules.keybinds.quickshell",
}) do require(m) end

local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
try_require(state_home .. "/quickshell/hypr.lua")

local plugin = os.getenv("HOME") .. "/.local/lib/hyprglass/hyprglass.so"
hl.on("hyprland.start", function()
    local f = io.open(plugin, "r")
    if f then
        f:close()
        hl.exec_cmd("hyprctl plugin load " .. plugin .. " >/dev/null 2>&1 || true")
    end
end)

try_require(conf_home .. "/hypr/hyprlock.lua")

try_require(conf_home .. "/hypr/openwhispr-binds.lua")
