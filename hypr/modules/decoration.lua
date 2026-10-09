-- modules/decoration.lua
--
-- Window appearance.

-- The inner window glow is tinted with the active theme's accent, so
-- focus reads as a soft halo of light rather than the stock near-black
-- vignette. The accent is parsed out of the generated
-- colors/hyprland.conf (the same file general.lua seeds borders from),
-- so a theme switch + reload retints the glow along with everything
-- else. Before any theme has been published the colour stays nil and
-- Hyprland's default applies.
local function read_theme_accent()
    local home = os.getenv("HOME")
    local f = io.open(home .. "/.config/colors/hyprland.conf", "r")
    if not f then
        return nil
    end

    local contents = f:read("*a")
    f:close()

    local accent = contents:match("%$accent%s*=%s*rgb%(([0-9a-fA-F]+)%)")
    if not accent then
        return nil
    end

    -- 0x33 is ~20% alpha: subtle, a hint of the accent rather than a
    -- neon edge.
    return "rgba(" .. accent .. "33)"
end

hl.config({
    decoration = {
        rounding = 10,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 1.0,

        dim_inactive = true,
        dim_strength = 0.25,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },

        glow = {
            enabled = true,
            range = 10,
            render_power = 3,
            color = read_theme_accent(),
        },

        blur = {
            enabled = true,
            size = 7,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
})
