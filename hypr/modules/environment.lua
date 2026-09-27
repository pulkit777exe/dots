-- modules/environment.lua
--
-- Session environment variables, applied before anything else starts.
--
-- NVIDIA vars are applied only when the machine actually has NVIDIA
-- hardware. Forcing LIBVA_DRIVER_NAME=nvidia on a non-NVIDIA box makes
-- VA-API video decode fail outright, which breaks browsers and mpv, so
-- probe for the device node instead of assuming the target hardware.

local has_nvidia = io.open("/dev/nvidiactl", "r") ~= nil

if has_nvidia then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVIDIA_DRM_MODESET", "1")
end

-- Wayland session identity
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
