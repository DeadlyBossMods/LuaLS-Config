local fs   = require "bee.filesystem"
local json = require "json"

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

-- Merge global definitions from various places
local globals = {}
local ws = fs.path(CHECK)

-- Handle .luacheckrc
local luacheckCfg = ws / ".luacheckrc"
local luacheck = {}
---@diagnostic disable-next-line: redundant-parameter
local f = loadfile(luacheckCfg:string(), nil, luacheck)
if f then f() end
if luacheck.globals then
	for _, v in ipairs(luacheck.globals) do
		globals[#globals + 1] = v
	end
end

-- Handle .luarc.json
local luarc = ws / ".luarc.json"
local f = io.open(luarc:string())
if f then
	local config = json.decode(f:read("*a"))
	local luarcGlobals = config["diagnostics.globals"]
	if luarcGlobals then
		for _, v in ipairs(luarcGlobals) do
			globals[#globals + 1] = v
		end
	end
	f:close()
end

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
	["Lua.diagnostics.globals"] = globals,
	["Lua.diagnostics.disable"] = {
		"unused-local", -- Very spammy and low value
		"redefined-local", -- Low value
		"empty-block", -- Triggers on some locales, generally not very useful
		"invisible", -- Slowest diagnostic and we don't use it
		"deprecated", -- Second slowest diagnostic and also pretty much unused for us
		"duplicate-doc-field" -- Slow to run on mods, likely due to the auto-generated field annotations (which we don't need to check)
	},
	["Lua.diagnostics.severity"]  = {
		["undefined-global"] = "Error",
		["lowercase-global"] = "Error",
	}
}
