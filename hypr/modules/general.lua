-- modules/general.lua
--
-- Core compositor behavior.

-- Border colours follow the generated palette. The live path
-- (quickshell/scripts/publish-colors.py's apply_live()) reloads
-- Hyprland the instant a palette is pushed — but that only reaches an
-- already-running session. On a fresh login/reboot, before any push
-- happens this session, we still want the last published colours, not
-- Hyprland's built-in default. So read the same generated
-- colors/hyprland.conf every other consumer reads from and seed the
-- config with it; live reloads take over from there.
local function read_border_colors()
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

local paletteBorders = read_border_colors()

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
        -- palette has ever been published on this machine).
        ["col.active_border"] = paletteBorders and paletteBorders.active or nil,
        ["col.inactive_border"] = paletteBorders and paletteBorders.inactive or nil,
    },
})