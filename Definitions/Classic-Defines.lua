-- Classic-only defines that are currently missing from https://github.com/Ketho/vscode-wow-api
---@meta

--- Only available in Classic.
---@type table? -- doesn't trigger nil check, see https://github.com/LuaLS/lua-language-server/issues/2450
C_GameRules = nil

--- [Documentation](https://warcraft.wiki.gg/wiki/API_C_GameRules.IsHardcoreActive)
--- Only available in Classic.
---@return boolean
function C_GameRules.IsHardcoreActive() end


---@type table?
C_Seasons = nil

--- [Documentation](https://warcraft.wiki.gg/wiki/API_C_Seasons.HasActiveSeason)
--- Only available in Classic.
---@return boolean
function C_Seasons.HasActiveSeason() end

--- Only available in Classic.
---@enum Enum.SeasonID
Enum.SeasonID = {
	NoSeason        = 0,
	SeasonOfMastery = 1,
	--- Season of Discovery
	Placeholder     = 2,
	Hardcore        = 3,
}

--- [Documentation](https://warcraft.wiki.gg/wiki/API_C_Seasons.GetActiveSeason)
--- Only available in Classic.
---@return Enum.SeasonID
function C_Seasons.GetActiveSeason() end


--- [Documentation](https://warcraft.wiki.gg/wiki/API_C_LFGInfo.GetDungeonInfo)
--- Only available in Classic.
--- Caution: Classic has C_LFGInfo, but GetDungeonInfo is missing there.
---@param lfgDungeonID number
---@return string name
---@return number? iconID
---@return string? link
function GetDungeonInfo(lfgDungeonID) end


--- Classic variant of UnitInPhaseReason()
---@param unit UnitId
---@return boolean
function UnitInPhase(unit) end

--- Classic variant of UnitFactionGroup()
---@param unit UnitId
---@return string
function GetPlayerFactionGroup(unit) end


--- [Documentation](https://wowpedia.fandom.com/wiki/API_GetNumTrackedAchievements)
---@return number
function GetNumTrackedAchievements() end


---@type Frame?
WatchFrame = nil

---@type Frame?
QuestWatchFrame = nil

function ObjectiveTracker_Expand() end