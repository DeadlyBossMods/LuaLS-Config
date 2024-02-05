local guide     = require "parser.guide"
local astHelper = require "plugins.astHelper"
local files     = require "files"

-- Not all events have args tables, see DBM-Core.lua:noArgTableEvents
-- TODO: validate that this list is complete; DBM uses an exclude list containing events that don't do this and does it for everything else
-- We need an explicit list of all such events
local eventsWithArgsTable = {
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_AURA_REFRESH",
	"SPELL_AURA_BROKEN",
	"SPELL_AURA_BROKEN_SPELL",
	"SPELL_AURA_REMOVED",
	"SPELL_AURA_REMOVED_DOSE",
	"SPELL_SUMMON",
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_CAST_FAILED",
	"SPELL_INTERRUPT",
	"SPELL_DISPELL",
	"SPELL_CREATE",
	"UNIT_DESTROYED",
	"UNIT_DIED",
	"PARTY_KILL"
}

local unitSpellcastEvents = {
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_SUCCEEDED"
}

local chatEvents = {
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_MONSTER_SAY",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"RAID_BOSS_WHISPER"
}

local function addClassDeclaration(ast, varNode, className, group)
	astHelper.addDoc(ast, varNode, "class", className .. ": DBMMod", group or {})
end

local function addFullModClassComment(ast, varNode, className, group)
	local group = group or {}
	addClassDeclaration(ast, varNode, className, group)
	-- Add definitions for common event handlers, found by looking at current usage of events in mods.
	-- CLEU events with arg table
	for _, v in ipairs(eventsWithArgsTable) do
		astHelper.addDoc(ast, varNode, "field", v .. " fun(self: " .. className .. ", args: DBMCombatLogArgs)", group)
	end
	-- UNIT_SPELLCAST_*
	for _, v in ipairs(unitSpellcastEvents) do
		astHelper.addDoc(ast, varNode, "field", v .. " fun(self: " .. className .. ", uId: string, castGUID: string, spellId: number)", group)
		astHelper.addDoc(ast, varNode, "field", v .. "_UNFILTERED fun(self: " .. className .. ", uId: string, castGUID: string, spellId: number)", group)
	end
	-- CHAT_MSG_*
	for _, v in ipairs(chatEvents) do
		astHelper.addDoc(ast, varNode, "field", v .. " fun(self: " .. className .. ", msg: string, sender: string, language: string, channel: string, from: string)", group)
	end
	-- No-arg combat log events
	astHelper.addDoc(ast, varNode, "field", "SPELL_DAMAGE fun(self: " .. className .. ", sourceGUID: string, sourceName: string, sourceFlags: number, sourceRaidFlags: number, destGUID: string, destName: string, destFlags: number, destRaidFlags: number, spellId: number, spellName: string, spellSchool: number, amount: number, overkill: number, school: number, resisted: number?, blocked: number?, absorbed: number?, critical: boolean, glancing: boolean, crushing: boolean, isOffHand: boolean)", group)
	astHelper.addDoc(ast, varNode, "field", "SPELL_PERIODIC_DAMAGE fun(self: " .. className .. ", sourceGUID: string, sourceName: string, sourceFlags: number, sourceRaidFlags: number, destGUID: string, destName: string, destFlags: number, destRaidFlags: number, spellId: number, spellName: string, spellSchool: number, amount: number, overkill: number, school: number, resisted: number?, blocked: number?, absorbed: number?, critical: boolean, glancing: boolean, crushing: boolean, isOffHand: boolean)", group)
	astHelper.addDoc(ast, varNode, "field", "SPELL_ENERGIZE fun(self: " .. className .. ", sourceGUID: string, sourceName: string, sourceFlags: number, sourceRaidFlags: number, destGUID: string, destName: string, destFlags: number, destRaidFlags: number, spellId: number, spellName: string, spellSchool: number, amount: number, overEnergize: number, powerType: number, alternatePowerType : number)", group)
	astHelper.addDoc(ast, varNode, "field", "SPELL_HEAL fun(self: " .. className .. ", sourceGUID: string, sourceName: string, sourceFlags: number, sourceRaidFlags: number, destGUID: string, destName: string, destFlags: number, destRaidFlags: number, spellId: number, spellName: string, spellSchool: number, amount: number, overhealing: number, absorbed: number?, critical: boolean)", group)
	astHelper.addDoc(ast, varNode, "field", "SPELL_MISSED fun(self: " .. className .. ", sourceGUID: string, sourceName: string, sourceFlags: number, sourceRaidFlags: number, destGUID: string, destName: string, destFlags: number, destRaidFlags: number, spellId: number, spellName: string, spellSchool: number, missType: string, isOffHand: boolean, amountMissed: number, critical: boolean)", group)
	astHelper.addDoc(ast, varNode, "field", "SWING_DAMAGE fun(self: " .. className .. ", sourceGUID: string, sourceName: string, sourceFlags: number, sourceRaidFlags: number, destGUID: string, destName: string, destFlags: number, destRaidFlags: number, amount: number, overkill: number, school: number, resisted: number?, blocked: number?, absorbed: number?, critical: boolean, glancing: boolean, crushing: boolean, isOffHand: boolean)", group)
	-- UNIT_*
	astHelper.addDoc(ast, varNode, "field", "UNIT_AURA fun(self: " .. className .. ", updateInfo: table)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_AURA_UNFILTERED fun(self: " .. className .. ", updateInfo: table)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_POWER_UPDATE fun(self: " .. className .. ", powerType: string)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_POWER_UPDATE_UNFILTERED fun(self: " .. className .. ", powerType: string)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_HEALTH fun(self: " .. className .. ", uId: string)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_HEALTH_UNFILTERED fun(self: " .. className .. ", uId: string)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_TARGET fun(self: " .. className .. ", uId: string)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_TARGET_UNFILTERED fun(self: " .. className .. ", uId: string)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_TARGETABLE_CHANGED fun(self: " .. className .. ", uId: string)", group)
	astHelper.addDoc(ast, varNode, "field", "UNIT_TARGETABLE_CHANGED_UNFILTERED fun(self: " .. className .. ", uId: string)", group)
	-- On* events
	astHelper.addDoc(ast, varNode, "field", "OnSync fun(self: " .. className .. ", msg: string, arg1: string, arg2: string, arg3: string, arg4: string, arg5: string)", group)
