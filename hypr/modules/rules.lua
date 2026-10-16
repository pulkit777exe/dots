local floats = {
    { "pavucontrol-floating", "^pavucontrol$" },
    { "blueman-floating", "^blueman-manager$" },
    { "network-manager-floating", "^nm-connection-editor$" },
}

for _, r in ipairs(floats) do
    hl.window_rule({ name = r[1], match = { class = r[2] }, float = true, center = true })
end

hl.window_rule({
    name = "picture-in-picture",
    match = {
        title = "Picture%-in%-Picture",
    },
    float = true,
    pin = true,
    center = true,
    size = {
        800,
        450,
    },
})
