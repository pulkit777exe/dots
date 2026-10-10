-- One curve for the whole compositor: every animated leaf gets the same
-- bezier and speed. Listed explicitly (not all-on) so a future leaf that
-- should stay still -- e.g. a test overlay -- is opt-in, not opt-out.
-- Covers open/close/move fades plus layers, which is what the shell's
-- layer-shell popups animate through.
local leaves = {
    "windows",
    "windowsIn",
    "windowsOut",
    "windowsMove",
    "fade",
    "fadeLayers",
    "layers",
    "layersIn",
    "layersOut",
    "workspaces",
    "workspacesIn",
    "workspacesOut",
    "border",
    "borderangle",
}

for _, leaf in ipairs(leaves) do
    hl.animation({
        leaf = leaf,
        enabled = true,
        bezier = "default",
        speed = 1.0,
    })
end
