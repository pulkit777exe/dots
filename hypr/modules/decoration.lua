-- modules/decoration.lua
--
-- Window appearance.

-- Colours come from the generated palette (colors/hyprland.conf,
-- seeded by publish-colors.py): the glow is the accent at ~20% alpha,
-- a subtle halo rather than a neon edge, and the shadow the background
-- at ~93%. Only the alphas are literal; before any palette is
-- published both stay nil and Hyprland's defaults apply.
local function read_colours()
    local home = os.getenv("HOME")
    local f = io.open(home .. "/.config/colors/hyprland.conf", "r")
    if not f then
        return nil, nil
    end

    local contents = f:read("*a")
    f:close()

    local accent = contents:match("%$accent%s*=%s*rgb%(([0-9a-fA-F]+)%)")
    local background = contents:match("%$bg%s*=%s*rgb%(([0-9a-fA-F]+)%)")

    local glow = accent and ("rgba(" .. accent .. "33)") or nil
    local shadow = background and ("rgba(" .. background .. "ee)") or nil
    return glow, shadow
end

local glowColour, shadowColour = read_colours()

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
            color = shadowColour,
        },

        glow = {
            enabled = true,
            range = 10,
            render_power = 3,
            color = glowColour,
        },

        blur = {
            enabled = true,
            size = 7,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
})
