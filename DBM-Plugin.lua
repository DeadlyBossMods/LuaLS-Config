local guide     = require 'parser.guide'
local luadoc    = require 'parser.luadoc'
local astHelper = require 'plugins.astHelper'

-- Not all events have args tables, see DBM-Core:noArgTableEvents
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

print("Loaded DBM-Plugin!")
