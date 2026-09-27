-- modules/decoration.lua
--
-- Window appearance.

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

        blur = {
            enabled = true,
            size = 7,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
})