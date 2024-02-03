local parser = require 'parser'
local guide  = require 'parser.guide'

local file = arg[1] or error("usage: lua-language-server Event-Handler-Checker.lua <file to check>")
local code, err = io.open(file)
if not code then
	io.stderr:write('failed to open ' .. file .. ': ' .. err)
	os.exit(1)
end
code = code:read('a')
local state = parser.compile(code, 'Lua', 'Lua 5.1')

local noArgTableEvents = {
	SWING_DAMAGE = true,
	SWING_MISSED = true,
	RANGE_DAMAGE = true,
	RANGE_MISSED = true,
	SPELL_DAMAGE = true,
	SPELL_BUILDING_DAMAGE = true,
	SPELL_MISSED = true,
	SPELL_ABSORBED = true,
	SPELL_HEAL = true,
	SPELL_ENERGIZE = true,
	SPELL_PERIODIC_ENERGIZE = true,
	SPELL_PERIODIC_MISSED = true,
	SPELL_PERIODIC_DAMAGE = true,
	SPELL_PERIODIC_DRAIN = true,
	SPELL_PERIODIC_LEECH = true,
	SPELL_DRAIN = true,
	SPELL_LEECH = true,
	SPELL_CAST_FAILED = true
}

local function getLine(pos)
	if not pos then return -1 end
	return math.floor(pos / 10000) + 1
end

local function getColumn(pos)
	if not pos then return -1 end
	return pos % 10000
end

local function shortNodeString(node)
	if type(node) ~= "table" or not node.type then return tostring(node) end
	return ("line:%d:%d [%s:%s]"):format(getLine(node.start), getColumn(node.start), node.type, guide.getKeyName(node) or "nil")
end

local function emitDiagnostic(node, msg, ...)
	print("WARNING " .. shortNodeString(node) .. ": " .. msg:format(...))
end

