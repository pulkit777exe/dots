local mod = "SUPER"

local function qs_global(key, name, opts)
    hl.bind(
        mod .. " + " .. key,
        hl.dsp.global("quickshell:" .. name),
        opts
    )
end

hl.bind("Super_L", hl.dsp.global("quickshell:toggleLauncher"), { release = true })
hl.bind("Super_R", hl.dsp.global("quickshell:toggleLauncher"), { release = true })
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
