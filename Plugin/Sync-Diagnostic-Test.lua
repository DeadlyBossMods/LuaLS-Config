local diagTest = require "Diagnostics-Test"

require "Sync-Diagnostic"

local test = diagTest("dbm-sync-checker")

-- Happy path
test [[
	local mod = DBM:NewMod("name")
	function mod:Foo()
		self:SendSync("foo")
	end
	function mod:Bar()
		self:SendSync("bar")
	end
	function mod:OnSync(msg)
		if msg == "foo" then end
		if msg ~= "bar" then return end
	end
]]

-- Sync mismatch
test [[
	local mod = DBM:NewMod("name")
	function mod:Bar()
		self:SendSync(<!"bar"!>)
	end
	function mod:OnSync(msg)
		if <!msg == "foo"!> then end
	end
]]

-- Different mods are different
test [[
	local mod1 = DBM:NewMod("name1")
	local mod2 = DBM:NewMod("name2")
	function mod1:Bar()
		self:SendSync(<!"foo"!>)
	end
	function mod2:OnSync(msg)
		if <!msg == "foo"!> then end
	end
]]
