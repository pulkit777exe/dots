local mod = "SUPER"

for _, m in ipairs({ { "272", hl.dsp.window.drag() }, { "273", hl.dsp.window.resize() } }) do
    hl.bind(mod .. " + mouse:" .. m[1], m[2], { mouse = true })
end
