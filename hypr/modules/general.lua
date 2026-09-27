-- modules/general.lua
--
-- Core compositor behavior.

-- Border colors follow whatever theme is currently active. The live
-- path (quickshell/scripts/publish-colors.py's apply_live()) pushes
-- new colors via `hyprctl keyword general:col.active_border ...` the
-- instant a theme is switched — but that only reaches an already-
-- running Hyprland session. On a fresh login/reboot, before any theme
-- switch happens this session, we still want last time's theme, not
-- Hyprland's built-in default. So read the same generated
-- colors/hyprland.conf every other app reads from and seed the config
-- with it; the live keyword updates take over from there.
local function read_theme_border_colors()
    local home = os.getenv("HOME")
    local path = home .. "/.config/colors/hyprland.conf"
    local f = io.open(path, "r")
    if not f then
        return nil
    end

    local contents = f:read("*a")
    f:close()

    local accent = contents:match("%$accent%s*=%s*rgb%(([0-9a-fA-F]+)%)")
    local surface = contents:match("%$surface%s*=%s*rgb%(([0-9a-fA-F]+)%)")

    if not accent or not surface then
        return nil
    end

    return {
        active = "rgba(" .. accent .. "ff)",
        inactive = "rgba(" .. surface .. "aa)",
    }
end

local themeBorders = read_theme_border_colors()

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,

        border_size = 2,

        resize_on_border = false,

        allow_tearing = false,

        layout = "dwindle",

        snap = {
            enabled = true,
        },

        -- Falls back to Hyprland's own default border colors only if
        -- colors/hyprland.conf hasn't been generated yet (i.e. no
        -- theme has ever been applied on this machine).
        ["col.active_border"] = themeBorders and themeBorders.active or nil,
        ["col.inactive_border"] = themeBorders and themeBorders.inactive or nil,
    },
})