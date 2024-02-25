local guide = require "parser.guide"

local util = {}

local function getModNameFromArg(node, uri)
	local name
	if node.type == "integer" or node.type == "string" then
		name = tostring(node[1])
	else
		-- Fallback: filename, some mods have dynamic names, e.g., PvP/Arathi depends on game version
		name = uri:gsub(".*/", ""):gsub("(.*)%..*", "%1", 1)
	end
	name = name:gsub("[^%w]", "") -- mod IDs can be pretty much anything, at least apostrophes are somewhat common
	return "DBMMod" .. name
end

local function getDbmModVar(node, uri)
	local nodeName = guide.getKeyName(node)
	if nodeName ~= "NewMod" and nodeName ~= "GetModByName" then
		return
	end
	local callNode = node.parent
	if callNode.type ~= "call" or guide.getKeyName(node.node) ~= "DBM" or #callNode.args < 2 then
		return
	end
	-- FIXME: this is neither complete nor ideal, we should distinguish two cases:
	-- 1) mod is stored in a variable or table field
	-- 2) mod is used directly, e.g., an example from GUI: DBM:GetModByName(id).Options[foo] = bar
	-- We only care about case (1) here right now, but we may need some cases from (2) for some planned plugins like localization
	local parentTypes = {
		["local"] = true,
		setglobal = true,
		setfield = true,
		tableexp = true,
		tablefield = true,
		tableindex = true,
		callargs = true
	}
	local varNode = guide.getParentTypes(node, parentTypes)
	return varNode, callNode, getModNameFromArg(callNode.args[2], uri), nodeName
end

local function forwardIfNotEmpty(func, ...)
	if ... then
		func(...)
	end
end

-- TODO: can we cache the DBM mod vars somehow if this is used by multiple diagnostics?
function util.EachDBMModVar(ast, uri, callback)
	guide.eachSourceType(ast, "getmethod", function(node)
		forwardIfNotEmpty(callback, getDbmModVar(node, uri))
    end)
end

return util