local home = os.getenv("HOME")
local screenshot_dir = home .. "/Pictures/Screenshots"

local shots = {
    { "", "area" },
    { "SHIFT + ", "active" },
    { "CTRL + ", "output" },
}

for _, s in ipairs(shots) do
    hl.bind(
        s[1] .. "Print",
        hl.dsp.exec_cmd(
            "mkdir -p " .. screenshot_dir ..
            " && grimblast copysave " .. s[2] .. " " ..
            screenshot_dir ..
            "/$(date +%Y-%m-%d_%H-%M-%S).png"
        )
    )
end
