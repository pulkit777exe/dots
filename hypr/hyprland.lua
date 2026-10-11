require("modules.environment")
require("modules.startup")

pcall(require, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/hyprlock.lua")

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

pcall(require, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/openwhispr-binds.lua")
