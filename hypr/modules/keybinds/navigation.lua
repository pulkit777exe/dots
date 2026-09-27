-- modules/keybinds/navigation.lua
--
-- Focus, move, swap, and Alt-Tab.

local mod = "SUPER"

local directions = {
    left = "left",
    right = "right",
    up = "up",
    down = "down",
}

for key, direction in pairs(directions) do

    -- Focus
    hl.bind(
        mod .. " + " .. key,
        hl.dsp.focus({
            direction = direction,
        })
    )

    -- Move
    hl.bind(
        mod .. " + SHIFT + " .. key,
        hl.dsp.window.move({
            direction = direction,
        })
    )

    -- Swap
    hl.bind(
        mod .. " + ALT + " .. key,
        hl.dsp.window.swap({
            direction = direction,
        })
    )
end

-- Next window
hl.bind(
    "ALT + TAB",
    hl.dsp.window.cycle_next({
        hist = true,
    })
)

-- Previous window
hl.bind(
    "ALT + SHIFT + TAB",
    hl.dsp.window.cycle_next({
        prev = true,
        hist = true,
    })
)