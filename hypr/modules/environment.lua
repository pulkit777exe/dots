-- GPU vendor stack: only force the dGPU when the user explicitly selected
-- the nvidia session (envycontrol mode nvidia). The old check (mere
-- presence of /dev/nvidiactl, true on hybrid too) forced every GLX app
-- onto the dGPU and drained battery. Without envycontrol, fall back to
-- the presence check so NVIDIA-only desktops do not regress.
local function envy_mode()
    local q = io.popen("command -v envycontrol >/dev/null && envycontrol --query 2>/dev/null")
    if not q then return nil end
    local mode = q:read("*l")
    q:close()
    return mode
end

local mode = envy_mode()
local want_nvidia = (mode == "nvidia")
if mode == nil then
    want_nvidia = io.open("/dev/nvidiactl", "r") ~= nil
end

if want_nvidia then
    hl.env("LIBVA_DRIVER_NAME", "iHD")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end
-- NOTE: NVIDIA_DRM_MODESET was set here before; it is a kernel parameter
-- (nvidia-drm.modeset=1), not an environment variable, so exporting it did
-- nothing. Set it via kernel cmdline if modesetting is ever needed.

-- uwsm already exports these; setting them again is at best duplicate.
-- Only fill them in for plain (non-uwsm) launches.
if os.getenv("XDG_SESSION_TYPE") == nil then
    hl.env("XDG_SESSION_TYPE", "wayland")
end
if os.getenv("XDG_CURRENT_DESKTOP") == nil then
    hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
end

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
