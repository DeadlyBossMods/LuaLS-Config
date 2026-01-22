local util        = require "Util"
local events      = require "Events"
local diagnostics = require "Custom-Diagnostics"

local guide = require "parser.guide"
local files = require "files"

---@alias EventType "RawCLEU"|"ArgsTableCLEU"|"Event"
---@return EventType?
local function eventHandlerType(name)
	if not name then return end
	if name:match("^SPELL_") or name:match("^RANGE_") then -- only events with SpellId are relevant for the SpellId check
		return events.ArgTableEvents[name] and "ArgsTableCLEU" or "RawCLEU"
	end
	return name:match("^[%u_]+$") and "Event"
end

---@param handlerMapping HandlerMapping[]
local function analyzeEventHandler(node, handlerMapping, registeredEvents, callback)
	local registeredSpellIds = {}
	local handledEventsMsg
	if #handlerMapping == 1 then
		handledEventsMsg = "event " .. handlerMapping[1].name
	else
		handledEventsMsg = "events "
	end
	local isRawCleuEvent = false
	local isArgsTableCleuEvent = false
	for _, mapping in ipairs(handlerMapping) do
		local eventType = eventHandlerType(mapping.name)
		if #handlerMapping > 1 then
			handledEventsMsg = handledEventsMsg .. mapping.name .. ", "
		end
		isRawCleuEvent = isRawCleuEvent or eventType == "RawCLEU"
		isArgsTableCleuEvent = isArgsTableCleuEvent or eventType == "ArgsTableCLEU"
		if eventType == "RawCLEU" or eventType == "ArgsTableCLEU" then
			local registrations = registeredEvents[mapping.name]
			if registrations then
				for _, registration in ipairs(registrations) do
					if #registration.args == 0 then -- No args == everything registered
						return
					end
					for _, spellId in ipairs(registration.args) do
						registeredSpellIds[spellId] = true
					end
				end
			end
		end
	end
	handledEventsMsg = handledEventsMsg:gsub(", $", "")
	if isRawCleuEvent and isArgsTableCleuEvent then
		callback{
			start = node.parent.start,
			finish = node.parent.finish,
			message = "This event handler attempts to handle events for raw combat log events and combat log events with args tables."
		}
		return
	end
	local function checkSpellIdUsage(arg, methodName, highlightNode)
		highlightNode = highlightNode or arg
		if arg.type == "integer" then
			local spellId = guide.getLiteral(arg)
			if not registeredSpellIds[spellId] then
				callback{
					start = highlightNode.start,
					finish = highlightNode.finish,
					message = ("Spell id %d is not registered for %s."):format(spellId, handledEventsMsg)
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
	if isRawCleuEvent then
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
	elseif isArgsTableCleuEvent then
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
				local fieldName = guide.getKeyName(parent)
				if fieldName == "spellId" then
					local fieldUsage = parent.parent
					-- Handle the "args.spellId == xyz" case
				 	if fieldUsage and fieldUsage.type == "binary" and fieldUsage.op.type == "==" then
						local other = fieldUsage[1] == parent and fieldUsage[2] or fieldUsage[1]
						checkSpellIdUsage(other, ".spellId equality check", fieldUsage)
					-- Handle the "local foo = args.spellId if foo == xyyz then" case
					elseif fieldUsage and fieldUsage.type == "local" and fieldUsage.ref then
						for _, ref in ipairs(fieldUsage.ref) do
							fieldUsage = ref.parent
							if fieldUsage.type == "binary" and fieldUsage.op.type == "==" then
								local other = fieldUsage[1] == ref and fieldUsage[2] or fieldUsage[1]
								checkSpellIdUsage(other, "spellId propagated to local equality check", fieldUsage)
							end
						end
					end
				end
			end
		end
	end
end

local function findEventHandlers(varNode, handlers, callback)
	local function addEventHandler(node, mappingNode, event)
		local events = handlers[node] or {}
		handlers[node] = events
		---@class HandlerMapping
		events[#events + 1] = {
			name = event, ---@type string
			mappingNode = mappingNode ---@type parser.object
		}
	end
	-- Handle function mod:FOO_EVENT(...)
	for _, node in ipairs(varNode.ref) do
		local setMethodNode = node.parent
		local methodName = guide.getKeyName(setMethodNode)
		if setMethodNode and setMethodNode.type == "setmethod" and eventHandlerType(methodName) then
			addEventHandler(setMethodNode.value, setMethodNode, methodName)
		end
	end
	local function findFieldValue(localNode, fieldNameTarget)
		if not fieldNameTarget or not localNode.ref then
			return
		end
		-- Just the first random function assignment is good enough
		for _, node in ipairs(varNode.ref) do
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
	for _, node in ipairs(varNode.ref) do
		local setFieldNode = node.parent
		local fieldName = guide.getKeyName(setFieldNode)
		if setFieldNode and setFieldNode.type == "setfield" and eventHandlerType(fieldName) then
			if setFieldNode.value.type == "function" then
				addEventHandler(setFieldNode.value, setFieldNode, fieldName)
			elseif setFieldNode.value.type == "getlocal" and setFieldNode.value.node.value and setFieldNode.value.node.value.type == "function" then
				-- only support "local function foo() end" and "local foo = function() end"
				-- (yes, this misses "local x; x = function()")
				addEventHandler(setFieldNode.value.node.value, setFieldNode, fieldName)
			elseif setFieldNode.value.type == "getfield" then
				local localNode = setFieldNode.value.node
				local functionNode = findFieldValue(localNode.node, guide.getKeyName(setFieldNode.value))
				if functionNode then
					addEventHandler(functionNode, setFieldNode, fieldName)
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
		end
	end
end

local function parseEventString(event)
	local subEvent, args = event:match("([^%s]+)%s*(.*)")
	---@class ParsedDBMEvent
	local result = {
		event = subEvent, ---@type string
		args = {}
	}
	args = args or ""
	for v in args:gmatch("([^%s]+)") do
		result.args[#result.args + 1] = v:match("^%d+$") and tonumber(v) or v
	end
	return result
end

---@param varNode parser.object
---@param events ParsedDBMEvent[]
local function findRegisteredEvents(varNode, events, callback)
	for _, ref in ipairs(varNode.ref) do
		local getMethodNode = ref.parent
		local methodName = guide.getKeyName(getMethodNode)
		if getMethodNode.type == "getmethod" and (methodName == "RegisterEvents" or methodName == "RegisterEventsInCombat" or methodName == "RegisterShortTermEvents" or methodName == "RegisterSafeEvents" or methodName == "RegisterSafeEventsInCombat") then
			local callNode = getMethodNode.parent
			if callNode.type == "call" then
				for _, argNode in ipairs(callNode.args) do
					if argNode.type == "string" then
						---@class ParsedDBMEvent
						local event = parseEventString(guide.getKeyName(argNode))
						event.node = argNode
						event.inCombatOnly = methodName == "RegisterEventsInCombat" or methodName == "RegisterSafeEventsInCombat"
						event.shortTerm = methodName == "RegisterShortTermEvents"
						events[#events + 1] = event
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
end

local validEventUids = {
	player = true, target = true, focus = true, mouseover = true, pet = true, vehicle = true, none = true
}
local function isValidEventUnitId(uId)
	return validEventUids[uId]
		or uId:match("^boss%d") or uId:match("^party%d") or uId:match("^raid%d+") or uId:match("^nameplate%d+")
		or uId:match("^partypet%d") or uId:match("^raidpet%d+") or uId:match("^spectated.%d+") or uId:match("^spectatedpet.%d+")
		or uId:match("^arena%d")
end

---@param event ParsedDBMEvent
local function checkEvent(event, node, callback)
	local eventName = event.event
	if events.WowEvents[eventName] then
		if eventName:match("^UNIT_") then
			for _, arg in ipairs(event.args) do
				if not isValidEventUnitId(arg) then
					callback{
						start = node.start,
						finish = node.finish,
						message = ("Parameter %s is not valid for event %s, expected a unit id."):format(arg, eventName)
					}
				end
			end
		else
			if #event.args > 0 then
				callback{
					start = node.start,
					finish = node.finish,
					message = ("Event %s does not take parameters."):format(eventName)
				}
			end
		end
	elseif events.WowEvents[eventName:gsub("_UNFILTERED$", "")] then
		if #event.args > 0 then
			callback{
				start = node.start,
				finish = node.finish,
				message = ("_UNFILTERED events do not take parameters."):format(eventName)
			}
		end
	elseif events.ArgTableEvents[eventName] or events.NoArgsTableEvents[eventName] then
		if eventName:match("^SPELL_") or eventName:match("^RANGE_") or eventName == "DAMAGE_SHIELD" or eventName == "DAMAGE_SHIELD_MISSED" then
			for _, arg in ipairs(event.args) do
				if type(arg) ~= "number" then
					callback{
						start = node.start,
						finish = node.finish,
						message = ("Parameter %s is not valid for event %s, expected a spell id."):format(arg, eventName)
					}
				end
			end
		elseif #event.args > 0 then
			callback{
				start = node.start,
				finish = node.finish,
				message = "Only SPELL_, RANGE_, and DAMAGE_SHIELD[_MISSED] combat log events take parameters."
			}
		end
	else
		callback{
			start = node.start,
			finish = node.finish,
			message = ("Unknown event %s."):format(eventName)
		}
	end
end

local function analyzeMod(modVars, callback)
	local registeredEvents = {} ---@type ParsedDBMEvent[]
	local eventHandlers = {} ---@type {[parser.object]: HandlerMapping[]}
	for _, modVar in ipairs(modVars) do
		findRegisteredEvents(modVar, registeredEvents, callback)
		findEventHandlers(modVar, eventHandlers, callback)
	end
	local registeredEventsByName = {}
	for _, v in ipairs(registeredEvents) do
		checkEvent(v, v.node, callback)
		local events = registeredEventsByName[v.event] or {}
		registeredEventsByName[v.event] = events
		events[#events + 1] = v
	end
	local handlersByEvent = {}
	for node, events in pairs(eventHandlers) do
		for _, event in ipairs(events) do
			handlersByEvent[event.name] = node
		end
	end

	-- Used but not registered events
	for node, events in pairs(eventHandlers) do
		for _, event in ipairs(events) do
			if not registeredEventsByName[event.name] then
				callback{
					start = event.mappingNode.start,
					finish = event.mappingNode.finish,
					message = ("Event %s is not registered"):format(event.name)
				}
			end
		end
	end
	-- Registered but unused events
	-- TODO: this may turn out to be annoying, re-evaluate if this provides enough value for the annoyingness
	-- Examples of errors this would catch: adding SPELL_AURA_APPLIED_DOSE later but forgetting to assign the event handler to the existing one
	for _, event in pairs(registeredEvents) do
		if not handlersByEvent[event.event] then
			callback{
				start = event.node.start,
				finish = event.node.finish,
				message = ("Event %s is registered but unused"):format(event.event)
			}
		end
	end

	for node, mappings in pairs(eventHandlers) do
		analyzeEventHandler(node, mappings, registeredEventsByName, callback)
	end
end

local function eventDiagnostic(uri, callback)
	local state = files.getState(uri)
    if not state then
        return
    end
	local ast = state.ast
--	local start = os.clock()
	local mods = {}
	util.EachDBMModVar(state, function(varNode, callNode, className)
		local modVars = mods[className] or {}
		mods[className] = modVars
		if varNode.type == "local" or varNode.type == "self" or varNode.type == "setlocal" then
			varNode.ref = varNode.ref or {}
			modVars[#modVars + 1] = varNode
		else
			-- This should probably be a separate diagnostic
			callback{
				start = varNode.start,
				finish = varNode.finish,
				message = "DBM mods should be stored in locals only, otherwise the static analyzer for event checks won't work. Ignore this in dummy mods in Core or GUI."
			}
		end
	end)
	for k, v in pairs(mods) do
		analyzeMod(v, callback)
	end
--	print("eventDiagnostic took " .. os.clock() - start .. " sec on " .. uri)
end

diagnostics:New("dbm-event-checker", eventDiagnostic)

if not QUIET then
	print("Loaded DBM event checker diagnostic")
end