end

local function isDbmNewOrGetModCallNode(node)
	return node.type == "call"
		and (guide.getKeyName(node.node) == "NewMod" or guide.getKeyName(node.node) == "GetModByName") and node.node.type == "getmethod"
		and (guide.getKeyName(node.node.method) == "NewMod" or guide.getKeyName(node.node.method) == "GetModByName")
		and guide.getKeyName(node.node.node) == "DBM"
		and #node.args >= 2
		and guide.getKeyName(node.node.method)
end

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

function OnTransformAst(uri, ast)
	guide.eachSourceType(ast, "call", function(node)
		local dbmNodeType = isDbmNewOrGetModCallNode(node)
		if dbmNodeType then
			local varNode = guide.getParentTypes(node, {["local"] = true, ["setglobal"] = true})
			if varNode then
				local className = getModNameFromArg(node.args[2], uri)
				if dbmNodeType == "NewMod" then
					addFullModClassComment(ast, varNode, className)
				elseif dbmNodeType == "GetModByName" then
					addClassDeclaration(ast, varNode, className)
				end
			end
        end
    end)
	return ast
end

-- TODO: diagnostics should be split into a new file, but the path setup is a bit messy

-- Hacky hack to inject a custom diagnostic.
local function defineDiagnostic(name, func, severity, fileStatus, group)
	severity = severity or "Warning"
	fileStatus = fileStatus or "Opened"
	group = group or "DBM"
	local protoDiagnostic = require "proto.diagnostic"
	protoDiagnostic.register{name}{group = group, severity = severity, status = fileStatus}
	protoDiagnostic._diagAndErrNames[name] = true
	local protoDefine = require "proto.define"
	protoDefine.DiagnosticDefaultSeverity[name] = severity
	protoDefine.DiagnosticDefaultNeededFileStatus[name] = fileStatus
	package.loaded["core.diagnostics." .. name] = func
end

