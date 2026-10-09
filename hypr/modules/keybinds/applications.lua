local mod = "SUPER"

hl.bind(
    mod .. " + Return",
    hl.dsp.exec_cmd("kitty")
)

hl.bind(
    mod .. " + slash",
    hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-call shell toggleLauncher")
)

hl.bind(
    mod .. " + L",
    hl.dsp.exec_cmd("~/.config/hypr/hyprlock/scripts/lock.sh")
)

hl.bind(
    mod .. " + Q",
    hl.dsp.window.close()
)
