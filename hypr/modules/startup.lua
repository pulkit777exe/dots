local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- Idle, wallpaper and night-light daemons ship systemd user units
    -- (hypridle/hyprpaper/hyprsunset.service); enable --now is idempotent
    -- and self-healing, unlike the old pgrep/setsid spawns. quickshell has
    -- no unit, so it is still exec'd here. hypridle.conf is a static tracked
    -- file (it has no dynamic parts), read directly by the daemon.
    hl.exec_cmd("systemctl --user enable --now hypridle.service hyprpaper.service")
    hl.exec_cmd("command -v hyprsunset >/dev/null && systemctl --user enable --now hyprsunset.service || true")

    hl.exec_cmd("wl-paste --watch cliphist store")

    hl.exec_cmd("pidof polkitd || /usr/lib/polkit-1/polkitd --no-debug &")

    hl.exec_cmd("quickshell -p " .. home .. "/.config/quickshell")
end)
