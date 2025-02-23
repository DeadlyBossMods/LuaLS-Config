-- Definitions missing from ketho.vscode-wow-api for various reasons.
-- These are not specific to it not supporting classic, classic-only definitions are in Classic-Defines.lua
-- This is also not meant for random globals, only for these where the type is useful, e.g., functions or frames.
---@meta

---[Documentation](https://warcraft.wiki.gg/wiki/API_tostringall)
---@param ... any
---@return string ...
function tostringall(...) end

---[Documentation](https://warcraft.wiki.gg/wiki/API_securecall)
---@param func function|string
---@param ... any
function securecall(func, ...) end

--- [Documentation](https://wowpedia.fandom.com/wiki/API_GetNumTalentTabs)
---@param isInspect boolean?
---@param isPet boolean?
---@return number numTabs
function GetNumTalentTabs(isInspect, isPet) end

--- [Documentation](https://wowpedia.fandom.com/wiki/API_GetTalentTabInfo)
---@param index number
---@param isInspect boolean?
---@param isPet boolean?
---@param talentGroup number?
---@return string name
---@return string? texture
---@return number pointsSpent
---@return string fileName
---@return number unknown
function GetTalentTabInfo(index, isInspect, isPet, talentGroup) end

---@type number
MAX_TALENT_TABS = nil
ALTERNATE_POWER_INDEX = 10


-- WoWLua definition is missing return value
---[Documentation](https://warcraft.wiki.gg/wiki/API_C_NamePlate.GetNamePlates)
---@return table nameplates
function C_NamePlate.GetNamePlates(includeForbidden) end


---[Documentation](https://warcraft.wiki.gg/wiki/API_PlayMusic)
---@param musicID number|string
function PlayMusic(musicID) end


--- [Documentation](https://warcraft.wiki.gg/wiki/API_GetLFGMode)
---@param category number
---@param lfgID any?
---@return string mode
---@return string subMode
function GetLFGMode(category, lfgID) end

---Currently missing from WoW API globals, returns Constants.TimerunningConsts value for currently active seasonID
---@return number seasonID
function PlayerGetTimerunningSeasonID() end

---Currently missing from WoW API globals, returns index of current spec
---@return number specIndex
function GetPrimaryTalentTree() end

---@class TimerTracker
TimerTracker = nil
TimerTracker.timerList = {}

---@param tracker TimerTracker
function FreeTimerTrackerTimer(tracker) end

---@param self TimerTracker
---@param event string
---@param ... any
function TimerTracker_OnEvent(self, event, ...) end

---@class ColorPickerFrame
ColorPickerFrame = nil

---@param stuff table
function ColorPickerFrame:SetupColorPickerAndShow(stuff) end

---@return number r
---@return number g
---@return number b
function ColorPickerFrame:GetColorRGB() end

---@param rgbR number
---@param rgbG number
---@param rgbB number
function ColorPickerFrame:SetColorRGB(rgbR, rgbG, rgbB) end

-- Weird locale selectors we use during startup instead of GetLocale() for some reason.
---@type number?
LOCALE_koKR = nil
---@type number?
LOCALE_zhCN = nil
---@type number?
LOCALE_zhTW = nil
---@type number?
LOCALE_ruRU = nil

---@type table<string, function>
SlashCmdList = {}

---@type frame
WorldFrame = nil

---@type Frame
AlertFrame = nil

---@type Frame
RaidBossEmoteFrame = nil

---@type Frame
RolePollPopup = nil

---@type MovieFrame
MovieFrame = nil
function CinematicFrame_CancelCinematic() end


---@type MessageFrame
DEFAULT_CHAT_FRAME = nil

---@return EditBox frame
function ChatEdit_GetActiveWindow() end


---@param id string
---@return table frame
function StaticPopup_Show(id) end

---@param id string
function StaticPopup_Hide(id) end

---@param tooltip any
---@param text string
function GameTooltip_SetTitle(tooltip, text) end

---@type table<string, table>
StaticPopupDialogs = nil

---@type number
STATICPOPUP_NUMDIALOGS = nil

---@type string
PLAYER_DIFFICULTY_STORY_RAID = nil

---@overload fun(): ... any
---@return any ... Current CLEU args.
function CombatLogGetCurrentEventInfo() end

function HandleLuaError(errorMessage) end

---@class FontString
local FontString = {}

---[Documentation](https://warcraft.wiki.gg/wiki/API_FontString_SetFormattedText)
---@param text string
---@param ... any
function FontString:SetFormattedText(text, ...) end