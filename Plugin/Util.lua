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
	if nodeName ~= "NewMod" and nodeName ~= "GetModByName" and nodeName ~= "GetMod" then
		return
	end
	local callNode = node.parent
	if callNode.type ~= "call" or guide.getKeyName(node.node) ~= "DBM" or #callNode.args < 2 then
		return
	end
	local parentTypes = {
		["local"] = true,
		setglobal = true,
		setfield = true,
		setindex = true,
		tableexp = true,
		tablefield = true,
		tableindex = true,
		callargs = true,
		getfield = true,
		ifblock = true,
	}
	local nonAssignParentTypes = {
		callargs = true,
		getfield = true,
		ifblock = true,
	}
	local varNode = guide.getParentTypes(node, parentTypes)
	if not varNode or nonAssignParentTypes[varNode.type] then
		return
	end
	return varNode, callNode, getModNameFromArg(callNode.args[2], uri), nodeName
end

-- Finds all variables that contain DBM mods.
-- This makes some assumptions about mods such as that all functions are methods (i.e., first param is self).
-- It should catch most variables that appear in reasonably written mods.
-- TODO: we could use the type system to find all variables of the mod type, I've attempted this initially but it was a bit messy.
---@overload fun(state, callback)
function util.EachDBMModVar(ast, uri, callback)
	if type(uri) == "function" then return util.EachDBMModVar(ast.ast, ast.uri, uri) end
	guide.eachSourceType(ast, "getmethod", function(node)
		local varNode, callNode, modName, dbmNodeType = getDbmModVar(node, uri)
		if varNode then
			callback(varNode, callNode, modName, dbmNodeType)
			if varNode.type == "local" then
				util.FindSelfReferences(varNode, function(varNode)
					callback(varNode, callNode, modName, "Param")
				end)
			end
		end
    end)
end

-- Find references to an object in self parameters of methods (assumes every function field is a method)
function util.FindSelfReferences(varNode, callback)
	for _, node in ipairs(varNode.ref or {}) do
		local funcNode
		if node.parent.type == "setmethod" or node.parent.type == "setfield" then
			local funcNode
			if node.parent.value.type == "function" then
				funcNode = node.parent.value
			elseif node.parent.value.type == "getlocal" and node.parent.value.node.value.type == "function" then
				funcNode = node.parent.value.node.value
			end
			if funcNode and funcNode.args and funcNode.args[1] then
				callback(funcNode.args[1])
			end
		end
	end
end

return util