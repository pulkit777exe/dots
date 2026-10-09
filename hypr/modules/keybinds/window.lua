local mod = "SUPER"

hl.bind(
    mod .. " + V",
    hl.dsp.window.float({
        action = "toggle",
    })
)

hl.bind(
    mod .. " + F",
    hl.dsp.window.fullscreen({
        state = "toggle",
    })
)

hl.bind(
    mod .. " + SHIFT + V",
    hl.dsp.window.pseudo({
        state = "toggle",
    })
)
