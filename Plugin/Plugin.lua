local modClasses = require "Mod-Class-Plugin"

function OnTransformAst(uri, ast)
	modClasses:OnTransformAst(uri, ast)
	return ast
end

require "Event-Diagnostic"
require "Sync-Diagnostic"