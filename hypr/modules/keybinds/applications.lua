local mod = "SUPER"

local apps = {
    { "Return", hl.dsp.exec_cmd("kitty") },
    { "slash", hl.dsp.global("quickshell:toggleLauncher") },
    { "L", hl.dsp.exec_cmd("~/.config/hypr/hyprlock/scripts/lock.sh") },
    { "Q", hl.dsp.window.close() },
}

for _, a in ipairs(apps) do
    hl.bind(mod .. " + " .. a[1], a[2])
end
