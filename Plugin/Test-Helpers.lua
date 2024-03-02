---@diagnostic disable: lowercase-global

local files = require "files"

function dump(tbl, filterKeys, stream, indent, seen, path)
	filterKeys = filterKeys or {}
	stream = stream or io.stdout
	indent = indent or 0
	seen = seen or {}
	path = path or ""
	if type(tbl) ~= "table" or seen[tbl] then
		if type(tbl) == "string" then
			stream:write("\"")
			stream:write((tbl:gsub("\n", "\\n")))
			stream:write("\"")
		elseif type(tbl) == "table" then
			stream:write("<table ")
			stream:write(seen[tbl])
			stream:write(">")
		else
			stream:write(tostring(tbl))
		end
		stream:write(",\n")
		return
	end
	seen[tbl] = path
	stream:write("{\n")
	for k, v in pairs(tbl) do
		if not filterKeys[k] then
			stream:write(("  "):rep(indent + 1))
			stream:write(tostring(k))
			stream:write(" = ")
			dump(v, filterKeys, stream, indent + 1, seen, path .. "." .. tostring(k))
		end
	end
	stream:write(("  "):rep(indent))
	stream:write("},\n")
end

function nodeToString(node)
	if not node then return "<nil>" end
	if not node.type then return "Node(unknown)" end
	local skip = {
		type = true,
		finish = true,
		range = true
	}
	local children = ""
	for k, v in pairs(node) do
		if (type(k) ~= "number" or k > #node) and not skip[k] and not (type(k) == "string" and k:match("^_")) then
			children = children .. (",%s=%s"):format(tostring(k), type(v) == "table" and (v.type and "(" .. v.type ..  ")" or "(table)") or tostring(v))
		end
	end
	return ("Node(%s%s)"):format(node.type, children)
end

function dumpNode(node, stream)
	local stream = stream or io.stdout
	stream:write(nodeToString(node))
	stream:write("\n")
end

local TESTURI = "file://test.lua"

function compile(script)
	files.remove(TESTURI)
	files.setText(TESTURI, script)
	files.open(TESTURI)
	return files.getState(TESTURI)
end
