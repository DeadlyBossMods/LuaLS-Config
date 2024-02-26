local util   = require "Util"
local events = require "Events"

local astHelper = require "plugins.astHelper"

local plugin = {}

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

local function addFullModClassComment(ast, varNode, className)
	local group = {}
	addClassDeclaration(ast, varNode, className, group)
	-- Add definitions for common event handlers, found by looking at current usage of events in mods.
	-- The full definitions are a bit messy, so we restrict outselves to those that are actually being used for now.
	-- CLEU events with arg table
	for _, v in ipairs(events.CombatLogEvents) do
		if not events.NoArgsTableEvents[v] then
			astHelper.addDoc(ast, varNode, "field", v .. " fun(self: " .. className .. ", args: DBMCombatLogArgs)", group)
		end
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
	astHelper.addDoc(ast, varNode, "field", "OnCombatStart fun(self: " .. className .. ", delay: number)", group)
end

function plugin:OnTransformAst(uri, ast)
	-- Runs for 20-30ms on Core and provides pretty much 0 value there
	if uri:find("DBM%-Core%.lua$") then
		return
	end
	util.EachDBMModVar(ast, uri, function(varNode, _, className, callType)
		if varNode.type ~= "local" and varNode.type ~= "setglobal" and varNode.type ~= "setfield" then
			return
		end
		if callType == "NewMod" then
			addFullModClassComment(ast, varNode, className)
		elseif callType == "GetModByName" then
			addClassDeclaration(ast, varNode, className)
		end
	end)
end

print("Loaded DBM mod classes plugin")

return plugin