-- Find DBM mods
local modVars = {}
guide.eachSourceType(state.ast, "call", function(node)
	if node.node.type ~= "getmethod" then return end
	local getMethodNode = node.node
	local methodName = guide.getKeyName(getMethodNode)
	-- TODO: we could match GetModByName with NewMod calls, but it's pretty rare that mods use this (exception: PvP)
	if guide.getKeyName(getMethodNode.node) == "DBM" and (methodName == "NewMod" or methodName == "GetModByName") then
		local localVar = guide.getParentType(node, "local")
		local globalVar = guide.getParentType(node, "setglobal")
		if localVar then
			modVars[#modVars+1] = guide.getParentType(node, "local")
		elseif globalVar and methodName == "NewMod" then
			emitDiagnostic(globalVar, "DBM mod constructor result written to global directly, please avoid that.")
		end
	end
end)

-- Find registered events
local registeredEvents = {}
local function parseEventString(event)
	local params = {}
	for v in event:gmatch("([^%s]+)") do
		params[#params + 1] = tonumber(v) or v
	end
	return {event = params[1], select(2, table.unpack(params))}
end
for k, node in ipairs(modVars[1].ref) do
	local getMethodNode = guide.getParentType(node, "getmethod")
	local methodName = guide.getKeyName(getMethodNode)
	if methodName == "RegisterEvents" or methodName == "RegisterEventsInCombat" then
		local callNode = guide.getParentType(node, "call")
		if callNode then
			for _, argNode in ipairs(callNode.args) do
				if argNode.type == "string" then
					local event = parseEventString(guide.getKeyName(argNode))
					event.node = argNode
					event.inCombatOnly = methodName == "RegisterEventsInCombat"
					registeredEvents[#registeredEvents + 1] = event
				elseif argNode.type ~= "self" then
					-- TODO: resolve some other common arg nodes if there are any in common use
					emitDiagnostic(argNode, "Registered event with non-literal string param.")
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

---@alias EventType "RawCLEU"|"ArgsTableCLEU"|"Event"
---@return EventType?
local function eventHandlerType(name)
	if not name then return end
	if name:match("^SPELL_") or name:match("^RANGE_") then -- only events with SpellId are relevant for CLEU/normal event
		return noArgTableEvents[name] and "RawCLEU" or "ArgsTableCLEU"
	end
	return name:match("^[%u_]+$") and "Event"
end

local function analyzeEventHandler(node, events)
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
	local function checkSpellIdUsage(arg, methodName)
		if arg.type == "integer" then
			local spellId = guide.getLiteral(arg)
			if not registeredSpellIds[spellId] then
				emitDiagnostic(arg, "Spell id %d is not registered for event %s.", spellId, eventName)
			end
		else
			-- TODO: if there are common cases for this we can catch these
			emitDiagnostic(arg, "Unexpected parameter type %s to %s, expected raw spell ID.", arg.type, methodName)
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
				checkSpellIdUsage(other, guide.getKeyName(spellIdArg) .. " equality comparison")
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
					checkSpellIdUsage(other, ".spellId equality check")
				end
			end
		end
	end
end

-- Handle function mod:FOO_EVENT(...)
for k, node in ipairs(modVars[1].ref) do
	local setMethodNode = node.parent
	local methodName = guide.getKeyName(setMethodNode)
	if setMethodNode and setMethodNode.type == "setmethod" and eventHandlerType(methodName) then
		if registeredEventsByName[methodName] then
			analyzeEventHandler(setMethodNode.value, registeredEventsByName[methodName])
		else
			emitDiagnostic(setMethodNode, "Event %s is not registered.", methodName)
		end
	end
end

local function findFieldValue(localNode, fieldNameTarget)
	if not fieldNameTarget or not localNode.ref then
		return
	end
	-- Just the first random function assignment is good enough
	for k, node in ipairs(modVars[1].ref) do
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
for k, node in ipairs(modVars[1].ref) do
	local setFieldNode = node.parent
	local fieldName = guide.getKeyName(setFieldNode)
	if setFieldNode and setFieldNode.type == "setfield" and eventHandlerType(fieldName) then
		if registeredEventsByName[fieldName] then
			if setFieldNode.value.type == "function" then
				analyzeEventHandler(setFieldNode.value, registeredEventsByName[fieldName])
			elseif setFieldNode.value.type == "getlocal" and setFieldNode.value.node.value then
				-- only support "local function foo() end" and "local foo = function() end"
				-- (yes, this misses "local x; x = function()")
				analyzeEventHandler(setFieldNode.value.node.value, registeredEventsByName[fieldName])
			elseif setFieldNode.value.type == "getfield" then
				local localNode = setFieldNode.value.node
				local functionNode = findFieldValue(localNode.node, guide.getKeyName(setFieldNode.value))
				if functionNode then
					analyzeEventHandler(functionNode, registeredEventsByName[fieldName])
				else
					emitDiagnostic(setFieldNode, "Failed to deduce value of field %s.", fieldName)
				end
			else
				emitDiagnostic(setFieldNode.value, "Unknown assignment to event handler for event %s.", fieldName)
			end
		else
			emitDiagnostic(setFieldNode, "Event %s is not registered.", fieldName)
		end
	end
end

-- Check sync handlers
-- Hacky, only checks OnSync declared as method (no indirection) and checks all SendSync() calls on variables named mod and self regardless of the object they are called on
local syncsReceived = {}
for k, node in ipairs(modVars[1].ref) do
	local setMethodNode = node.parent
	local methodName = guide.getKeyName(setMethodNode)
	if setMethodNode and setMethodNode.type == "setmethod" and methodName == "OnSync" then
		local syncArg = setMethodNode.value.args[2]
		if not syncArg or not syncArg.ref then
			return
		end
		for _, argRef in ipairs(syncArg.ref) do
			local binary = argRef.parent
			if binary and binary.type == "binary" and binary.op.type == "==" then
				local other = binary[1] == argRef and binary[2] or binary[1]
				if other.type == "string" then
					syncsReceived[guide.getLiteral(other)] = other
				else
					emitDiagnostic(argRef, "Cannot deduce received sync message equality comparison target.")
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
	if methodName == "SendSync" and (objName == "mod" or objName == "self") then
		local arg = callNode.args[2]
		if arg and arg.type == "string" then
			syncsSent[guide.getLiteral(arg)] = arg
		end
	end
end)

for k, v in pairs(syncsSent) do
	if not syncsReceived[k] then
		emitDiagnostic(v, "Sync event \"%s\" is sent but never explicitly checked for in OnSync().", k)
	end
end

for k, v in pairs(syncsReceived) do
	if not syncsSent[k] then
		emitDiagnostic(v, "Sync event \"%s\" is explicitly checked for in OnSync() but never sent.", k)
	end
end
