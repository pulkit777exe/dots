local c = require("modules.colours")

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
            color = c.rgba(c.background, "ee"),
        },

        glow = {
            enabled = true,
            range = 10,
            render_power = 3,
            color = c.rgba(c.accent, "33"),
        },

        blur = {
            enabled = true,
            size = 7,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
})
