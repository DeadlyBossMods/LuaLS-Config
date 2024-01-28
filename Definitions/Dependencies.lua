--- Some basic definitions for dependencies we use.
---@meta

---@class LibSerialize
LibSerialize = {}

function LibSerialize:Serialize(str) end
function LibSerialize:Deserialize(str) end


---@class LibDeflate
LibDeflate = {}
function LibDeflate:EncodeForPrint(str) end
function LibDeflate:DecodeForPrint(str) end
function LibDeflate:CompressDeflate(str, options) end
function LibDeflate:DecompressDeflate(str) end


---@class LibDropDownMenu
LibDropDownMenu = {}
function LibDropDownMenu:UIDropDownMenu_SetWidth(frame, newWidth) end
function LibDropDownMenu:UIDropDownMenu_AddButton(info, level) end
function LibDropDownMenu:UIDropDownMenu_Initialize(frame, initFunction, displayMode, level, menuList) end
function LibDropDownMenu:ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button, autoHideDelay, overrideDisplayMode) end
---@class DropdownMenu
---@return DropdownMenu
function LibDropDownMenu:Create_DropDownMenu(name, parent) end