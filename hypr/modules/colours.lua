local f = io.open(os.getenv("HOME") .. "/.config/colors/hyprland.conf", "r")
if not f then
    return {}
end

local contents = f:read("*a")
f:close()

local function rgb(name)
    return contents:match("%$" .. name .. "%s*=%s*rgb%(([0-9a-fA-F]+)%)")
end

return {
    accent = rgb("accent"),
    background = rgb("bg"),
    surface = rgb("surface"),
}
