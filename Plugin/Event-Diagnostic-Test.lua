
local diagTest = require "Diagnostics-Test"

require "Event-Diagnostic"

local test = diagTest("dbm-event-checker")

-- Happy path, no warnings
test [[
	local mod = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_CAST_START")
	mod:RegisterEventsInCombat("SPELL_CAST_SUCCESS 123")
	mod:RegisterShortTermEvents("SPELL_CAST_FAILED")
	function mod:SPELL_CAST_START()
	end
	function mod:SPELL_CAST_SUCCESS(args)
		if args:IsSpellID(123) then end
	end
	function mod:SPELL_CAST_FAILED(args)
		if args:IsSpellID(456) then end -- No args = register all
	end
]]

-- Event not registered
test [[
	local mod = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_CAST_START")
	function <!mod:SPELL_CAST_FAILED!>()
	end
]]

-- Spell IDs not registered
test [[
	local mod = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_AURA_APPLIED 123")
	function mod:SPELL_AURA_APPLIED(args)
		if args:IsSpell(123, <!456!>) then end
		if args:IsSpellID(123, <!456!>) then end
		if <!args.spellId == 789!> then end
		if <!789 == args.spellId!> then end
		if args.something == 789 then end
		if args:Bar(789) then end
	end
]]

-- Handlers point to another handler
test [[
	local mod = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_AURA_APPLIED 123 456", "SPELL_AURA_APPLIED_DOSE 123")
	function mod:SPELL_AURA_APPLIED(args)
		if args:IsSpellID(123, <!789!>) then end
	end
	mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED
]]

-- Handler is in a separate function
test [[
	local mod = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_AURA_APPLIED 123 456", "SPELL_AURA_APPLIED_DOSE 123 456")
	local function handler(mod, args)
		if args.spellId == 123 or args.spellId == 456 or <!args.spellId == 789!> then end
	end
	mod.SPELL_AURA_APPLIED = handler
	mod.SPELL_AURA_APPLIED_DOSE = handler
]]

-- Multiple mods
test [[
	local mod1 = DBM:NewMod("name1")
	local mod2 = DBM:NewMod("name2")
	mod1:RegisterEvents("SPELL_AURA_APPLIED 123")
	mod2:RegisterEventsInCombat("SPELL_AURA_APPLIED 456")
	function mod1:SPELL_AURA_APPLIED(args)
		if args:IsSpellID(123, <!456!>) then end
	end
	function mod2:SPELL_AURA_APPLIED(args)
		if args:IsSpellID(<!123!>, 456) then end
	end
]]

-- Same mod in multiple variables
-- FIXME: this doesn't pass right now
--[[
test [[
	local mod1 = DBM:NewMod("name")
	local mod2 = DBM:GetModByName("name")
	mod1:RegisterEvents("SPELL_AURA_APPLIED 123")
	mod2:RegisterEventsInCombat("SPELL_AURA_REMOVED 456")
	function mod1:SPELL_AURA_REMOVED(args)
		if args:IsSpellID(<!123!>, 456) then end
	end
	function mod2:SPELL_AURA_APPLIED(args)
		if args:IsSpellID(123, <!456!>) then end
	end
]]

-- Event registration must use literals as arguments
test [[
	local mod = DBM:NewMod("name")
	local foo = "SPELL_AURA_APPLIED"
	mod:RegisterEvents(<!foo!>)
]]

-- Events without arg tables
test [[
	local mod = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_DAMAGE 123")
	function mod:SPELL_DAMAGE(sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId)
		if sourceFlags == 456 then end
		if spellId == 123 or <!spellId == 456!> then end
		if 123 == spellId or <!456 == spellId!> then end
		if spellId == <!sourceFlags!> then end
	end
]]

-- Bad or unsupported event handlers
test [[
	local mod = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_DAMAGE 123")
	mod.SPELL_DAMAGE = <!5!>
	mod.SPELL_DAMAGE = <!SOME_GLOBAL!>
	local x = 5
	mod.SPELL_DAMAGE = <!x!>
	mod.x = 5
	mod.SPELL_DAMAGE = <!mod.x!>
]]

-- Mods in globals aren't supported
test [[
	<!mod!> = DBM:NewMod("name")
	mod:RegisterEvents("SPELL_AURA_APPLIED 123")
	function mod:SPELL_DAMAGE(args)
		if args.spellId == 456 then end -- Passes because globals aren't supported
	end
]]

-- Mods in anything other than locals aren't supported
test [[
	local x = {<!DBM:NewMod("name")!>}
	local y = {<!foo!> = DBM:NewMod("name")}
	local z = {<!["foo"]>! = DBM:NewMod("name")}
	<!x.mod!> = DBM:NewMod("name")
	print<!(DBM:NewMod("name"))!>
	x.mod:RegisterEvents("SPELL_AURA_APPLIED 123")
	function x.mod:SPELL_DAMAGE(args)
		if args.spellId == 456 then end -- Passes
	end
]]
