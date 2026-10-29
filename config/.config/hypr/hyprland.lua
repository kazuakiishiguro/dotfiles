-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Support both packaged Omarchy and older installations in ~/.local/share.
local home = os.getenv("HOME")
local omarchy_path
local candidates = { os.getenv("OMARCHY_PATH") or "", "/usr/share/omarchy", home .. "/.local/share/omarchy" }
for _, candidate in ipairs(candidates) do
  local defaults = io.open(candidate .. "/default/hypr/omarchy.lua", "r")
  if defaults then
    defaults:close()
    omarchy_path = candidate
    break
  end
end
assert(omarchy_path, "Cannot find Omarchy's Hyprland defaults")

-- Current bootstrap also reloads Lua modules and resolves generated theme state.
local bootstrap_path = omarchy_path .. "/default/hypr/bootstrap.lua"
local bootstrap = io.open(bootstrap_path, "r")
if bootstrap then
  bootstrap:close()
  dofile(bootstrap_path)
end
-- Use the detected installation even if the session kept a stale OMARCHY_PATH.
package.path = home .. "/.local/state/?.lua;" .. home .. "/.config/?.lua;" .. omarchy_path .. "/?.lua;" .. package.path

-- All Omarchy default setups
require("default.hypr.omarchy")

-- Change your own setup in these files and override defaults.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Machine-only overrides live outside Git and run after the shared settings.
local local_path = home .. "/.config/hypr/local.lua"
local local_config = io.open(local_path, "r")
if local_config then
  local_config:close()
  dofile(local_path)
end
