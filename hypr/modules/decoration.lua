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
            color = c.background and ("rgba(" .. c.background .. "ee)") or nil,
        },

        glow = {
            enabled = true,
            range = 10,
            render_power = 3,
            color = c.accent and ("rgba(" .. c.accent .. "33)") or nil,
        },

        blur = {
            enabled = true,
            size = 7,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
})
