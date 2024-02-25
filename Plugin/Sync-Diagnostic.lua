local util        = require "Util"
local diagnostics = require "Custom-Diagnostics"

local guide = require "parser.guide"
local files = require "files"

local function analyzeMod(modVars, ast, callback)
	local syncsReceived = {}
	local syncsSent = {}
	for _, modVar in ipairs(modVars) do
		for k, node in ipairs(modVar.ref) do
			local setMethodNode = node.parent
			local methodName = guide.getKeyName(setMethodNode)
			if setMethodNode and setMethodNode.type == "setmethod" and methodName == "OnSync" then
				local syncArg = setMethodNode.value.args[2]
				if syncArg and syncArg.ref then
					for _, argRef in ipairs(syncArg.ref) do
						local binary = argRef.parent
						if binary and binary.type == "binary" and (binary.op.type == "==" or binary.op.type == "~=") then
							local other = binary[1] == argRef and binary[2] or binary[1]
							if other.type == "string" then
								syncsReceived[guide.getLiteral(other)] = binary
							else
								callback{
									start = other.start,
									finish = other.finish,
									message = "Cannot deduce value of expression the received sync message is being compared to. Compare it directly to a string literal."
								}
							end
						end
					end
				end
			end
		end
	end
	-- FIXME: these are just all SendSync calls on variables named mod or self, doesn't work for multiple mods in a file
	-- A proper implementation needs to check methods defined on the mods and methods called on their self params
	-- For now this is "good enough"
	guide.eachSourceType(ast, "call", function(callNode)
		if callNode.node.type ~= "getmethod" then return end
		local getMethodNode = callNode.node
		local objNode = getMethodNode.node
		local methodName = guide.getKeyName(getMethodNode)
		local objName = guide.getKeyName(objNode)
		if methodName == "SendSync" and (objName == "mod" or objName == "self") then
			local arg = callNode.args[2]
			if arg and arg.type == "string" then
				syncsSent[guide.getLiteral(arg)] = arg
			end
		end
	end)
	for k, v in pairs(syncsSent) do
		if not syncsReceived[k] then
			callback{
				start = v.start,
				finish = v.finish,
				message = ("Sync event \"%s\" is sent but never explicitly checked for in OnSync()."):format(k)
			}
		end
	end
	for k, v in pairs(syncsReceived) do
		if not syncsSent[k] then
			callback{
				start = v.start,
				finish = v.finish,
				message = ("Sync event \"%s\" is explicitly checked for in OnSync() but never sent."):format(k)
			}
		end
	end
end

local function syncDiagnostic(uri, callback)
	local state = files.getState(uri)
    if not state then
        return
    end
	local ast = state.ast
	local mods = {}
	util.EachDBMModVar(ast, uri, function(varNode, callNode, className)
		if varNode.type == "local" then
			varNode.ref = varNode.ref or {}
			local modVars = mods[className] or {}
			mods[className] = modVars
			modVars[#modVars + 1] = varNode
		end
	end)
	for k, v in pairs(mods) do
		analyzeMod(v, ast, callback)
	end
end

diagnostics:New("dbm-sync-checker", syncDiagnostic)
