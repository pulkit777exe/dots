-- hyprpaper.lua
--
-- SUPERSEDED — this file is not required anywhere in hyprland.lua (it
-- never was), and its wallpaper-daemon-start + wallpaper-set steps have
-- been merged into modules/startup.lua, which now IS required. Kept
-- here only so the history isn't silently lost; safe to delete once
-- you've confirmed modules/startup.lua covers what you need.

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("sleep 1 && hyprctl hyprpaper wallpaper ,'/home/pulkit/Downloads/everforest/wallhaven-9o8k9w_1920x1080.png'")
end)   