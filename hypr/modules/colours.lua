local f = io.open(os.getenv("HOME") .. "/.config/colors/hyprland.conf", "r")
if not f then
    return {}
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
