local mod = {}

local protoDiagnostic = require "proto.diagnostic"
local protoDefine = require "proto.define"

-- Hacky hack to inject a custom diagnostic.
function mod:New(name, func, severity, fileStatus, group)
	severity = severity or "Warning"
	fileStatus = fileStatus or "Opened"
	group = group or "DBM"
	protoDiagnostic.register{name}{group = group, severity = severity, status = fileStatus}
	protoDiagnostic._diagAndErrNames[name] = true
	protoDefine.DiagnosticDefaultSeverity[name] = severity
	protoDefine.DiagnosticDefaultNeededFileStatus[name] = fileStatus
	package.loaded["core.diagnostics." .. name] = func
end

return mod