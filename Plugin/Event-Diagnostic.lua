local util        = require "Util"
local events      = require "Events"
local diagnostics = require "Custom-Diagnostics"

local guide = require "parser.guide"
local files = require "files"

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

-- FIXME: this file needs to be cleaned up


---@alias EventType "RawCLEU"|"ArgsTableCLEU"|"Event"
---@return EventType?
local function eventHandlerType(name)
	if not name then return end
	if name:match("^SPELL_") or name:match("^RANGE_") then -- only events with SpellId are relevant for the SpellId check
		return events.ArgTableEvents[name] and "ArgsTableCLEU" or "RawCLEU"
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

local function analyzeMod(modVars, callback)
	-- FIXME: this is incorrect after the file split refactoring: modVars are now vars refering to the *same* mod
	for _, modVar in ipairs(modVars) do
		if modVar.type ~= "local" then
			-- This should probably be a separate diagnostic
			callback{
				start = modVar.start,
				finish = modVar.finish,
				message = "DBM mods should be stored in locals only, otherwise the static analyzer for event checks won't work. Ignore this in dummy mods in Core or GUI."
			}
		else
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
						elseif setFieldNode.value.type == "getlocal" and setFieldNode.value.node.value and setFieldNode.value.node.value.type == "function" then
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
									start = setFieldNode.value.start,
									finish = setFieldNode.value.finish,
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
end

local function eventDiagnostic(uri, callback)
	local state = files.getState(uri)
    if not state then
        return
    end
	local ast = state.ast
	--local start = os.clock()
	local mods = {}
	util.EachDBMModVar(ast, uri, function(varNode, callNode, className, callType)
		local modVars = mods[className] or {}
		mods[className] = modVars
		modVars[#modVars + 1] = varNode
		if varNode.type == "local" then
			varNode.ref = varNode.ref or {}
		end
	end)
	for k, v in pairs(mods) do
		analyzeMod(v, callback)
	end
	--print("eventDiagnostic took " .. os.clock() - start .. " sec on " .. uri)
end

diagnostics:New("dbm-event-checker", eventDiagnostic)
