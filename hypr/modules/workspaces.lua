-- modules/workspaces.lua
--
-- Workspace-specific compositor configuration.

-- Keep the default workspaces simple.
-- Workspace 1-10 are created on demand by keybinds.

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        layout = "dwindle",
    })
end