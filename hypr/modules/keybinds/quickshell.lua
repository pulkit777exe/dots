local mod = "SUPER"

local function qs_global(key, name, opts)
    hl.bind(
        mod .. " + " .. key,
        hl.dsp.global("quickshell:" .. name),
        opts
    )
end

for _, k in ipairs({ "Super_L", "Super_R" }) do
    hl.bind(k, hl.dsp.global("quickshell:toggleLauncher"), { release = true })
end
qs_global("D", "toggleLauncher")
qs_global("N", "toggleControlCenter")
qs_global("S", "toggleSettings")
qs_global("T", "toggleThemePicker")
qs_global("W", "toggleWallpaperPicker")
qs_global("C", "toggleClipboard")

hl.bind(
    mod .. " + SHIFT + L",
    hl.dsp.global("quickshell:togglePowerMenu")
)

hl.bind(
    mod .. " + ESCAPE",
    hl.dsp.global("quickshell:closeAll")
)

-- Reload is a direct exec, not a global shortcut: it restarts the shell,
-- so it must keep working when the shell is wedged or mid-restart and no
-- GlobalShortcut can fire. Deliberately has no twin in Keybinds.qml.
hl.bind(
    mod .. " + R",
    hl.dsp.exec_cmd("~/.config/quickshell/scripts/recovery.sh reload")
)
