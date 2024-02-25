-- LuaLS environment setup
local basePath = arg[0]:gsub("[/\\]*[^/\\]-$", "") -- The dir under which this file is
package.path = "./script/?.lua;./script/?/init.lua;./test/?.lua;./test/?/init.lua;"
package.path = package.path .. basePath .. "/?.lua;"
package.path = package.path .. basePath .. "/?/init.lua"
_G.log = require "log"
local fs = require 'bee.filesystem'
ROOT = fs.path(fs.exe_path():parent_path():parent_path():string()) -- The dir under which LuaLS is
TEST = true
DEVELOP = true
LUA_VER = "Lua 5.1"

-- All custom diagnostics must be loaded before diagnostics are invoked for the first ime
require "Event-Diagnostic"
require "Sync-Diagnostic"

require "Event-Diagnostic-Test"
require "Sync-Diagnostic-Test"
