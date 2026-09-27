-- modules/keybinds/screenshots.lua
--
-- Screenshot bindings using grimblast.

local home = os.getenv("HOME")
local screenshot_dir = home .. "/Pictures/Screenshots"

hl.bind(
    "Print",
    hl.dsp.exec_cmd(
        "mkdir -p " .. screenshot_dir ..
        " && grimblast copysave area " ..
        screenshot_dir ..
        "/$(date +%Y-%m-%d_%H-%M-%S).png"
    )
)

hl.bind(
    "SHIFT + Print",
    hl.dsp.exec_cmd(
        "mkdir -p " .. screenshot_dir ..
        " && grimblast copysave active " ..
        screenshot_dir ..
        "/$(date +%Y-%m-%d_%H-%M-%S).png"
    )
)

hl.bind(
    "CTRL + Print",
    hl.dsp.exec_cmd(
        "mkdir -p " .. screenshot_dir ..
        " && grimblast copysave output " ..
        screenshot_dir ..
        "/$(date +%Y-%m-%d_%H-%M-%S).png"
    )
)