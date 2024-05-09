local fs   = require "bee.filesystem"
local json = require "json"
local diags = require "proto.diagnostic"

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
local ws = fs.path(CHECK or CHECK_WORKER)

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

local disabledDiagnostics = {
	"unused-local", -- Very spammy and low value
	"redefined-local", -- Low value
	"empty-block", -- Triggers on some locales, generally not very useful
	"invisible", -- Slowest diagnostic and we don't use it
	"deprecated", -- Second slowest diagnostic and also pretty much unused for us
	"duplicate-doc-field" -- Slow to run on mods, likely due to the auto-generated field annotations (which we don't need to check)
}

-- Lightweight check just to replace LuaCheck but without pulling in more noisy/potentially false-positive warnings.
-- Used to gate releases.
if ONLY_CHECK_GLOBALS then
	local enabledDiagnostics = {
		["undefined-global"] = true,
		["lowercase-global"] = true,
		["global-element"] = true
	}
	for diag in pairs(diags.getDiagAndErrNameMap()) do
		if not enabledDiagnostics[diag] then
			disabledDiagnostics[#disabledDiagnostics + 1] = diag
		end
	end
	-- Config file is run before the plugin that loads these, so they are not yet included above
	disabledDiagnostics[#disabledDiagnostics + 1] = "dbm-sync-checker"
	disabledDiagnostics[#disabledDiagnostics + 1] = "dbm-event-checker"
end

return {
	["Lua.workspace.library"] = libs,
	["Lua.runtime.version"] = "Lua 5.1",
	["Lua.runtime.plugin"] = pluginPath,
	["Lua.diagnostics.globals"] = globals,
	["Lua.diagnostics.disable"] = disabledDiagnostics,
	["Lua.diagnostics.neededFileStatus"] = {
		["global-element"] = "Any" -- Bans defining global variables, even if they are all uppercase (consistent with LuaCheck)
	},
	["Lua.diagnostics.severity"]  = {
		["undefined-global"] = "Error",
		["lowercase-global"] = "Error",
	}
}
