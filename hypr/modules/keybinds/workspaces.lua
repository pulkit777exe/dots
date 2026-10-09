local mod = "SUPER"

for i = 1, 9 do

    hl.bind(
        mod .. " + " .. i,
        hl.dsp.focus({
            workspace = i,
        })
    )

    hl.bind(
        mod .. " + SHIFT + " .. i,
        hl.dsp.window.move({
            workspace = i,
        })
    )
end

hl.bind(
    mod .. " + 0",
    hl.dsp.focus({
        workspace = 10,
    })
)

hl.bind(
    mod .. " + SHIFT + 0",
    hl.dsp.window.move({
        workspace = 10,
    })
)