local function findDbmMods(ast)
	local localModVars, globalModVars = {}, {}
	guide.eachSourceType(ast, "call", function(node)
		local dbmNodeType = isDbmNewOrGetModCallNode(node)
		if dbmNodeType then
			local localVar = guide.getParentType(node, "local")
			local globalVar = guide.getParentType(node, "setglobal")
			-- TODO: we could match GetModByName with NewMod calls, but that would only be useful cross-file which is rather messy
			-- But it would be great to catch some uses of SendSync/OnSync when shared between trash mods and bosses
			if localVar and localVar.ref then
				localModVars[#localModVars + 1] = localVar
			elseif globalVar and dbmNodeType == "NewMod" then
				globalModVars[#globalModVars + 1] = globalVar
				-- TODO: support setfield here?
			end
		end
	end)
	return localModVars, globalModVars
end

local function modInGlobalDiagnostic(uri, callback)
	local state = files.getState(uri)
    if not state then
        return
    end
	local _, dbmModsInGlobals = findDbmMods(state.ast)
	for _, v in ipairs(dbmModsInGlobals) do
		callback{
			start = v.start,
			finish = v.finish,
			message = "Result of DBM:NewMod() should not be directly stored in a global variable"
		}
	end
end
defineDiagnostic("dbm-mod-in-global", modInGlobalDiagnostic)

-- Check sync handlers
-- Hacky, only checks OnSync declared as method (no indirection) and checks all SendSync() calls on variables named mod and self regardless of the object they are called on.
-- This breaks a bit if you have multiple mods in a single file.
local function syncHandlerDiagnostic(uri, callback)
	local state = files.getState(uri)
    if not state then
        return
    end
	local dbmModVars = findDbmMods(state.ast)
	for _, dbmModVar in ipairs(dbmModVars) do
		local syncsReceived = {}
		for k, node in ipairs(dbmModVar.ref) do
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
		local syncsSent = {}
		guide.eachSourceType(state.ast, "call", function(callNode)
			if callNode.node.type ~= "getmethod" then return end
			local getMethodNode = callNode.node
			local objNode = getMethodNode.node
			local methodName = guide.getKeyName(getMethodNode)
			local objName = guide.getKeyName(objNode)
			-- TODO: this should check method definitions on the mod var instead and use their self params
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
end
defineDiagnostic("dbm-sync-checker", syncHandlerDiagnostic)

-- Check DBM events
local function parseEventString(event)
	local result = {}
	local subEvent, args = event:match("([^%s]+)%s*(.*)")
	args = args or ""
	for v in args:gmatch("([^%s]+)") do
		result[#result + 1] = tonumber(v) or v
	end
	result.event = subEvent
	return result
end

local eventsWithArgsTableByEvent = {}
for _, v in ipairs(eventsWithArgsTable) do
	eventsWithArgsTableByEvent[v] = true
end

---@alias EventType "RawCLEU"|"ArgsTableCLEU"|"Event"
---@return EventType?
local function eventHandlerType(name)
	if not name then return end
	if name:match("^SPELL_") or name:match("^RANGE_") then -- only events with SpellId are relevant for the SpellId check
		return eventsWithArgsTableByEvent[name] and "ArgsTableCLEU" or "RawCLEU"
	end
	return name:match("^[%u_]+$") and "Event"
end

local function analyzeEventHandler(node, events, callback)
	local eventName = events[1].event
	local eventType = eventHandlerType(eventName)
	if eventType ~= "RawCLEU" and eventType ~= "ArgsTableCLEU" then
		return
	end
	local registeredSpellIds = {}
	for _, event in ipairs(events) do
		for _, spellId in ipairs(event) do
			registeredSpellIds[spellId] = true
		end
		if #event == 0 then -- no params == everything
			return
		end
	end
	local function checkSpellIdUsage(arg, methodName, highlightNode)
		highlightNode = highlightNode or arg
		if arg.type == "integer" then
			local spellId = guide.getLiteral(arg)
			if not registeredSpellIds[spellId] then
				callback{
					start = highlightNode.start,
					finish = highlightNode.finish,
					message = ("Spell id %d is not registered for event %s."):format(spellId, eventName)
				}
			end
		else
			-- TODO: If there are common cases for this we can catch these, but looks like all existing mods just use literals here.
			callback{
				start = arg.start,
				finish = arg.finish,
				message = ("Unexpected parameter type %s to %s, expected raw spell ID."):format(arg.type, methodName)
			}
		end
	end
	if eventType == "RawCLEU" then
		local spellIdArg = node.args[10]
		if not spellIdArg or not spellIdArg.ref then
			return
		end
		for _, argRef in ipairs(spellIdArg.ref) do
			local binary = argRef.parent
			if binary and binary.type == "binary" and binary.op.type == "==" then
				local other = binary[1] == argRef and binary[2] or binary[1]
				checkSpellIdUsage(other, guide.getKeyName(spellIdArg) .. " equality comparison", binary)
			end
		end
	elseif eventType == "ArgsTableCLEU" then
		local clArgs = node.args[2]
		if not clArgs or not clArgs.ref then
			return
		end
		for _, clArgsRef in ipairs(clArgs.ref) do
			local parent = clArgsRef.parent
			if parent and parent.type == "getmethod" then
				local methodName = guide.getKeyName(parent)
				local callNode = guide.getParentType(clArgsRef, "call")
				if callNode and callNode.args and (methodName == "IsSpell" or methodName == "IsSpellID") then
					for i = 2, #callNode.args do
						local arg = callNode.args[i]
						checkSpellIdUsage(arg, methodName)
					end
				end
			elseif parent and parent.type == "getfield" then
				-- Only catch the simple "args.spellId == xyz" case
				local fieldName = guide.getKeyName(parent)
				local binary = parent.parent
				if fieldName == "spellId" and binary and binary.type == "binary" and binary.op.type == "==" then
					local other = binary[1] == parent and binary[2] or binary[1]
					checkSpellIdUsage(other, ".spellId equality check", binary)
				end
			end
		end
	end
end

local function eventDiagnostic(uri, callback)
	local state = files.getState(uri)
    if not state then
        return
    end
	local dbmModVars = findDbmMods(state.ast)
	for _, modVar in ipairs(dbmModVars) do
		local registeredEvents = {}
		for _, node in ipairs(modVar.ref) do
			local getMethodNode = node.parent
			local methodName = guide.getKeyName(getMethodNode)
			if methodName == "RegisterEvents" or methodName == "RegisterEventsInCombat" or methodName == "RegisterShortTermEvents" then
				local callNode = getMethodNode.parent
				if callNode.type == "call" then
					for _, argNode in ipairs(callNode.args) do
						if argNode.type == "string" then
							local event = parseEventString(guide.getKeyName(argNode))
							event.node = argNode
							event.inCombatOnly = methodName == "RegisterEventsInCombat"
							event.shortTerm = methodName == "RegisterShortTermEvents"
							registeredEvents[#registeredEvents + 1] = event
						elseif argNode.type ~= "self" then
							-- We could resolve some other commonly used parameters here, but looks like all existing mods just pass string literals here
							callback{
								start = argNode.start,
								finish = argNode.finish,
								message = "Registered event with parameter that is not a string literal."
							}
						end
					end
				end
			end
		end
		local registeredEventsByName = {}
		for _, v in ipairs(registeredEvents) do
			local events = registeredEventsByName[v.event] or {}
			registeredEventsByName[v.event] = events
			events[#events + 1] = v
		end
		-- Handle function mod:FOO_EVENT(...)
		for _, node in ipairs(modVar.ref) do
			local setMethodNode = node.parent
			local methodName = guide.getKeyName(setMethodNode)
			if setMethodNode and setMethodNode.type == "setmethod" and eventHandlerType(methodName) then
				if registeredEventsByName[methodName] then
					analyzeEventHandler(setMethodNode.value, registeredEventsByName[methodName], callback)
				else
					callback{
						start = setMethodNode.start,
						finish = setMethodNode.finish,
						message = ("Event %s is not registered."):format(methodName)
					}
				end
			end
		end
		local function findFieldValue(localNode, fieldNameTarget)
			if not fieldNameTarget or not localNode.ref then
				return
			end
			-- Just the first random function assignment is good enough
			for _, node in ipairs(modVar.ref) do
				local setFieldNode = node.parent
				local fieldName = guide.getKeyName(setFieldNode)
				if setFieldNode and (setFieldNode.type == "setfield" or setFieldNode.type == "setmethod") and fieldName == fieldNameTarget then
					if setFieldNode.value.type == "function" then
						return setFieldNode.value
					elseif setFieldNode.value.type == "getlocal" and setFieldNode.value.node.value then
						return setFieldNode.value.node.value
					end
				end
			end
		end
		-- Handle function mod.FOO_EVENT = (something)
		for _, node in ipairs(modVar.ref) do
			local setFieldNode = node.parent
			local fieldName = guide.getKeyName(setFieldNode)
			if setFieldNode and setFieldNode.type == "setfield" and eventHandlerType(fieldName) then
				if registeredEventsByName[fieldName] then
					if setFieldNode.value.type == "function" then
						analyzeEventHandler(setFieldNode.value, registeredEventsByName[fieldName], callback)
					elseif setFieldNode.value.type == "getlocal" and setFieldNode.value.node.value then
						-- only support "local function foo() end" and "local foo = function() end"
						-- (yes, this misses "local x; x = function()")
						analyzeEventHandler(setFieldNode.value.node.value, registeredEventsByName[fieldName], callback)
					elseif setFieldNode.value.type == "getfield" then
						local localNode = setFieldNode.value.node
						local functionNode = findFieldValue(localNode.node, guide.getKeyName(setFieldNode.value))
						if functionNode then
							analyzeEventHandler(functionNode, registeredEventsByName[fieldName], callback)
						else
							callback{
								start = setFieldNode.start,
								finish = setFieldNode.finish,
								message = ("Failed to deduce value of field %s."):format(fieldName)
							}
						end
					else
						callback{
							start = setFieldNode.value.start,
							finish = setFieldNode.value.finish,
							message = ("Failed to deduce value of field %s."):format(fieldName)
						}
					end
				else
					callback{
						start = setFieldNode.start,
						finish = setFieldNode.finish,
						message = ("Event %s is not registered"):format(fieldName)
					}
				end
			end
		end
	end
end
defineDiagnostic("dbm-event-checker", eventDiagnostic)


print("Loaded DBM-Plugin!")
