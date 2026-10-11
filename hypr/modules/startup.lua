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

    -- Polkit: polkitd is the system authority (already started by
    -- systemd) — what a desktop session needs is an *agent* to ask for
    -- the password, which is hyprpolkitagent. Never launch polkitd here.
    hl.exec_cmd("command -v hyprpolkitagent >/dev/null && hyprpolkitagent &")

    hl.exec_cmd("quickshell -p " .. home .. "/.config/quickshell")
end)
