-- ~/.config/hypr/hyprland.lua
--
-- Main Hyprland configuration.

-- Session / environment
require("modules.environment")

-- Session startup — Quickshell, cliphist watcher, polkit, wallpaper daemon.
-- Was never required anywhere in this config before this line: none of
-- it was actually starting automatically. See modules/startup.lua's own
-- header comment for what depends on what and why the order matters.
require("modules.startup")

-- Idle lifecycle (dim -> lock -> display off -> suspend). Also never required
-- before, so hypridle was not started and its TOML was never written. Loaded
-- defensively with an absolute path, like openwhispr below, so a missing file
-- cannot take the rest of the config down with it.
pcall(require, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/hypridle.lua")

-- Hardware
require("modules.monitors")
require("modules.input")

-- Compositor behavior
require("modules.general")
require("modules.layout")
require("modules.decoration")
require("modules.animations")

-- Workspace / window behavior
require("modules.workspaces")
require("modules.rules")

-- Keyboard / mouse
require("modules.keybinds.applications")
require("modules.keybinds.navigation")
require("modules.keybinds.resize")
require("modules.keybinds.mouse")
require("modules.keybinds.window")
require("modules.keybinds.workspaces")
require("modules.keybinds.screenshots")
require("modules.keybinds.media")
require("modules.keybinds.quickshell")
-- OpenWhispr (voice dictation) binds. Optional and app-specific: this
-- file only exists once OpenWhispr is installed, so load it defensively
-- and never let a missing file break the rest of the config. Resolved
-- relative to this config so it works for any username/machine.
pcall(require, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/openwhispr-binds.lua")