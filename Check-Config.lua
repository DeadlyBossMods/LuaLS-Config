local fs = require "bee.filesystem"

if not DBM_LIBRARIES then
	error("Usage: parameter --dbm_libraries is required")
end

local basePath = fs.canonical(CONFIGPATH):parent_path()
local pluginPath = (basePath / "Plugin/Plugin.lua"):string()

local libs = {}
for lib in DBM_LIBRARIES:gmatch("([^,]+)") do
	libs[#libs + 1] = lib
end
libs[#libs + 1] = (basePath / "Definitions"):string()

-- Add ourselves to the list of trusted plugins
-- At first glance this may be a bit surprising that this is possible, but we are already executing code,
-- so I guess the safety check has no meaning anyways if the user opts to run a Lua config file
local trustedPluginsPath = fs.path(LOGPATH) / "TRUSTED"
local trustedPluginsFile, err = io.open(trustedPluginsPath:string(), "a+")
if not trustedPluginsFile then
	error("Could not write to TRUSTED file: " .. err)
end
local found = false
local empty = true
for line in trustedPluginsFile:lines() do
	empty = false
	if line == pluginPath then
		found = true
		break
	end
end
if not found then
	if not empty then
		trustedPluginsFile:write("\n")
	end
	trustedPluginsFile:write(pluginPath)
end
trustedPluginsFile:close()

return {
	["Lua.workspace.library"] = libs,
	["Lua.runtime.version"] = "Lua 5.1",
	["Lua.runtime.plugin"] = pluginPath,
}
