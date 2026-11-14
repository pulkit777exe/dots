local home = os.getenv("HOME")
local conf_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local qs = conf_home .. "/quickshell"

hl.on("hyprland.start", function()
    -- Render runtime state generated from the settings store before daemons
    -- and the shell read it.
    hl.exec_cmd("python3 " .. qs .. "/scripts/generate-hypridle-conf.py")
    hl.exec_cmd("python3 " .. qs .. "/scripts/generate-hypr-conf.py")

    for _, d in ipairs({ "hypridle", "hyprpaper", "hyprsunset" }) do
        hl.exec_cmd("command -v " .. d .. " >/dev/null && systemctl --user enable --now " .. d .. ".service || true")
    end

    -- hyprland.start re-fires on `hyprctl reload`, so long-lived
    -- children guard on their own name first ([c]lass: pgrep never
    -- matches its own command line).
    hl.exec_cmd("pgrep -x wl-paste >/dev/null || wl-paste --watch cliphist store")

    -- Secrets: one keyring daemon for the session, so apps never
    -- D-Bus-activate a second, locked one behind our back.
    hl.exec_cmd("eval $(gnome-keyring-daemon --start --components=secrets,ssh 2>/dev/null) 2>/dev/null; dbus-update-activation-environment --systemd GNOME_KEYRING_CONTROL SSH_AUTH_SOCK 2>/dev/null || true")

    -- Polkit agent for password prompts.
    hl.exec_cmd("pgrep -f '[p]olkit-agent.py' >/dev/null || python3 " .. qs .. "/scripts/polkit-agent.py &")

    -- One shell instance per config path.
    hl.exec_cmd("pgrep -f 'quickshell.*" .. qs:gsub("%-", "%%-") .. "' >/dev/null || quickshell -p " .. qs .. " &")
end)
