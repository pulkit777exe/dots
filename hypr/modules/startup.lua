local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- Idle, wallpaper and night-light daemons ship systemd user units
    -- (hypridle/hyprpaper/hyprsunset.service); enable --now is idempotent
    -- and self-healing, unlike the old pgrep/setsid spawns. quickshell has
    -- no unit, so it is still exec'd here. hypridle.conf is rendered from
    -- the settings store first (it is ignored runtime state, see the
    -- .example template), so user timeouts apply from the first start.
    hl.exec_cmd("python3 " .. home .. "/.config/quickshell/scripts/generate-hypridle-conf.py")
    hl.exec_cmd("systemctl --user enable --now hypridle.service hyprpaper.service")
    hl.exec_cmd("command -v hyprsunset >/dev/null && systemctl --user enable --now hyprsunset.service || true")

    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Secrets: one keyring daemon for the session, so apps never
    -- D-Bus-activate a second, locked one behind our back. Unlock itself
    -- still comes from PAM (see setup.sh ensure_pam_keyring) plus a Login
    -- keyring whose password matches the login password; without that pair
    -- Brave keeps asking every boot. The eval captures the daemon's env
    -- for the activation bus; `|| true` keeps a missing daemon non-fatal.
    hl.exec_cmd("eval $(gnome-keyring-daemon --start --components=secrets,ssh 2>/dev/null) 2>/dev/null; dbus-update-activation-environment --systemd GNOME_KEYRING_CONTROL SSH_AUTH_SOCK 2>/dev/null || true")

    -- Polkit: polkitd is the system authority (already started by
    -- systemd) — what a desktop session needs is an *agent* to ask for
    -- the password. Ours speaks the protocol (scripts/polkit-agent.py)
    -- and shows the island dialog; hyprpolkitagent stays installed as a
    -- manual fallback but never autostarts (two agents race).
    hl.exec_cmd("python3 " .. home .. "/.config/quickshell/scripts/polkit-agent.py &")

    hl.exec_cmd("quickshell -p " .. home .. "/.config/quickshell")
end)
