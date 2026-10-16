local mod = "SUPER"

local directions = { "left", "right", "up", "down" }

for _, direction in ipairs(directions) do

    hl.bind(
        mod .. " + " .. direction,
        hl.dsp.focus({
            direction = direction,
        })
    )

    hl.bind(
        mod .. " + SHIFT + " .. direction,
        hl.dsp.window.move({
            direction = direction,
        })
    )

    hl.bind(
        mod .. " + ALT + " .. direction,
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
