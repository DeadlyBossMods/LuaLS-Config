local util = require "Util"

local guide = require "parser.guide"

local function test(script)
	local found = {}
	local state = compile(script)
	util.EachDBMModVar(state, function(varNode, _, modName, modType)
		found[#found + 1] = {node = varNode, name = modName, type = modType}
	end)
	table.sort(found, function(e1, e2) return e1.node.start < e2.node.start end)
	return found
end


local found = test[[
	local mod1 = DBM:NewMod("Foo1")
	local mod2 = DBM:GetModByName("Foo2")
	local mod3 = DBM:GetMod("Foo3")
]]
assert(#found == 3)
assert(found[1].name == "DBMModFoo1")
assert(found[1].type == "NewMod")
assert(found[2].name == "DBMModFoo2")
assert(found[2].type == "GetModByName")
assert(found[3].name == "DBMModFoo3")
assert(found[3].type == "GetMod")

found = test[[
	local mod = DBM:NewMod("Foo" .. bar)
]]
assert(#found == 1)
assert(found[1].name == "DBMModtest") -- URI in testing is file://test.lua

found = test[[
	mod = DBM:NewMod("Foo1")
	foo.bar = DBM:NewMod("Foo2")
	x = {DBM:NewMod("Foo3")}
	y = {["y"] = DBM:NewMod("Foo4")}
	z[5] = DBM:NewMod("Foo5")
]]
assert(#found == 5)
assert(found[1].name == "DBMModFoo1")
assert(found[2].name == "DBMModFoo2")
assert(found[3].name == "DBMModFoo3")
assert(found[4].name == "DBMModFoo4")
assert(found[5].name == "DBMModFoo5")

found = test[[
	local function foo(bar)
		bar = DBM:GetModByName(bar)
	end
]]
assert(#found == 1)
assert(found[1].node.type == "setlocal")

found = test[[
	local mod = DBM:NewMod("Foo")
	function mod:Foo()
	end
	function somethingelse:Foo()
	end
]]
assert(#found == 2)
assert(found[2].name == "DBMModFoo")
assert(found[2].type == "Param")

found = test[[
	local mod = DBM:NewMod("Foo")
	function mod.Foo(self)
	end
	function mod.Bar() -- no params, should match anything
	end
	local function foo(mod) -- param name doesn't matter
	end
	mod.Baz = foo
	mod.Fun = function(self) end
	mod.Num = 5
]]
assert(#found == 4)
for _, f in ipairs(found) do
	assert(f.name == "DBMModFoo")
end
for i = 2, #found do
	assert(found[i].type == "Param")
end

found = test[[
	local mod = DBM:GetModByName("Foo") or DBM:NewMod("Foo")
]]
-- TODO: this isn't ideal, but also not relevant
assert(#found == 2)
assert(found[1].name == "DBMModFoo")
assert(found[1].type == "GetModByName")
assert(found[2].name == "DBMModFoo")
assert(found[2].type == "NewMod")

found = test[[
	DBM:GetModByName("Foo").Options.Bar = 1
]]
assert(#found == 0)

found = test[[
	local function foo(mod)
	end
	foo(DBM:GetModByName("Foo"))
]]
-- TODO: this isn't ideal, but also not relevant
assert(#found == 0)
