local conf_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local f = io.open(conf_home .. "/colors/hyprland.conf", "r")
if not f then
    local fallback = "4f8fe6"
    return {
        accent = fallback,
        background = "1e1e2e",
        surface = "313244",
        rgba = function(hex, alpha)
            if not hex then return nil end
            return "rgba(" .. hex .. alpha .. ")"
        end,
    }
end

local contents = f:read("*a")
f:close()

local function rgb(name)
    return contents:match("%$" .. name .. "%s*=%s*rgb%(([0-9a-fA-F]+)%)")
end

local function rgba(hex, alpha)
    if not hex then return nil end
    return "rgba(" .. hex .. alpha .. ")"
end

return {
    accent = rgb("accent"),
    background = rgb("bg"),
    surface = rgb("surface"),
    rgba = rgba,
}
