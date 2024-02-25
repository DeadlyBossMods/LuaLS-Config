local files = require "files"
local catch = require "catch"
local core  = require "core.diagnostics"
local util  = require "utility"

local TESTURI = "file://test.lua"

-- This test setup is heavily inspired by test/diagnostics/init.lua in LuaLS

local function compare(want, got)
    local diff = {}
    for _, target in ipairs(want) do
		local found = false
        for _, result in ipairs(got) do
            if target[1] == result.start and target[2] == result.finish then
                found = true
				break
            end
        end
        if not found then
			diff[#diff + 1] = {
				type = "Expected but didn't get",
				start = target[1],
				finish = target[2],
			}
		end
    end
	for _, result in ipairs(got) do
		local found = false
        for _, target in ipairs(want) do
            if target[1] == result.start and target[2] == result.finish then
                found = true
				break
            end
        end
        if not found then
			diff[#diff + 1] = {
				type = "Got but didn't expect",
				data = result
			}
		end
    end
    return diff
end

return function(diagnostic)
	return function(script)
		local newScript, want = catch(script, "!")
		files.setText(TESTURI, newScript)
		files.open(TESTURI)
		local got = {}
		core(TESTURI, false, function(result)
			if result.code == diagnostic then
				got[#got + 1] = result
			end
		end)
		if #got > 0 then
			local diff = compare(want["!"], got)
			if #diff > 0 then
				error(("Diagnostic mismatch, diff:\n%s"):format(util.dump(diff)), 2)
			end
		elseif #want["!"] > 0 then
			error("expected " .. #want["!"] .. " diagnostics but got 0", 2)
		end
		files.remove(TESTURI)
	end
end
