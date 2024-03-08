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
	NoSeason          = 0,
	SeasonOfMastery   = 1,
	SeasonOfDiscovery = 2,
	Hardcore          = 3,
}
--- SeasonID as string, useful as a parameter to avoid having to nil-check every Enum.SeasonID access in functions that take a season as parameter.
---@alias SeasonID "NoSeason" | "SeasonOfMastery" | "SeasonOfDiscovery" | "Hardcore"

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

--- Classic replacement for C_UnitAuras.GetAuraDataByIndex()
---@param unit UnitId
---@param i number
---@return string spellName, number icon, number count, string debuffType, number duration, number expirationTime, string unitCaster, boolean isStealable, boolean nameplateShowPersonal, number spellId, boolean canApplyAura, boolean isBossDebuff, boolean castByPlayer, boolean nameplateShowAll, number timeMod, any value1, any value2, any value3
function UnitAura(unit, i) end

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