local c = require("modules.colours")

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

        ["col.active_border"] = c.rgba(c.accent, "ff"),
        ["col.inactive_border"] = c.rgba(c.surface, "aa"),
    },
})
