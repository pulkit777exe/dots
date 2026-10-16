local mod = "SUPER"

for i = 1, 10 do
    local key = i % 10

    hl.bind(
        mod .. " + " .. key,
        hl.dsp.focus({
            workspace = i,
        })
    )

    hl.bind(
        mod .. " + SHIFT + " .. key,
        hl.dsp.window.move({
            workspace = i,
        })
    )
end
