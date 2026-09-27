-- modules/startup.lua
-- Autostart: apps that run once per Hyprland session.
--
-- `hl.on("hyprland.start", ...)` fires exactly once per session — not on
-- every `hyprctl reload` — so we don't need duplicate-suppression guards
-- here. Anything in this block survives a config reload but doesn't
-- re-spawn.
--
-- Order matters: hyprpaper before quickshell (so the wallpaper is ready
-- when the shell draws its first frame), cliphist before any app that
-- might want to paste (so the daemon is listening).
--
-- Quickshell startup is here too — it owns the bar, notifications, and
-- every popup surface, so it has to be up before the user sees anything
-- interactively.

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- Wallpaper daemon only. Do NOT hardcode which wallpaper to show
    -- here — that was pointing at a fixed ~/Downloads path belonging
    -- to one specific theme, which breaks on a fresh machine and
    -- ignores whatever theme/wallpaper the user actually had selected.
    -- Quickshell's Theme service (services/Theme.qml) is the single
    -- source of truth for "which wallpaper for which theme"; it reads
    -- colors/index.json + the per-theme wallpaperIndex and calls
    -- `hyprctl hyprpaper preload/wallpaper` itself as soon as it starts
    -- (see onCurrentWallpaperChanged / _applyWallpaper). All this needs
    -- to do is make sure the daemon is up before that happens.
    hl.exec_cmd("hyprpaper")

    -- Clipboard history daemon
    hl.exec_cmd("wl-paste --type text --watch cliphist store")

    -- Night Light / blue-light filter daemon. Optional, so it is started only
    -- when the binary is actually installed. This daemon has to be running
    -- before the toggle can do anything: NightLight.qml drives it with
    -- `hyprctl hyprsunset`, which is a silent no-op if hyprsunset is not up,
    -- and the service has no way to read back whether it is (see the
    -- docstring in services/NightLight.qml). Without this line the moon
    -- button in the control centre looks like it works and does nothing.
    hl.exec_cmd("command -v hyprsunset >/dev/null && hyprsunset &")

    -- Authentication agent: Quickshell owns this via its in-process
    -- PolkitAgent (services/Auth.qml), so no separate agent process.
    -- Just make sure polkit is available.
    hl.exec_cmd("pidof polkitd || /usr/lib/polkit-1/polkitd --no-debug &")

    -- Notification daemon (Quickshell provides one via NotificationServer,
    -- but if you ever want a separate one, drop it in here).

    -- The desktop shell — last, so everything it talks to is up.
    hl.exec_cmd("quickshell -p " .. home .. "/.config/quickshell")
end)
