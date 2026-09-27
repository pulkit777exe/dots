-- modules/rules.lua
--
-- Application-specific window behavior.

-- Audio controls
hl.window_rule({
    name = "pavucontrol-floating",
    match = {
        class = "^pavucontrol$",
    },
    float = true,
    center = true,
})

-- Bluetooth manager
hl.window_rule({
    name = "blueman-floating",
    match = {
        class = "^blueman-manager$",
    },
    float = true,
    center = true,
})

-- Network connection editor
hl.window_rule({
    name = "network-manager-floating",
    match = {
        class = "^nm-connection-editor$",
    },
    float = true,
    center = true,
})

-- Picture-in-picture
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