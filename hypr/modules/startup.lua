local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")

    hl.exec_cmd("wl-paste --watch cliphist store")

    hl.exec_cmd("command -v hyprsunset >/dev/null && hyprsunset &")

    hl.exec_cmd("pidof polkitd || /usr/lib/polkit-1/polkitd --no-debug &")

    hl.exec_cmd("quickshell -p " .. home .. "/.config/quickshell")
end)
