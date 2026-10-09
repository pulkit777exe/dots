local mod = "SUPER"

local directions = {
    left = "left",
    right = "right",
    up = "up",
    down = "down",
}

for key, direction in pairs(directions) do

    hl.bind(
        mod .. " + " .. key,
        hl.dsp.focus({
            direction = direction,
        })
    )

    hl.bind(
        mod .. " + SHIFT + " .. key,
        hl.dsp.window.move({
            direction = direction,
        })
    )

    hl.bind(
        mod .. " + ALT + " .. key,
        hl.dsp.window.swap({
            direction = direction,
        })
    )
end

hl.bind(
    "ALT + TAB",
    hl.dsp.window.cycle_next({
        hist = true,
    })
)

hl.bind(
    "ALT + SHIFT + TAB",
    hl.dsp.window.cycle_next({
        prev = true,
        hist = true,
    })
)
