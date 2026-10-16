local mod = "SUPER"

local toggles = {
    { "V", hl.dsp.window.float({ action = "toggle" }) },
    { "F", hl.dsp.window.fullscreen({ state = "toggle" }) },
    { "SHIFT + V", hl.dsp.window.pseudo({ state = "toggle" }) },
}

for _, t in ipairs(toggles) do
    hl.bind(mod .. " + " .. t[1], t[2])
end
