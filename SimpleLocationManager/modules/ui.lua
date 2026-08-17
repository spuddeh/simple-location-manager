-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Simple Location Manager UI module.
-- Mod Version: 1.7.0
-- Credits: psiberx (CET Kit), community
-------------------------------------------------------------------

local UI = {}
local Logic = require("modules/logic")
local Utils = require("modules/utils")
local Impex = require("modules/impex")
local IconPicker = require("modules/icon_picker")
local Env = require("modules/env")
local Loc = require("modules/loc")

-- Bound once rather than called as Loc.L, because it is on nearly every line that
-- draws anything and the shorter name is what keeps those lines readable.
local L = Loc.L

local MOD_NAME = "Simple Location Manager"
local MOD_VERSION = "1.7.0"
local MODAL_PREFIX = "SLM - "

-- Icon a category gets when it is created without one being picked.
local DEFAULT_NEW_CATEGORY_ICON = "Star"

-- What a setting STORES is an English word; what a combo SHOWS is a translation of it.
-- The two are kept apart because comparing the stored value against the label would make
-- every one of these controls forget its own selection outside English.
local GROUP_BY_VALUES = { "District", "Category", "A-Z" }
local GROUP_BY_KEYS = {
    ["District"] = "groupBy.district",
    ["Category"] = "groupBy.category",
    ["A-Z"] = "groupBy.alphabetical",
}

local GROUP_STATE_VALUES = { "Expanded", "Collapsed" }
local GROUP_STATE_KEYS = {
    ["Expanded"] = "groupState.expanded",
    ["Collapsed"] = "groupState.collapsed",
}

---@param value string A stored groupBy value
---@return string label
local function GroupByLabel(value)
    return L(GROUP_BY_KEYS[value] or "groupBy.district")
end

---@param value string A stored defaultGroupState value
---@return string label
local function GroupStateLabel(value)
    return L(GROUP_STATE_KEYS[value] or "groupState.expanded")
end

-- Window Utils is optional. Where it is absent, `wu` is ImGui itself and the window
-- behaves exactly as it does without the library, so nothing here is a dependency.
-- Resolved on the first draw rather than in Init, because every CET mod has loaded
-- by the time onDraw first fires.
local wu = nil
local function ResolveWindowUtils()
    if wu then return wu end

    wu = GetMod("WindowUtils") or ImGui

    -- Per-window config is the fallback the library reads while its master toggle is
    -- off, which is its shipped state. Stating the values here rather than inheriting
    -- them means SLM keeps this feel even if the library's own defaults move.
    if wu.SetWindowConfig then
        wu.SetWindowConfig(MOD_NAME, {
            gridEnabled = true,
            animationEnabled = true,
            animationDuration = 0.2,
            easeFunction = "easeOut",
            snapCollapsed = true
        })
    end

    return wu
end

-- UI State
local isOverlayOpen = false     -- Tracks if the CET overlay is currently visible
local searchQuery = ""          -- Current search text in the main location list
local filteredLocationCount = 0 -- QOL: Store filtered count for footer
local activeTab = "Locations"   -- Current active tab in the main window
local lastDebugInfo = nil       -- Stores the last printed debug info string
local lastDistrictInfo = nil    -- Stores the last dumped district info string

-- Footer readout, sampled in UI.Draw. It has to be sampled where it is drawn: a timer
-- driven by onUpdate would stop while the CET overlay is open, which is the only time
-- the footer is on screen.
local envReadout = nil

-- Group expand/collapse persistence (survives search filtering).
--
-- This table is AUTHORITATIVE. Every header is told its state with SetNextItemOpen on
-- every frame rather than reading back whatever ImGui kept, and the returned value is
-- written straight back here so a click by the user still lands. Left in ImGui's own
-- storage, the state of a group that nothing had touched could come back collapsed.
local groupOpenState = {}           -- Open/closed state per group key

local forceExpand = false           -- Expand every group on the next frame, then clears
local forceCollapse = false         -- Collapse every group on the next frame, then clears

--- Assert a group's open state on the header that follows.
---
--- Precedence: an explicit Expand/Collapse All, then a live search, which opens every group so
--- the matches are visible, then this group's remembered state, then the default for a group
--- that has none.
---@param key string
local function ApplyGroupOpenState(key)
    local state
    if forceExpand then
        state = true
    elseif forceCollapse then
        state = false
    elseif searchQuery ~= "" then
        state = true
    elseif groupOpenState[key] ~= nil then
        state = groupOpenState[key]
    else
        state = (Logic.settings.defaultGroupState ~= "Collapsed")
    end

    ImGui.SetNextItemOpen(state)
end

--- Record what the header returned, so a click by the user survives to the next frame.
--- A searching frame is skipped: a group open because of the filter is not one the user
--- opened, so clearing the search returns every group to the state it was left in.
---@param key string
---@param isOpen boolean
local function RecordGroupOpenState(key, isOpen)
    if searchQuery == "" then
        groupOpenState[key] = isOpen
    end
end


-- Modal Flags & State
local editingId = nil            -- ID of the location currently being edited (Edit Modal)
local pendingNewLocation = nil   -- Temp location object for "New Location" (before save)
local confirmDeleteId = nil      -- ID of the location pending deletion (Delete Confirmation Modal)
local confirmDeleteAll = false   -- Flag for "Delete All Locations" confirmation modal
local showResetConfirm = false   -- Flag for "Reset Settings" confirmation modal
local showDuplicateModal = false -- Flag for "Duplicate Location" warning modal
local duplicateWarningName = ""  -- Name of the location causing the duplicate warning
local duplicateWarningId = nil   -- ID of the location causing the duplicate warning
local updateConfirmId = nil      -- ID of the location pending a position update (Update Confirmation Modal)

-- Group-state diagnostic. Armed by an action under suspicion, it records only the frames on
-- which a group's open/closed state CHANGES, with the inputs the decision was made from. It
-- reads the decision and takes no part in it, so the behaviour under test is unchanged.
-- Declared below every value it reads, so those are upvalues rather than globals.

-- Export Selection State
local showExportSelectModal = false -- Flag for the "Export Selected" modal
local exportSelection = {}          -- Set of selected location ids
local exportSelectSearch = ""       -- Filter inside the modal, separate from the main search

-- Import System State
local showImportRed = false -- Flag for the Import Data modal
local importReport = nil    -- Stores the result report of the last import operation
local importString = ""     -- Buffer for the import string input field

-- Preset Cleanup State
local showPresetCleanupModal = false -- Flag for the "Remove Preset Locations" modal
local presetOrphans = {}             -- Snapshot of orphaned presets, taken when the modal opens
local presetCleanupSelection = {}    -- Set of preset file names ticked for removal
local presetCleanupDeleteEdited = false -- Delete edited locations rather than keeping them

-- Unused Category Cleanup State
local showCategoryCleanupModal = false -- Flag for the "Remove Unused Categories" modal
local unusedCategories = {}            -- Snapshot of unused custom categories, taken on open
local categoryCleanupSelection = {}    -- Set of category names ticked for removal

-- Category Management State
local showCategoryModal = false         -- Flag for Add/Edit Category modal
local showDeleteCategoryModal = false   -- Flag for Delete Category confirmation modal
local categoryToDelete = nil            -- Name of the category pending deletion
local newCatName = ""                   -- Buffer for new/edited category name
local newCatIcon = "NewBox"             -- Buffer for new/edited category icon
local isEditingCategory = false         -- Flag to distinguish between Creating vs Editing a category
local editingCategoryOriginalName = nil -- Stores original name when editing to handle renames

-- Temporary Edit Buffers (used in Edit Modal)
local tempName = ""
local tempDesc = ""
local tempCategory = "Misc"
local tempCategoryIcon = nil     -- Icon chosen for a category being typed for the first time
local showTempCatPicker = false  -- Inline icon picker open, in the Edit modal
local tempEnvEnabled = false     -- "Save time and weather with this location"
local tempEnvTimeEnabled = true  -- Off leaves the time of day alone
local tempEnvHour = 12
local tempEnvMinute = 0
local tempEnvWeather = ""        -- Weather state id, "" leaves the weather alone

-- Manual Coordinates Modal State
local showManualModal = false       -- Flag for the Manual Coordinates modal
local manualPaste = ""              -- Smart paste buffer (auto-parsed on change)
local manualLastPaste = ""          -- Previous frame's paste value (change detection)
local manualX = 0.0
local manualY = 0.0
local manualZ = 0.0
local manualYaw = 0.0
local manualName = "Manual Location"
local manualCategory = "Misc"
local manualCategoryIcon = nil      -- Icon chosen for a category being typed for the first time
local showManualCatPicker = false   -- Inline icon picker open, in the Manual Coordinates modal



--- Initialize UI
function UI.Init(logicModule)
    Logic = logicModule
end

--- Generic Modal Wrapper Helper
--- @param titleSuffix string The modal title (prefix added automatically)
--- @param shouldOpen boolean|nil Condition to force open the popup
--- @param flags number|nil ImGuiWindowFlags (default: AlwaysAutoResize)
--- @param renderContent function Callback to render the modal body
--- @param options table|nil Optional overrides: { onClose = func, onPreOpen = func }
function UI.WrapperModal(titleSuffix, shouldOpen, flags, renderContent, options)
    local fullTitle = MODAL_PREFIX .. titleSuffix
    flags = flags or ImGuiWindowFlags.AlwaysAutoResize
    options = options or {}

    -- Handle Open Logic
    if shouldOpen then
        if not ImGui.IsPopupOpen(fullTitle) then
            -- Pre-Open hook (e.g. SetNextWindowSize)
            if options.onPreOpen then options.onPreOpen() end
            ImGui.OpenPopup(fullTitle)
        end
    end

    -- Draw Modal
    -- onPreOpen runs every frame, before BeginPopupModal: SetNextWindowSize only applies to the
    -- next window begun, and the popup still has to render on frames where shouldOpen is false.
    if options.onPreOpen then options.onPreOpen() end

    -- Centred on every appearance. ImGui files a window's position under its TITLE, and a
    -- modal that draws two sizes under one title - a list, and a line saying there is
    -- nothing to list - otherwise opens the small state wherever the large one last sat.
    -- Appearing rather than Always, so dragging it still works once it is open.
    local screenW, screenH = GetDisplayResolution()
    ImGui.SetNextWindowPos(screenW * 0.5, screenH * 0.5, ImGuiCond.Appearing, 0.5, 0.5)

    if ImGui.BeginPopupModal(fullTitle, true, flags) then
        renderContent()
        ImGui.EndPopup()
    else
        -- External Close Detection
        if shouldOpen and not ImGui.IsPopupOpen(fullTitle) then
            if options.onClose then options.onClose() end
        end
    end
end

function UI.OnOverlayOpen()
    isOverlayOpen = true
    -- A different save can load a different environment definition, so the weather
    -- state list is rebuilt rather than carried across.
    Env.InvalidateCache()

    -- The game's language is readable by now even though it was not at init, and the
    -- player can change it mid-session with nothing telling a CET mod that they did.
    -- Checked here because it is the moment before any of this text is drawn.
    Loc.Refresh(Logic.settings.language)
end

function UI.OnOverlayClose()
    isOverlayOpen = false
end

--- Exports data to clipboard and notifies user
local function OpenExport(title, dataStr)
    if not dataStr then
        Utils.NotifyWarning(L("export.nothingToExport"))
        return
    end

    -- Copy to Clipboard
    ImGui.SetClipboardText(dataStr)

    -- Notifications
    Utils.Notify(L("export.copiedToClipboard", title))

    -- Verbose Console Log
    Utils.Print(title)
    Utils.Print("Export string copied to clipboard.")
end

local importOpenCount = 0

--- Draw Import Modal
local function DrawImportModal()
    -- Held in a local because onPreOpen below has to name the same popup, and a
    -- second copy of the title would drift from this one the moment it is translated.
    local title = L("import.importData")
    UI.WrapperModal(title, showImportRed, ImGuiWindowFlags.AlwaysAutoResize, function()
        if ImGui.BeginTabBar("ImportTabs" .. importOpenCount) then
            -- TAB 1: String Import (Paste)
            if ImGui.BeginTabItem(L("import.stringImport")) then
                ImGui.Spacing()
                ImGui.Text(L("import.pasteTextHereSlmExport"))

                -- Single Line Input with Clear Button
                local changed
                ImGui.PushItemWidth(740)
                importString, changed = ImGui.InputText("##importStr", importString, 1024 * 1024)
                ImGui.PopItemWidth()
                ImGui.SameLine()
                if ImGui.Button(IconGlyphs.Eraser) then
                    importString = ""
                end

                ImGui.Spacing()

                if ImGui.Button(IconGlyphs.Download .. L("import.processImport")) then
                    -- call Impex.ProcessImport (returns data, sourceType, err)
                    local data, sourceType, err, customCats = Impex.ProcessImport(importString)
                    if not data then
                        importReport = { imported = 0, skipped = 0, logs = { "[ERROR] " .. tostring(err) } }
                    else
                        -- call Impex.ProcessImportDataArray
                        importReport = Impex.ProcessImportDataArray(data, sourceType, "Manual Input", customCats)
                        importString = "" -- Clear input on success
                    end
                end

                ImGui.EndTabItem()
            end

            -- TAB 2: AMM Bulk Import
            if ImGui.BeginTabItem(L("import.ammBulkImport")) then
                ImGui.Spacing()
                ImGui.TextWrapped(L("import.bulkImportJsonFilesFrom"))
                ImGui.TextWrapped(L("import.filesMustBeLocatedIn"))
                ImGui.TextColored(0.5, 1.0, 1.0, 1.0,
                    L("import.binPluginsCyberEngineTweaks"))
                ImGui.TextWrapped(
                    L("import.youMustManuallyCopyAmm"))


                ImGui.Spacing()

                if ImGui.Button(IconGlyphs.FolderSearch .. L("import.scanDirectoryImport")) then
                    local path = Impex.AMM_LOCATIONS_PATH
                    importReport = Impex.ImportFromAMMDirectory(path)
                end

                ImGui.EndTabItem()
            end

            ImGui.EndTabBar()
        end

        ImGui.Separator()

        -- Report Area (Shared)
        if importReport then
            ImGui.TextColored(0.0, 1.0, 0.0, 1.0,
                L("import.importedSkipped", importReport.imported, importReport.skipped))

            if ImGui.BeginChild("ImportLog", 0, 200, true) then
                for _, log in ipairs(importReport.logs) do
                    -- Color code errors
                    if string.find(log, "Error") or string.find(log, "Skipped") then
                        ImGui.TextColored(1.0, 0.5, 0.5, 1.0, log)
                    else
                        ImGui.TextWrapped(log)
                    end
                end
                ImGui.EndChild()
            end
        end

        ImGui.Spacing()

        -- Close Button (Bottom Right)
        local w = ImGui.GetWindowWidth()
        ImGui.SetCursorPosX(w - 120) -- Rough align right
        if ImGui.Button(L("import.close"), 100, 0) then
            showImportRed = false
            importString = ""
            importReport = nil
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            showImportRed = false
            importString = ""
            importReport = nil
        end,
        onPreOpen = function()
            if not ImGui.IsPopupOpen(MODAL_PREFIX .. title) then
                importOpenCount = importOpenCount + 1
            end
        end
    })
end

--- Helper: Sort Locations Alphabetically (Case-Insensitive)
local function SortLocationByName(a, b)
    local na = (a.name or ""):lower()
    local nb = (b.name or ""):lower()
    return na < nb
end

--- Locations matching the export modal's own filter, sorted by name.
--- The filter reuses Logic.CheckSearch, so it matches on the same fields as the main list.
---@return table
local function GetExportCandidates()
    local list = {}
    for _, loc in ipairs(Logic.locations) do
        if exportSelectSearch == "" or Logic.CheckSearch(loc, exportSelectSearch) then
            table.insert(list, loc)
        end
    end
    table.sort(list, SortLocationByName)
    return list
end

--- Draw the "Export Selected" modal: pick locations, get one export string for the lot.
local function DrawExportSelectModal()
    local shouldOpen = showExportSelectModal
    if shouldOpen then ImGui.SetNextWindowSize(560, 0, ImGuiCond.Always) end

    UI.WrapperModal(L("exportSelect.title"), shouldOpen, ImGuiWindowFlags.NoResize, function()
        local candidates = GetExportCandidates()

        -- Filter
        local style = ImGui.GetStyle()
        local clearBtnW = ImGui.CalcTextSize(IconGlyphs.Eraser) + (style.FramePadding.x * 2)
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail() - clearBtnW - style.ItemSpacing.x)
        exportSelectSearch = ImGui.InputTextWithHint("##exportSearch",
            IconGlyphs.Magnify .. L("exportSelect.filterLocations"), exportSelectSearch, 100)
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Eraser) then exportSelectSearch = "" end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("exportSelect.clearFilter")) end

        -- Bulk actions apply to what the filter is showing, not to everything.
        if ImGui.Button(IconGlyphs.CheckAll .. L("exportSelect.selectShown")) then
            for _, loc in ipairs(candidates) do exportSelection[loc.id] = true end
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.CloseBoxMultipleOutline .. L("exportSelect.deselectShown")) then
            for _, loc in ipairs(candidates) do exportSelection[loc.id] = nil end
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Eraser .. L("exportSelect.clearAll")) then
            exportSelection = {}
        end

        ImGui.Separator()

        if #candidates == 0 then
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0, L("exportSelect.noLocationsMatchThatFilter"))
        end

        if ImGui.BeginChild("ExportSelectList", 0, 320, true, 0) then
            for _, loc in ipairs(candidates) do
                ImGui.PushID("exp_" .. loc.id)

                local checked = exportSelection[loc.id] == true
                local newChecked, changed = ImGui.Checkbox("##pick", checked)
                if changed then
                    exportSelection[loc.id] = newChecked or nil
                end

                ImGui.SameLine()
                local catIcon = "DotsCircle"
                for _, c in ipairs(Logic.GetCategories()) do
                    if c.name == loc.category then
                        catIcon = c.icon
                        break
                    end
                end
                ImGui.Text((IconGlyphs[catIcon] or IconGlyphs.Help) .. " " .. (loc.name or L("exportSelect.unnamed")))

                local districtStr = (loc.district or "Unknown")
                if loc.subDistrict and loc.subDistrict ~= "" then
                    districtStr = districtStr .. " (" .. loc.subDistrict .. ")"
                end
                ImGui.SameLine()
                ImGui.TextColored(0.5, 0.5, 0.5, 1.0, L("exportSelect.districtLine", districtStr))

                ImGui.PopID()
            end
            ImGui.EndChild()
        end

        -- Count what is selected across the whole list, not just the filtered view, so
        -- narrowing the filter cannot make a selection look smaller than it is.
        local selectedList = {}
        for _, loc in ipairs(Logic.locations) do
            if exportSelection[loc.id] then table.insert(selectedList, loc) end
        end

        ImGui.Separator()
        ImGui.AlignTextToFramePadding()
        ImGui.Text(L("exportSelect.selectedCount", #selectedList))
        ImGui.SameLine()

        ImGui.BeginDisabled(#selectedList == 0)
        if ImGui.Button(IconGlyphs.ContentCopy .. L("exportSelect.copyExportString")) then
            local data, count = Impex.ExportList(selectedList)
            if data then
                OpenExport(L("exportSelect.exportSelectedTitle", count), data)
                showExportSelectModal = false
                ImGui.CloseCurrentPopup()
            else
                Utils.NotifyWarning(L("exportSelect.nothingToExport"))
            end
        end
        ImGui.EndDisabled()
        if ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled) then
            ImGui.SetTooltip(L("exportSelect.copyExportTooltip"))
        end

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            showExportSelectModal = false
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            showExportSelectModal = false
        end
    })
end

--- Fill the time/weather buffers from a location, or from the game where it has none.
---@param loc table|nil
local function SeedEnvBuffers(loc)
    local env = loc and loc.env

    tempEnvEnabled = env ~= nil
    tempEnvTimeEnabled = (env == nil) or (env.time ~= nil)
    tempEnvWeather = (env and env.weather) or ""

    local time = (env and env.time) or Env.GetCurrentTime()
    tempEnvHour = (time and time.h) or 12
    tempEnvMinute = (time and time.m) or 0

    if not env then
        tempEnvWeather = Env.GetCurrentWeather() or ""
    end
end

--- Build the env block the buffers describe, or nil when the section is switched off.
--- Time and weather are independent, so a location can carry either alone. With both
--- switched off there is nothing to record and the result is nil, not an empty block -
--- an empty one would show a padlock row that does nothing.
---@return table|nil
local function BuildEnvFromBuffers()
    if not tempEnvEnabled then return nil end
    if not tempEnvTimeEnabled and tempEnvWeather == "" then return nil end

    local env = {}
    if tempEnvTimeEnabled then
        env.time = { h = tempEnvHour, m = tempEnvMinute, s = 0 }
    end
    if tempEnvWeather ~= "" then
        env.weather = tempEnvWeather
    end
    return env
end

--- Draw the "Time & Weather" section of the Edit modal.
local function DrawEnvSection()
    tempEnvEnabled = ImGui.Checkbox(L("env.saveTimeAndWeather"), tempEnvEnabled)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("env.setTheTimeOfDay"))
    end

    if not tempEnvEnabled then return end

    ImGui.Indent(20)

    -- Time. The checkbox is the counterpart of the weather picker's "Leave as is":
    -- either half can be saved without the other.
    tempEnvTimeEnabled = ImGui.Checkbox("##envTimeOn", tempEnvTimeEnabled)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("env.offLeavesTheTimeOf"))
    end
    ImGui.SameLine()

    ImGui.AlignTextToFramePadding()
    ImGui.Text(L("env.time"))
    ImGui.SameLine()

    ImGui.BeginDisabled(not tempEnvTimeEnabled)
    ImGui.SetNextItemWidth(80)
    tempEnvHour = ImGui.SliderInt("##envHour", tempEnvHour, 0, 23)
    ImGui.SameLine()
    ImGui.Text(":")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(80)
    tempEnvMinute = ImGui.SliderInt("##envMinute", tempEnvMinute, 0, 59)
    ImGui.EndDisabled()

    if not tempEnvTimeEnabled then
        ImGui.SameLine()
        ImGui.TextColored(0.6, 0.6, 0.6, 1.0, L("env.leaveAsIs"))
    end

    -- Weather
    local weatherAvailable = Env.IsWeatherAvailable()
    local states = weatherAvailable and Env.GetWeatherStates() or {}

    ImGui.AlignTextToFramePadding()
    ImGui.Text(L("env.weather"))
    ImGui.SameLine()

    ImGui.BeginDisabled(not weatherAvailable)
    ImGui.SetNextItemWidth(220)

    local preview = (tempEnvWeather == "") and "Leave as is" or Env.GetWeatherLabel(tempEnvWeather)
    if ImGui.BeginCombo("##envWeather", preview) then
        if ImGui.Selectable(L("env.leaveAsIs"), tempEnvWeather == "") then
            tempEnvWeather = ""
        end
        for _, state in ipairs(states) do
            if ImGui.Selectable(state.label, state.id == tempEnvWeather) then
                tempEnvWeather = state.id
            end
        end
        ImGui.EndCombo()
    end
    ImGui.EndDisabled()

    if not weatherAvailable then
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0, L("env.weatherNeedsCodewareTimeStill"))
    elseif tempEnvWeather ~= "" and not Env.HasWeatherState(tempEnvWeather) then
        -- The location came from a playthrough with a weather mod this one does not
        -- have. The id is kept so it works again once that mod is reinstalled.
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0, L("env.notInstalledThisWeatherWill"))
    end

    ImGui.Spacing()
    if ImGui.Button(IconGlyphs.MapClock .. L("env.useCurrent")) then
        local now = Env.Capture()
        if now then
            tempEnvTimeEnabled = true
            tempEnvHour = now.time.h
            tempEnvMinute = now.time.m
            tempEnvWeather = now.weather or ""
        end
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("env.copyTheGameCurrentTime")) end

    -- Both halves off records nothing, so say so rather than saving an empty block.
    if not tempEnvTimeEnabled and tempEnvWeather == "" then
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0,
            L("env.nothingSelectedThisLocationWill"))
        ImGui.PopTextWrapPos()
    end

    ImGui.Unindent(20)
end

--- Draw the Edit Location Modal
local function DrawEditModal()
    local shouldOpen = (editingId ~= nil)

    -- SetNextWindowSize pins the initial width so AlwaysAutoResize cannot run away.
    if shouldOpen then ImGui.SetNextWindowSize(500, 0, ImGuiCond.Appearing) end

    UI.WrapperModal(L("edit.title"), shouldOpen, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text(L("edit.name"))
        tempName = ImGui.InputText("##name", tempName, 100)

        ImGui.Text(L("edit.description"))
        ImGui.SetNextItemWidth(-1)
        -- 3 lines high, 500 char limit.
        -- Dynamic width, now that the window size is constrained.
        tempDesc = ImGui.InputTextMultiline("##desc", tempDesc, 500, ImGui.GetContentRegionAvail(),
            ImGui.GetTextLineHeight() * 4)

        -- QOL: Char Counter
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.5, 1.0)
        local len = string.len(tempDesc)

        -- Use ContentRegionAvail to align right
        local avail = ImGui.GetContentRegionAvail()
        local txt = len .. " / 500"
        local txtW = ImGui.CalcTextSize(txt)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + avail - txtW)
        ImGui.Text(txt)
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.Separator()

        -- Category
        ImGui.Text(L("edit.category"))
        ImGui.SameLine()
        -- Fetch icon for tempCategory. A name that matches no category is one the user is
        -- typing now, and its icon is theirs to choose.
        local currentCatIcon = nil
        for _, c in ipairs(Logic.GetCategories()) do
            if c.name == tempCategory then
                currentCatIcon = c.icon
                break
            end
        end
        local isNewCategory = (currentCatIcon == nil and tempCategory ~= "")
        if isNewCategory then
            currentCatIcon = tempCategoryIcon or DEFAULT_NEW_CATEGORY_ICON
        end
        local glyph = IconGlyphs[currentCatIcon or "Help"] or IconGlyphs.Help

        ImGui.AlignTextToFramePadding()
        if isNewCategory then
            -- Existing categories own their icon: it is changed in the Category Manager, not here.
            if ImGui.Button(glyph .. "##catIconBtn") then
                showTempCatPicker = not showTempCatPicker
                IconPicker.ClearSearch()
            end
            if ImGui.IsItemHovered() then ImGui.SetTooltip(L("category.chooseIconFor", tempCategory)) end
        else
            ImGui.Text(glyph .. " ")
            showTempCatPicker = false
        end
        ImGui.SameLine()

        ImGui.SetNextItemWidth(200)
        tempCategory = ImGui.InputText("##catInput", tempCategory, 50)
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("edit.typeNewCategoryNameOr")) end
        ImGui.SameLine()

        -- Category Dropdown
        ImGui.SetNextItemWidth(20)
        if ImGui.BeginCombo("##catSelect", "", ImGuiComboFlags.NoPreview) then
            local allCats = Logic.GetCategories()
            for _, c in ipairs(allCats) do
                local icon = IconGlyphs[c.icon] or IconGlyphs.Help
                if ImGui.Selectable(icon .. " " .. c.name, false) then
                    tempCategory = c.name
                    tempCategoryIcon = nil
                    showTempCatPicker = false
                end
            end
            ImGui.EndCombo()
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("edit.selectExistingCategory")) end

        if isNewCategory and showTempCatPicker then
            IconPicker.Draw(currentCatIcon, function(iconName)
                tempCategoryIcon = iconName
                showTempCatPicker = false
                IconPicker.ClearSearch()
            end, 200)
        end

        ImGui.Separator()

        -- Location Details
        if editingId then
            local loc
            if editingId == "NEW" then
                loc = pendingNewLocation -- Use temp object
            else
                loc = Logic.GetLocation(editingId)
            end

            if loc then
                if loc.district then
                    ImGui.TextColored(0.7, 0.7, 0.7, 1.0, loc.district)
                    if loc.subDistrict and loc.subDistrict ~= "" then
                        ImGui.SameLine()
                        ImGui.TextColored(0.5, 0.5, 0.5, 1.0, L("common.parenthesised", loc.subDistrict))
                    end
                end
                if loc.pos then
                    local cStr = string.format("X: %.1f, Y: %.1f, Z: %.1f", loc.pos.x, loc.pos.y, loc.pos.z)
                    ImGui.TextColored(0.5, 0.5, 0.5, 1.0, cStr)
                end
            end
        end

        ImGui.Separator()

        DrawEnvSection()

        ImGui.Separator()

        if ImGui.Button(IconGlyphs.ContentSave .. L("edit.save")) then
            -- Auto-add category if new
            local exists = false
            for _, c in ipairs(Logic.GetCategories()) do
                if c.name == tempCategory then
                    exists = true; break
                end
            end
            if not exists and tempCategory ~= "" then
                Logic.AddCategory(tempCategory, tempCategoryIcon or DEFAULT_NEW_CATEGORY_ICON)
            end

            if editingId then
                if editingId == "NEW" then
                    -- Commit the new location now
                    if pendingNewLocation then
                        pendingNewLocation.name = tempName
                        pendingNewLocation.description = tempDesc
                        pendingNewLocation.category = tempCategory
                        pendingNewLocation.env = BuildEnvFromBuffers()
                        Logic.AddLocation(pendingNewLocation) -- Save to DB
                        Utils.Notify(L("edit.savedNewLocation", tempName))
                    end
                else
                    Logic.UpdateLocation(editingId, tempName, tempDesc, nil, tempCategory)
                    Logic.SetLocationEnv(editingId, BuildEnvFromBuffers())
                end

                editingId = nil
                pendingNewLocation = nil
                ImGui.CloseCurrentPopup()
            end
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            editingId = nil
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            editingId = nil
        end
    })
end

--- Draw Update Confirmation Modal
local function DrawUpdateConfirmModal()
    local shouldOpen = (updateConfirmId ~= nil)
    UI.WrapperModal(L("updateConfirm.updatePosition"), shouldOpen, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text(L("updateConfirm.updateLocationPositionToCurrent"))
        ImGui.TextColored(0.7, 0.7, 0.7, 1.0, L("updateConfirm.nameAndDescriptionWillBe"))
        ImGui.Spacing()

        if ImGui.Button(L("updateConfirm.yesUpdate")) then
            Logic.UpdateLocationPosition(updateConfirmId)
            updateConfirmId = nil
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            updateConfirmId = nil
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            updateConfirmId = nil
        end
    })
end

--- Draw Delete Confirmation Modal
local function DrawDeleteConfirmModal()
    local shouldOpen = (confirmDeleteId ~= nil)
    UI.WrapperModal(L("deleteConfirm.title"), shouldOpen, ImGuiWindowFlags.AlwaysAutoResize, function()
        if not confirmDeleteId then return end
        local loc = Logic.GetLocation(confirmDeleteId)
        ImGui.Text(L("deleteConfirm.areYouSureYouWant"))
        if loc then
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0, loc.name or L("deleteConfirm.unknownLocation"))
            if Logic.settings.showDistrict then
                local fullDistrictName = loc.district or "Unknown"
                if loc.subDistrict and loc.subDistrict ~= "" then
                    fullDistrictName = fullDistrictName .. " (" .. loc.subDistrict .. ")"
                end
                ImGui.TextColored(0.7, 0.7, 0.7, 1.0, tostring(fullDistrictName))
            end

            if Logic.settings.showCoords and loc.pos then
                local cStr = string.format("X: %.0f, Y: %.0f, Z: %.0f", loc.pos.x, loc.pos.y, loc.pos.z)
                ImGui.TextColored(0.5, 0.5, 0.5, 1.0, cStr)
            end
        end
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, L("deleteConfirm.thisActionCannotBeUndone"))
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Delete .. L("deleteConfirm.yesDelete")) then
            Logic.DeleteLocation(confirmDeleteId)
            confirmDeleteId = nil
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            confirmDeleteId = nil
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            confirmDeleteId = nil
        end
    })
end

--- Prepare and open the edit modal
local function OpenEditModal(loc)
    editingId = loc.id
    tempName = loc.name
    tempDesc = loc.description or ""
    tempCategory = loc.category or "Misc"
    tempCategoryIcon = nil
    showTempCatPicker = false
    SeedEnvBuffers(loc)
end

--- Prepare and open edit modal for NEW location
local function OpenCreateModal(locData)
    editingId = "NEW"
    pendingNewLocation = locData
    tempName = locData.name
    tempDesc = locData.description or ""
    tempCategory = locData.category or "Misc"
    tempCategoryIcon = nil
    showTempCatPicker = false
    SeedEnvBuffers(locData)
end

--- Prepare and open the Manual Coordinates modal (resets all fields)
local function OpenManualModal()
    manualPaste = ""
    manualLastPaste = ""
    manualX, manualY, manualZ, manualYaw = 0.0, 0.0, 0.0, 0.0
    manualName = "Manual Location"
    manualCategory = "Misc"
    manualCategoryIcon = nil
    showManualCatPicker = false
    showManualModal = true
end

--- Draw a single location row
local function DrawLocationRow(loc, uniqueSuffix)
    ImGui.PushID(loc.id .. (uniqueSuffix or ""))
    ImGui.BeginGroup()

    ImGui.Separator()

    -- 1. Text Information (Name, Desc, District)
    ImGui.BeginGroup()
    -- Name (Bold)
    ImGui.PushTextWrapPos(0.0)
    local safeName = loc.name or "Unknown Location"
    -- Name: Bright White (Primary Focus)
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, safeName)
    ImGui.PopTextWrapPos()

    -- Description (Cool Grey) (0.65, 0.65, 0.67) - Clear but subtle
    ImGui.PushStyleColor(ImGuiCol.Text, 0.65, 0.65, 0.67, 1.0)
    ImGui.PushTextWrapPos(0.0)
    if loc.description and loc.description ~= "" then
        ImGui.TextWrapped(loc.description)
    end
    ImGui.PopTextWrapPos()
    ImGui.PopStyleColor()

    -- Category Info (District View OR Favorite)
    -- A-Z view is ungrouped, so the category isn't shown as a header; show it per row instead.
    if Logic.settings.groupBy == "District" or Logic.settings.groupBy == "A-Z" or loc.favorite then
        local catName = loc.category or "Misc"
        local catIcon = "DotsCircle"
        for _, c in ipairs(Logic.GetCategories()) do
            if c.name == catName then
                catIcon = c.icon
                break
            end
        end
        local glyph = IconGlyphs[catIcon] or IconGlyphs.Help
        -- Category: Medium Purple (0.6, 0.4, 0.9) - Readable "Middle Ground"
        ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.4, 0.9, 1.0)
        ImGui.Text(L("locationRow.categoryLine", glyph, catName))
        ImGui.PopStyleColor()
    end

    -- District Information (Conditional OR Favorite)
    if Logic.settings.showDistrict or loc.favorite then
        local districtName = loc.district or "Unknown"
        local subDistrictName = loc.subDistrict

        -- District: Electric Blue (0.2, 0.85, 1.0) - Tech/Hologram feel
        ImGui.PushStyleColor(ImGuiCol.Text, 0.2, 0.85, 1.0, 1.0)
        ImGui.Text(L("locationRow.districtLine", districtName))
        ImGui.PopStyleColor()

        -- Sub-District (Darker Blue), inline if exists
        if subDistrictName and subDistrictName ~= "" then
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.6, 1.0) -- Grey Separator
            ImGui.Text("|")
            ImGui.PopStyleColor()
            ImGui.SameLine()

            -- Darker Blue for Sub-District (0.4, 0.6, 0.75)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.6, 0.75, 1.0)
            ImGui.Text(L("locationRow.subDistrictLine", subDistrictName))
            ImGui.PopStyleColor()
        end
    end

    -- Coordinates Information (Conditional)
    if Logic.settings.showCoords and loc.pos then
        local cStr = string.format("X: %.1f, Y: %.1f, Z: %.1f", loc.pos.x, loc.pos.y, loc.pos.z)
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.5, 1.0)
        ImGui.Text(cStr)
        ImGui.PopStyleColor()
    end

    -- Saved Time & Weather (Amber, so it reads as a state this location will impose)
    if loc.env then
        local envStr = Env.Describe(loc.env)
        if envStr ~= "" then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.75, 0.35, 1.0)
            ImGui.Text(IconGlyphs.MapClock .. " " .. envStr)
            ImGui.PopStyleColor()
            if loc.env.weather and not Env.HasWeatherState(loc.env.weather) then
                ImGui.SameLine()
                ImGui.TextColored(1.0, 0.5, 0.4, 1.0, L("locationRow.notInstalled"))
            end
        end
    end

    -- Source Information (Grey - Subtle)
    if Logic.settings.showSourceInfo and loc.sourceType then
        local sStr = "Source: " .. loc.sourceType
        if loc.sourceDetail and loc.sourceDetail ~= "" then
            sStr = sStr .. " (" .. loc.sourceDetail .. ")"
        end
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.5, 1.0)
        ImGui.PushTextWrapPos(0.0)
        ImGui.Text(sStr)
        ImGui.PopTextWrapPos()
        ImGui.PopStyleColor()
    end

    ImGui.EndGroup()

    ImGui.Spacing()

    -- 2. Action Buttons Row --

    -- Favorite Button
    if loc.favorite then
        if ImGui.Button(IconGlyphs.Star) then
            Logic.UpdateLocation(loc.id, nil, nil, false)
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locationRow.removeFromFavorites")) end
    else
        if ImGui.Button(IconGlyphs.StarOutline) then
            Logic.UpdateLocation(loc.id, nil, nil, true)
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locationRow.addToFavorites")) end
    end
    ImGui.SameLine()

    -- Map Pin Button
    if ImGui.Button(IconGlyphs.MapMarker) then
        Logic.SetMappin(loc)
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locationRow.placeCustomMapPin")) end
    ImGui.SameLine()

    -- Teleport Button
    ImGui.PushStyleColor(ImGuiCol.Button, 1.0, 0.6, 0.0, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 1.0, 0.6, 0.0, 0.8)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 1.0, 0.6, 0.0, 0.6)
    if ImGui.Button(IconGlyphs.RunFast) then
        Logic.TeleportTo(loc, false)
    end
    -- Right-click carries the saved time and weather. Two gestures rather than a
    -- setting, so the choice is made per teleport instead of once in Settings.
    if ImGui.IsItemClicked(1) then
        Logic.TeleportTo(loc, true)
    end
    ImGui.PopStyleColor(3)
    if ImGui.IsItemHovered() then
        if loc.env then
            ImGui.SetTooltip(L("locationRow.teleportWithEnv", Env.Describe(loc.env)))
        else
            ImGui.SetTooltip(L("locationRow.teleportInstantlyReleasingAnyHeld"))
        end
    end
    ImGui.SameLine()

    -- Universal Actions (Edit/Update/Delete) - Now available for all

    -- Edit
    if ImGui.Button(IconGlyphs.Pencil) then
        OpenEditModal(loc)
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locationRow.editNameDescription")) end
    ImGui.SameLine()

    -- Update Pos
    if ImGui.Button(IconGlyphs.Refresh) then
        updateConfirmId = loc.id
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locationRow.updateCoordinatesToYourCurrent")) end
    ImGui.SameLine()

    -- Export (New)
    if ImGui.Button(IconGlyphs.ContentCopy) then
        local data = Impex.ExportLocation(loc.id)
        OpenExport(L("locationRow.exportCode") .. (loc.name or L("locationRow.location")), data)
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locationRow.exportToClipboard")) end
    ImGui.SameLine()

    -- Delete (Red Button)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.15, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.2, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.1, 0.1, 1.0)
    if ImGui.Button(IconGlyphs.Delete) then
        confirmDeleteId = loc.id
    end
    ImGui.PopStyleColor(3)
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locationRow.deleteLocation")) end

    ImGui.EndGroup()
    ImGui.PopID()
    return true
end

--- Draw the Locations Tab Content
local function DrawLocationsTab()
    -- Helpers
    local function CheckSearch(loc)
        if searchQuery == "" then return true end

        local q = string.lower(searchQuery)
        local n = string.lower(loc.name or "")
        local d = string.lower(loc.description or "")
        local dist = string.lower(loc.district or "")
        local sub = string.lower(loc.subDistrict or "")
        local cat = string.lower(loc.category or "")

        local coords = ""
        if loc.pos then
            coords = string.format("%.1f %.1f %.1f", loc.pos.x, loc.pos.y, loc.pos.z)
        end

        if string.find(n, q) or string.find(d, q) or string.find(dist, q) or string.find(sub, q) or string.find(cat, q) or string.find(coords, q) then
            return true
        end
        if Logic.CheckSearch(loc, searchQuery) then
            return true
        end
        return false
    end

    -- Reset filtered count each frame
    filteredLocationCount = 0

    -- 1. Pinned Header (Search & Global Actions)
    -- Calculate height dynamically based on font/frame size (2 rows + padding)
    local frameH = ImGui.GetFrameHeightWithSpacing()
    local headerHeight = (frameH * 2) + 10 -- Add a little extra buffer for separator/padding

    local availW, availH = ImGui.GetContentRegionAvail()

    if ImGui.BeginChild("LocHeader", availW, headerHeight, false, 0) then
        -- Row 1: Add Button & Expand/Collapse (Icon Only)
        if ImGui.Button(IconGlyphs.Plus) then
            -- Pre-check for duplicate
            local playerState = Logic.GetPlayerState()
            if playerState then
                local isDup, dupName, dupId = Logic.CheckForDuplicate(playerState.pos)
                if isDup then
                    duplicateWarningName = dupName or "Unknown"
                    duplicateWarningId = dupId
                    -- The popup opens in the main scope, outside this child window
                    showDuplicateModal = true
                else
                    -- Don't save immediately: use CreateLocationData plus the Edit modal.
                    local newLocData = Logic.CreateLocationData()
                    if newLocData then
                        OpenCreateModal(newLocData)
                    end
                end
            end
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("checkSearch.addCurrentLocation")) end

        -- Manual Coordinates Button (add a location from typed/pasted XYZ)
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.CrosshairsGps) then
            OpenManualModal()
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("checkSearch.addLocationFromManualCoordinates")) end

        -- Import Button (same modal the Settings tab opens; the flag is read in the main draw)
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Download) then
            showImportRed = true
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("checkSearch.importLocations")) end

        -- Right Align Expand/Collapse + Sort Combo
        ImGui.SameLine()

        -- Dynamic Right Align: Calc width of buttons + combo + spacing
        local style = ImGui.GetStyle()
        local b1w = ImGui.CalcTextSize(IconGlyphs.ArrowExpandAll) + (style.FramePadding.x * 2)
        local b2w = ImGui.CalcTextSize(IconGlyphs.ArrowCollapseAll) + (style.FramePadding.x * 2)

        -- Auto-fit Sort Combo
        local tDist = ImGui.CalcTextSize("District")
        local tCat = ImGui.CalcTextSize("Category")
        local comboW = math.max(tDist, tCat) + (style.FramePadding.x * 4) + 25 -- Text + Padding + Arrow

        -- Expand/Collapse buttons only matter for grouped views; they are disabled (not hidden)
        -- in the flat A-Z view so the layout stays stable as the user switches modes.
        local currentSort = Logic.settings.groupBy or "District"
        local showGroupButtons = currentSort ~= "A-Z"

        local rightOffset = b1w + b2w + comboW + (style.ItemSpacing.x * 2)

        ImGui.SetCursorPosX(ImGui.GetWindowContentRegionWidth() - rightOffset)

        -- Sort Combo
        ImGui.SetNextItemWidth(comboW)

        if ImGui.BeginCombo("##sort", GroupByLabel(currentSort)) then
            for _, value in ipairs(GROUP_BY_VALUES) do
                if ImGui.Selectable(GroupByLabel(value), currentSort == value) then
                    if currentSort ~= value then
                        Logic.settings.groupBy = value
                        Logic.Save()
                    end
                end
            end
            ImGui.EndCombo()
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("locations.sortBy", GroupByLabel(currentSort))) end

        ImGui.SameLine()

        ImGui.BeginDisabled(not showGroupButtons)

        if ImGui.Button(IconGlyphs.ArrowExpandAll) then
            forceExpand = true
        end
        if ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled) then
            ImGui.SetTooltip(showGroupButtons and L("checkSearch.expandAllGroups") or L("checkSearch.noGroupsToExpandIn"))
        end

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.ArrowCollapseAll) then
            forceCollapse = true
        end
        if ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled) then
            ImGui.SetTooltip(showGroupButtons and L("checkSearch.collapseAllGroups") or L("checkSearch.noGroupsToCollapseIn"))
        end

        ImGui.EndDisabled()

        -- Row 2: Search Bar with Clear Button AND Export Button
        local style = ImGui.GetStyle()
        local clearBtnW = ImGui.CalcTextSize(IconGlyphs.Eraser) + (style.FramePadding.x * 2)
        local exportBtnW = ImGui.CalcTextSize(IconGlyphs.ContentCopy) + (style.FramePadding.x * 2)
        local availW = ImGui.GetContentRegionAvail()

        -- Subtract both buttons + spacings
        ImGui.SetNextItemWidth(availW - clearBtnW - exportBtnW - (style.ItemSpacing.x * 2))
        searchQuery = ImGui.InputTextWithHint("##search", IconGlyphs.Magnify .. L("checkSearch.searchLocations"), searchQuery, 100)

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Eraser) then
            searchQuery = ""
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("checkSearch.clearSearch")) end

        -- QOL: Export Filtered Button
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.ContentCopy) then
            -- SearchLocations applies the same filter as the list view.
            local list = Logic.SearchLocations(searchQuery)
            if list and #list > 0 then
                local b64, count = Impex.ExportList(list)
                if b64 then
                    OpenExport(L("locations.exportFilteredTitle", count), b64)
                end
            else
                Utils.NotifyWarning(L("checkSearch.noLocationsToExport"))
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip(L("locations.exportTooltip",
                searchQuery == "" and L("checkSearch.all") or L("checkSearch.filtered")))
        end

        ImGui.Separator()
    end
    ImGui.EndChild()


    -- 2. Scrolling List
    -- Recalculate available height after header
    local _, remainingH = ImGui.GetContentRegionAvail()
    ImGui.BeginChild("LocList", availW, remainingH, false, 0)

    -- 2a. Favorites Section
    local filteredFavorites = {}
    for _, filterLoc in ipairs(Logic.locations) do
        if filterLoc.favorite and CheckSearch(filterLoc) then
            table.insert(filteredFavorites, filterLoc)
            filteredLocationCount = filteredLocationCount + 1
        end
    end
    table.sort(filteredFavorites, SortLocationByName)

    if #filteredFavorites > 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.84, 0.0, 1.0) -- Gold for header

        ApplyGroupOpenState("fav")

        ImGui.PushStyleColor(ImGuiCol.Header, 0, 0, 0, 0.0)
        ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0, 0, 0, 0.0)
        ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0, 0, 0, 0.0)

        local favOpen = ImGui.CollapsingHeader(IconGlyphs.Star .. L("locations.favoritesHeader", #filteredFavorites) .. "##fav")
        RecordGroupOpenState("fav", favOpen)
        if favOpen then
            ImGui.PopStyleColor(4) -- +1 for the Gold Text pushed above
            ImGui.Indent(10)
            if ImGui.BeginTable("FavTable", 1, ImGuiTableFlags.RowBg) then
                ImGui.TableSetupColumn("Loc", ImGuiTableColumnFlags.WidthStretch)
                for _, loc in ipairs(filteredFavorites) do
                    ImGui.TableNextRow()
                    ImGui.TableSetColumnIndex(0)
                    DrawLocationRow(loc, "Fav")
                end
                ImGui.EndTable()
            end
            ImGui.Unindent(10)
        else
            ImGui.PopStyleColor(4)
        end
    end

    -- 2b. Main List (Category, A-Z, or District)
    local currentSort = Logic.settings.groupBy or "District"

    if currentSort == "Category" then
        -- CATEGORY VIEW
        local cats = Logic.GetCategories()
        for _, catInfo in ipairs(cats) do
            -- Filter locations
            local catLocs = {}
            for _, loc in ipairs(Logic.locations) do
                if not loc.favorite and loc.category == catInfo.name and CheckSearch(loc) then
                    table.insert(catLocs, loc)
                    filteredLocationCount = filteredLocationCount + 1
                end
            end

            if #catLocs > 0 then
                table.sort(catLocs, SortLocationByName)

                local iconStr = IconGlyphs[catInfo.icon] or IconGlyphs.Star

                local catKey = "cat_" .. catInfo.name
                ApplyGroupOpenState(catKey)

                ImGui.PushStyleColor(ImGuiCol.Header, 0, 0, 0, 0.0)
                ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0, 0, 0, 0.0)
                ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0, 0, 0, 0.0)

                local isOpen = ImGui.CollapsingHeader(iconStr .. " " .. catInfo.name .. " (" .. #catLocs .. ")##cat_" .. catInfo.name)
                RecordGroupOpenState(catKey, isOpen)
                ImGui.PopStyleColor(3)

                -- Context Menu for Export (Must be outside the isOpen check)
                if ImGui.BeginPopupContextItem("##ctx_cat" .. catInfo.name) then
                    if ImGui.MenuItem(IconGlyphs.ContentCopy .. L("checkSearch.exportCategory")) then
                        local data, c = Impex.ExportCategory(catInfo.name)
                        if data then
                            OpenExport(L("locations.exportCategoryTitle", catInfo.name, c), data)
                        else
                            Utils.NotifyWarning(L("checkSearch.noLocationsToExport2"))
                        end
                    end
                    ImGui.EndPopup()
                end
                if ImGui.IsItemHovered() then ImGui.SetTooltip(L("checkSearch.rightClickForOptions")) end

                if isOpen then
                    ImGui.Indent(10)
                    if ImGui.BeginTable("CatTable" .. catInfo.name, 1, ImGuiTableFlags.RowBg) then
                        ImGui.TableSetupColumn("Loc", ImGuiTableColumnFlags.WidthStretch)
                        for _, loc in ipairs(catLocs) do
                            ImGui.TableNextRow()
                            ImGui.TableSetColumnIndex(0)
                            DrawLocationRow(loc, "Cat")
                        end
                        ImGui.EndTable()
                    end
                    ImGui.Unindent(10)
                end
            end
        end
    elseif currentSort == "A-Z" then
        -- A-Z VIEW (Flat, ungrouped)
        -- No group headers and no per-group count: the footer already shows the total.
        -- Favorites remain in their own pinned section above and are not repeated here.
        local flatLocs = {}
        for _, loc in ipairs(Logic.locations) do
            if not loc.favorite and CheckSearch(loc) then
                table.insert(flatLocs, loc)
                filteredLocationCount = filteredLocationCount + 1
            end
        end
        table.sort(flatLocs, SortLocationByName)

        if #flatLocs > 0 then
            if ImGui.BeginTable("AZTable", 1, ImGuiTableFlags.RowBg) then
                ImGui.TableSetupColumn("Loc", ImGuiTableColumnFlags.WidthStretch)
                for _, loc in ipairs(flatLocs) do
                    ImGui.TableNextRow()
                    ImGui.TableSetColumnIndex(0)
                    DrawLocationRow(loc, "AZ")
                end
                ImGui.EndTable()
            end
        end
    else
        -- DISTRICT VIEW
        local districts = {}
        for _, loc in ipairs(Logic.locations) do
            if not loc.favorite and CheckSearch(loc) then
                local dName = loc.district or "Unknown"
                local sName = loc.subDistrict or "General"
                -- Fix for Dogtown Grouping
                if dName == "Dogtown" and sName == "General" then sName = "Locations" end

                if not districts[dName] then districts[dName] = {} end
                if not districts[dName][sName] then districts[dName][sName] = {} end

                table.insert(districts[dName][sName], loc)
            end
        end

        -- Render Districts
        local sortedDistricts = {}
        for dName, _ in pairs(districts) do table.insert(sortedDistricts, dName) end
        table.sort(sortedDistricts)

        for _, dName in ipairs(sortedDistricts) do
            local subDistricts = districts[dName]
            local count = 0
            for _, group in pairs(subDistricts) do count = count + #group end

            local distKey = "dist_" .. dName
            ApplyGroupOpenState(distKey)

            ImGui.PushStyleColor(ImGuiCol.Header, 0, 0, 0, 0.0)
            ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0, 0, 0, 0.0)
            ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0, 0, 0, 0.0)

            local isOpen = ImGui.CollapsingHeader(dName .. " (" .. count .. ")##dist_" .. dName)
            RecordGroupOpenState(distKey, isOpen)
            ImGui.PopStyleColor(3)

            -- Context Menu for Export (Must be outside the isOpen check to work when collapsed)
            if ImGui.BeginPopupContextItem("##ctx" .. dName) then
                if ImGui.MenuItem(IconGlyphs.ContentCopy .. L("checkSearch.exportDistrict")) then
                    local data, c = Impex.ExportDistrict(dName)
                    if data then
                        OpenExport(L("locations.exportDistrictTitle", dName, c), data)
                    else
                        Utils.NotifyWarning(L("checkSearch.noLocationsToExport2"))
                    end
                end
                ImGui.EndPopup()
            end
            if ImGui.IsItemHovered() then ImGui.SetTooltip(L("checkSearch.rightClickForOptions")) end

            if isOpen then
                ImGui.Indent(10)


                -- Dogtown Special Case (Flattened & Sorted)
                if dName == "Dogtown" then
                    if ImGui.BeginTable("DogtownTable", 1, ImGuiTableFlags.RowBg) then
                        ImGui.TableSetupColumn("Loc", ImGuiTableColumnFlags.WidthStretch)

                        -- Flatten first
                        local dogtownLocs = {}
                        for _, groupLocs in pairs(subDistricts) do
                            for _, l in ipairs(groupLocs) do
                                table.insert(dogtownLocs, l)
                            end
                        end
                        table.sort(dogtownLocs, SortLocationByName)

                        for _, loc in ipairs(dogtownLocs) do
                            ImGui.TableNextRow()
                            ImGui.TableSetColumnIndex(0)
                            DrawLocationRow(loc, "Dogtown")
                        end
                        ImGui.EndTable()
                    end
                else
                    -- Standard Nested Logic
                    local sortedSubs = {}
                    for sName, _ in pairs(subDistricts) do table.insert(sortedSubs, sName) end
                    table.sort(sortedSubs)

                    for _, sName in ipairs(sortedSubs) do
                        local locs = subDistricts[sName]
                        table.sort(locs, SortLocationByName)

                        -- One header per subdistrict.
                        local headerText = sName
                        local subKey = "sub_" .. dName .. "_" .. sName
                        ApplyGroupOpenState(subKey)

                        ImGui.PushStyleColor(ImGuiCol.Header, 0, 0, 0, 0.0)
                        ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0, 0, 0, 0.0)
                        ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0, 0, 0, 0.0)

                        local subOpen = ImGui.CollapsingHeader(headerText .. " (" .. #locs .. ")##" .. dName .. sName)
                        RecordGroupOpenState(subKey, subOpen)
                        if subOpen then
                            ImGui.PopStyleColor(3)
                            if ImGui.BeginTable("SubDistTable" .. dName .. sName, 1, ImGuiTableFlags.RowBg) then
                                ImGui.TableSetupColumn("Loc", ImGuiTableColumnFlags.WidthStretch)
                                for _, loc in ipairs(locs) do
                                    ImGui.TableNextRow()
                                    ImGui.TableSetColumnIndex(0)
                                    DrawLocationRow(loc, dName .. sName)
                                end
                                ImGui.EndTable()
                            end
                        else
                            ImGui.PopStyleColor(3)
                        end
                    end
                end
                ImGui.Unindent(10)
            end
        end
    end

    forceExpand = false
    forceCollapse = false
    ImGui.EndChild()
end

--- Draw Disclaimer Modal (Easter Egg)
local function DrawDisclaimerModal()
    local title = MODAL_PREFIX .. "NOTICE: TRANS-LOCATIONAL SAFETY PROTOCOL 404-B"
    local titleWidth = ImGui.CalcTextSize(title)
    local winWidth = titleWidth + 60 -- Add padding to account for close button and frame borders

    ImGui.SetNextWindowSize(winWidth, 0, ImGuiCond.Appearing)

    if ImGui.BeginPopupModal(title, true, ImGuiWindowFlags.NoResize) then
        ImGui.SetWindowFontScale(0.7) -- Specific small font request

        ImGui.TextWrapped(L("disclaimer.subjectHighVelocityQuantumDisplacement"))
        ImGui.Spacing()
        ImGui.TextWrapped(
            L("disclaimer.byEngagingTheBlinkDrive"))
        ImGui.Spacing()

        ImGui.BulletText(L("disclaimer.kineticInheritance"))
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            L("disclaimer.newtonIsJerkAndHe"))
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.BulletText(L("disclaimer.theInsideOutClause"))
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            L("disclaimer.ifYouAttemptToTeleport"))
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.BulletText(L("disclaimer.molecularSouvenirs"))
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            L("disclaimer.attemptingToTeleportIntoMoving"))
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.BulletText(L("disclaimer.theGhostRide"))
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            L("disclaimer.yourVehicleWillContinueTo"))
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            L("disclaimer.liabilityWaiverByClickingAgree"))
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 1.0, 0.5, 1.0)
        ImGui.TextWrapped(
            L("disclaimer.safeTravelsChoomPleaseKeep"))
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.SetWindowFontScale(1.0) -- Reset

        local buttonW = 120
        local availW, _ = ImGui.GetContentRegionAvail()
        ImGui.SetCursorPosX((availW - buttonW) * 0.5)

        if ImGui.Button(L("disclaimer.agree"), buttonW, 30) then
            ImGui.CloseCurrentPopup()
        end

        ImGui.EndPopup()
    end
end

--- Draw the Settings Tab
local function DrawSettingsTab()
    -- Use 0, 0 to fill remaining space
    ImGui.BeginChild("SettingsBody", 0, 0, false, 0)
    ImGui.Spacing()

    -- 1. Defaults Section
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("settings.defaults"))
    ImGui.TextColored(0.7, 0.7, 0.7, 1.0, L("settings.overridesStandardDefaultsForNew"))
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "DefaultsCols", false)

    -- Col 1: Name
    ImGui.Text(L("settings.defaultName"))
    local dName = Logic.settings.defaultName or "New Location"
    ImGui.SetNextItemWidth(-1)
    local newDName, changedName = ImGui.InputText("##defName", dName, 100)
    if changedName then
        Logic.settings.defaultName = newDName
        Logic.Save()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.defaultName = Logic.defaultSettings.defaultName
        Logic.Save()
        Utils.Notify(L("settings.resetDefaultName"))
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.rightClickToResetTo")) end
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, L("settings.leaveEmptyToUseGeneric"))
    ImGui.PopTextWrapPos()

    ImGui.NextColumn()

    -- Col 2: Description
    ImGui.Text(L("settings.defaultDescription"))
    local dDesc = Logic.settings.defaultDesc
    if dDesc == nil then dDesc = "Timestamp" end -- Ensure UI reflects default default
    ImGui.SetNextItemWidth(-1)
    local newDDesc, changedDesc = ImGui.InputText("##defDesc", dDesc, 100)
    if changedDesc then
        Logic.settings.defaultDesc = newDDesc
        Logic.Save()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.defaultDesc = Logic.defaultSettings.defaultDesc
        Logic.Save()
        Utils.Notify(L("settings.resetDefaultDescription"))
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.rightClickToResetTo")) end
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, L("settings.defaultsToTimestampAutoGenerated"))
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, L("settings.leaveEmptyToDisable"))
    ImGui.PopTextWrapPos()

    ImGui.Columns(1) -- Reset
    ImGui.Spacing()
    ImGui.Spacing()

    -- 2. Configuration Section
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("settings.configuration"))
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "ConfigCols", false)

    -- Col 1: list and display
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("settings.duplicateWarningDistance"))
    ImGui.PopTextWrapPos()
    local warnDist = Logic.settings.warningDistance or 25.0
    ImGui.SetNextItemWidth(-1)
    local newDist, changedDist = ImGui.SliderFloat("##warnDist", warnDist, 0.0, 50.0, "%.0f")
    if changedDist then
        Logic.settings.warningDistance = newDist
        Logic.Save()
    end
    -- Helper for Right-Click Reset Tooltip
    local function ResetTooltip()
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text(L("resetTooltip.rightClickToResetTo"))
            ImGui.EndTooltip()
        end
    end

    if ImGui.IsItemClicked(1) then
        Logic.settings.warningDistance = Logic.defaultSettings.warningDistance
        Logic.Save()
        Utils.Notify(L("resetTooltip.resetDuplicateWarningDistance"))
    end
    ResetTooltip()
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, L("resetTooltip.setToDisableExactDupes"))
    ImGui.PopTextWrapPos()

    ImGui.Spacing()

    -- Col 1 Continue: Checkboxes
    local showCoords = Logic.settings.showCoords or false
    local newShowCoords, changedCoords = ImGui.Checkbox("##showCoords", showCoords)
    if changedCoords then
        Logic.settings.showCoords = newShowCoords
        Logic.Save()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.showCoords = Logic.defaultSettings.showCoords
        Logic.Save()
        Utils.Notify(L("resetTooltip.resetShowCoordinates"))
    end
    ResetTooltip()
    ImGui.SameLine()
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.showCoordinates"))
    ImGui.PopTextWrapPos()

    local showDist = Logic.settings.showDistrict or false
    local newShowDist, changedDist = ImGui.Checkbox("##showDist", showDist)
    if changedDist then
        Logic.settings.showDistrict = newShowDist
        Logic.Save()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.showDistrict = Logic.defaultSettings.showDistrict
        Logic.Save()
        Utils.Notify(L("resetTooltip.resetShowDistrictCategory"))
    end
    ResetTooltip()
    ImGui.SameLine()
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.showDistrictDetails"))
    ImGui.PopTextWrapPos()

    local showSource = Logic.settings.showSourceInfo or false
    local newShowSource, changedSource = ImGui.Checkbox("##showSource", showSource)
    if changedSource then
        Logic.settings.showSourceInfo = newShowSource
        Logic.Save()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.showSourceInfo = Logic.defaultSettings.showSourceInfo
        Logic.Save()
        Utils.Notify(L("resetTooltip.resetShowImportSource"))
    end
    ResetTooltip()
    ImGui.SameLine()
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.showImportSource"))
    ImGui.PopTextWrapPos()

    ImGui.Spacing()

    -- Default Group State
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.defaultGroupState"))
    ImGui.PopTextWrapPos()

    ImGui.SetNextItemWidth(-1)
    local currentGroupState = Logic.settings.defaultGroupState or "Expanded"
    if ImGui.BeginCombo("##GroupState", GroupStateLabel(currentGroupState)) then
        for _, value in ipairs(GROUP_STATE_VALUES) do
            if ImGui.Selectable(GroupStateLabel(value), currentGroupState == value) then
                Logic.settings.defaultGroupState = value
                Logic.Save()
            end
        end
        ImGui.EndCombo()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.defaultGroupState = "Expanded"
        Logic.Save()
        Utils.Notify(L("resetTooltip.resetDefaultGroupState"))
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("resetTooltip.defaultStateForLocationGroups"))
    end

    ImGui.Spacing()

    -- Language
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("settings.language"))
    ImGui.PopTextWrapPos()

    ImGui.SetNextItemWidth(-1)
    local currentLanguage = Logic.settings.language or "Auto"
    local languagePreview = currentLanguage == "Auto"
        and L("settings.languageAuto", Loc.GetLanguage())
        or (Loc.GetAvailable()[currentLanguage] or currentLanguage)

    if ImGui.BeginCombo("##Language", languagePreview) then
        if ImGui.Selectable(L("settings.languageAuto", Loc.GetLanguage()), currentLanguage == "Auto") then
            Logic.settings.language = "Auto"
            Loc.Apply(nil)
            Logic.Save()
        end
        -- Listed from the files on disk, so a language dropped in after release appears
        -- without anything here naming it.
        for code, name in pairs(Loc.GetAvailable()) do
            if ImGui.Selectable(name, currentLanguage == code) then
                Logic.settings.language = code
                Loc.Apply(code)
                Logic.Save()
            end
        end
        ImGui.EndCombo()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.language = "Auto"
        Loc.Apply(nil)
        Logic.Save()
        Utils.Notify(L("settings.resetLanguage"))
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("settings.languageTooltip"))
    end

    ImGui.Spacing()

    -- Console Logging
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.consoleLogging"))
    ImGui.PopTextWrapPos()

    ImGui.SetNextItemWidth(-1)
    local currentLogLevel = Logic.settings.logLevel or Utils.DEFAULT_LOG_LEVEL
    local chosenLogLevel = nil
    if ImGui.BeginCombo("##LogLevel", currentLogLevel) then
        for _, level in ipairs(Utils.LOG_LEVELS) do
            -- The choice is made after the loop, and a row naming the level already in force
            -- is ignored. Acting inside the loop let a row drawn later overwrite the row the
            -- user clicked, which put every level above the current one out of reach.
            if ImGui.Selectable(level, currentLogLevel == level) and level ~= currentLogLevel then
                chosenLogLevel = level
            end
        end
        ImGui.EndCombo()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.logLevel = Utils.DEFAULT_LOG_LEVEL
        Utils.SetLogLevel(Utils.DEFAULT_LOG_LEVEL)
        Logic.Save()
        Utils.Notify(L("resetTooltip.resetConsoleLogging"))
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("settings.logLevelTooltip"))
    end

    -- Applied after the item queries above, so IsItemClicked and IsItemHovered still refer
    -- to the combo rather than to whatever came next.
    if chosenLogLevel then
        Logic.settings.logLevel = chosenLogLevel
        Utils.SetLogLevel(chosenLogLevel)
        Logic.Save()
    end

    ImGui.NextColumn()

    -- Col 2: time and weather, then the teleport buttons. The safety protocol button stays
    -- last in this column, so anything added here goes above it.

    -- Time & Weather. There is no on/off setting: the teleport button's left and right
    -- click are the choice, so it is made per teleport rather than once here.
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.timeWeather"))
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0,
        L("resetTooltip.rightClickTeleportButtonTo"))
    ImGui.PopTextWrapPos()

    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.weatherTransition"))
    ImGui.PopTextWrapPos()
    ImGui.SetNextItemWidth(-1)
    local newBlend, changedBlend = ImGui.SliderFloat("##envBlend",
        Logic.settings.envBlendTime or 5.0, 0.0, 30.0, "%.1f")
    if changedBlend then
        Logic.settings.envBlendTime = newBlend
        Logic.Save()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.envBlendTime = Logic.defaultSettings.envBlendTime
        Logic.Save()
        Utils.Notify(L("resetTooltip.resetWeatherTransition"))
    end
    ResetTooltip()
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0,
        L("resetTooltip.onlyVisibleOverShortHops"))
    ImGui.PopTextWrapPos()

    if Env.IsWeatherAvailable() then
        -- Forcing a weather state stops the natural cycle, so there has to be a
        -- way back to it that does not mean loading a save.
        if ImGui.Button(IconGlyphs.WeatherPartlyCloudy .. L("resetTooltip.restoreNaturalWeather"), -1, 0) then
            if Env.ResetWeather(Logic.settings.envBlendTime) then
                Utils.Notify(L("resetTooltip.weatherCycleRestored"))
            else
                Utils.NotifyWarning(L("resetTooltip.couldNotRestoreTheWeather"))
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip(L("settings.restoreWeatherTooltip"))
        end
    else
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0, L("resetTooltip.codewareIsMissingTimeApplies"))
        ImGui.PopTextWrapPos()
    end

    ImGui.Spacing()

    -- Teleport
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.teleport"))
    ImGui.PopTextWrapPos()

    -- Warning / Disclaimer
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.6, 0.0, 1.0)
    if ImGui.Button(IconGlyphs.AlertDecagram .. L("resetTooltip.readSafetyProtocol")) then
        ImGui.OpenPopup(MODAL_PREFIX .. "NOTICE: TRANS-LOCATIONAL SAFETY PROTOCOL 404-B")
    end
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.readImportantSafetyDisclaimerRe")) end

    DrawDisclaimerModal() -- Render the modal if open

    ImGui.Columns(1)      -- Reset
    ImGui.Spacing()
    ImGui.Spacing()

    -- 2.5 Manage Categories
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.manageCategories"))
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    if ImGui.Button(IconGlyphs.Plus .. L("resetTooltip.addNewCategory")) then
        showCategoryModal = true
        newCatName = ""
        newCatIcon = "NewBox"
        IconPicker.ClearSearch()
    end

    ImGui.SameLine()

    -- The snapshot is taken on click rather than every frame: it walks every location, and
    -- the list must not shift under the player while they are ticking boxes.
    if ImGui.Button(IconGlyphs.Broom .. L("categoryCleanup.button")) then
        unusedCategories = Logic.GetUnusedCustomCategories()
        categoryCleanupSelection = {}
        for _, cat in ipairs(unusedCategories) do
            categoryCleanupSelection[cat.name] = true
        end
        showCategoryCleanupModal = true
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("categoryCleanup.tooltip"))
    end

    ImGui.Spacing()

    local cats = Logic.GetCategories()
    -- Table with 3 columns
    -- Category Manager List
    ImGui.Text(L("resetTooltip.customCategories"))

    -- Dynamic Width Calculation for Actions
    local style = ImGui.GetStyle()
    local editW = ImGui.CalcTextSize(IconGlyphs.Pencil)
    local delW = ImGui.CalcTextSize(IconGlyphs.Delete)
    -- Button Width = Text + (FramePadding.x * 2)
    -- Total = EditBtn + DelBtn + Spacing + ScrollbarPadding
    local actionsWidth = (editW + (style.FramePadding.x * 2)) +
        (delW + (style.FramePadding.x * 2)) +
        (style.ItemSpacing.x * 3) -- Extra buffer

    -- Fixed Height List (approx 10 rows)
    -- 10 rows * ~25px row height = ~250px
    if ImGui.BeginChild("CategoryList", 0, 250, true) then
        if ImGui.BeginTable("CatManager", 3, ImGuiTableFlags.RowBg) then
            ImGui.TableSetupColumn("Icon", ImGuiTableColumnFlags.WidthFixed, 30)
            ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableSetupColumn("Actions", ImGuiTableColumnFlags.WidthFixed, actionsWidth)

            if Logic.settings.customCategories then
                -- Sort Categories Alphabetically for Display
                local sortedCats = {}
                for _, c in ipairs(Logic.settings.customCategories) do table.insert(sortedCats, c) end
                table.sort(sortedCats, function(a, b) return string.lower(a.name) < string.lower(b.name) end)

                for _, c in ipairs(sortedCats) do
                    ImGui.TableNextRow()

                    ImGui.TableSetColumnIndex(0)
                    local glyph = IconGlyphs[c.icon] or IconGlyphs.Star
                    ImGui.Text(glyph)

                    ImGui.TableSetColumnIndex(1)
                    ImGui.Text(c.name)

                    ImGui.TableSetColumnIndex(2)
                    local isDefault = false
                    for _, d in ipairs(Logic.defaultCategories) do
                        if d.name == c.name then
                            isDefault = true; break
                        end
                    end

                    if not isDefault then
                        -- Edit Button
                        if ImGui.Button(IconGlyphs.Pencil .. "##edit" .. c.name) then
                            showCategoryModal = true
                            newCatName = c.name
                            newCatIcon = c.icon
                            -- The flag is what distinguishes editing from creating
                            isEditingCategory = true
                            editingCategoryOriginalName = c.name
                        end
                        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.editCategory")) end

                        ImGui.SameLine()

                        -- Delete Button
                        ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.15, 0.15, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.7, 0.2, 0.2, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.4, 0.1, 0.1, 1.0)
                        ImGui.SameLine()
                        if ImGui.Button(IconGlyphs.Delete .. "##del" .. c.name) then
                            categoryToDelete = c.name
                            showDeleteCategoryModal = true
                        end
                        ImGui.PopStyleColor(3)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.deleteCustomCategory")) end
                    end
                end
            end
            ImGui.EndTable()
        end
        ImGui.EndChild()
    end

    ImGui.Spacing()
    ImGui.Spacing()

    -- 3. Data & Tools Section
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text(L("resetTooltip.dataTools"))
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "ToolsCols", false)

    -- Col 1: Import/Export/Map
    -- Auto-size buttons (remove width arg) to fit content
    if ImGui.Button(IconGlyphs.ContentCopy .. L("resetTooltip.exportAllData")) then
        local data, count = Impex.ExportAll()
        if data then
            OpenExport(L("settings.exportAllDataTitle", count), data)
        else
            Utils.NotifyWarning(L("resetTooltip.noDataToExport"))
        end
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.backupAllLocationsToClipboard")) end

    -- These buttons size to their label, and a label wider than the column is clipped at the
    -- column edge, so a long one is a layout bug rather than a long button.
    if ImGui.Button(IconGlyphs.CheckAll .. L("resetTooltip.exportSelected")) then
        exportSelection = {}
        exportSelectSearch = ""
        showExportSelectModal = true
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("settings.exportSelectedTooltip"))
    end

    if ImGui.Button(IconGlyphs.Download .. L("resetTooltip.importData")) then
        showImportRed = true
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.importLocationsFromBaseString")) end

    ImGui.Spacing()
    if ImGui.Button(IconGlyphs.MapMarkerOff .. L("resetTooltip.clearLastMapPin")) then
        Logic.ClearMappin()
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.removeTheCurrentlySetCustom")) end

    ImGui.NextColumn()

    -- Col 2: Debugging
    if ImGui.Button(IconGlyphs.Console .. L("resetTooltip.dumpCoordinates")) then
        local info = Utils.GetDebugInfoString()
        Utils.Print("Coordinates\n" .. info)
        lastDebugInfo = info
        ImGui.SetClipboardText(info)
        Utils.Notify(L("resetTooltip.coordinatesCopiedToClipboard"))
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.dumpsCurrentCoordinatesToThe")) end

    if ImGui.Button(IconGlyphs.ApplicationExport .. L("resetTooltip.dumpDistrictInfo")) then
        Utils.DumpDistrictInfo()
        lastDistrictInfo = Utils.GetDistrictInfoString()
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(
            L("resetTooltip.dumpsDistrictPreventionsystemStructureTo"))
    end

    if lastDebugInfo then
        ImGui.Spacing()
        ImGui.TextColored(0.4, 1.0, 0.4, 1.0, L("resetTooltip.lastDebugLocation"))
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextWrapped(lastDebugInfo)
        ImGui.PopTextWrapPos()
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip(L("resetTooltip.middleClickToCopyTo"))
            if ImGui.IsMouseClicked(2) then
                ImGui.SetClipboardText(lastDebugInfo)
                Utils.Notify(L("resetTooltip.coordinatesCopiedToClipboard"))
            end
        end
    end

    if lastDistrictInfo then
        ImGui.Spacing()
        ImGui.TextColored(0.4, 0.8, 1.0, 1.0, L("resetTooltip.lastDistrictInfo"))
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextWrapped(lastDistrictInfo)
        ImGui.PopTextWrapPos()
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip(L("resetTooltip.middleClickToCopyTo"))
            if ImGui.IsMouseClicked(2) then
                ImGui.SetClipboardText(lastDistrictInfo)
                Utils.Notify(L("resetTooltip.districtInfoCopiedToClipboard"))
            end
        end
    end

    ImGui.Columns(1) -- Reset
    ImGui.Spacing()
    ImGui.Spacing()

    -- 4. Danger Zone Section
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, L("resetTooltip.dangerZone"))
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "DangerCols", false)

    -- Col 1
    -- Delete All (Red Button)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.6, 0.1, 0.1, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.7, 0.15, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.05, 0.05, 1.0)
    if ImGui.Button(IconGlyphs.Delete .. L("resetTooltip.deleteAllLocations")) then
        confirmDeleteAll = true
    end
    ImGui.PopStyleColor(3)
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.permanentlyDeleteAllLocations")) end

    ImGui.NextColumn()

    -- Col 2
    -- WrapperModal opens the popup itself from the flag. Naming the title again here
    -- would key OpenPopup to the English string while the modal drew under its
    -- translation, and the two would no longer be the same popup.
    if ImGui.Button(IconGlyphs.Refresh .. L("resetTooltip.resetSettings")) then
        showResetConfirm = true
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip(L("resetTooltip.resetAllSettingsToDefault")) end

    ImGui.NextColumn()

    -- Col 1, second row. Sized to its label like the two above it: a width of -1 fills the
    -- whole tab and reads as a more drastic action than either of them.
    -- The orphan list is taken once on click rather than every frame - it walks every
    -- location and reads the presets directory, and the modal must not shift under the
    -- player while they are ticking boxes.
    if ImGui.Button(IconGlyphs.Broom .. L("resetTooltip.removePresetLocations")) then
        presetOrphans = Impex.GetOrphanedPresets()
        presetCleanupSelection = {}
        presetCleanupDeleteEdited = false
        for _, orphan in ipairs(presetOrphans) do
            presetCleanupSelection[orphan.file] = true
        end
        showPresetCleanupModal = true
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(L("settings.removePresetLocationsTooltip"))
    end

    ImGui.Columns(1) -- Reset
    ImGui.Spacing()

    ImGui.EndChild()

    -- Confirmation Modal for "Delete All". WrapperModal opens it from the flag; repeating
    -- the title here would key OpenPopup to English while the modal drew under its
    -- translation, leaving a modal nothing could open.
    UI.WrapperModal(L("resetTooltip.deleteAllData"), confirmDeleteAll, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text(L("resetTooltip.areYouSureYouWant"))
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, L("resetTooltip.thisActionCannotBeUndone"))
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Delete .. L("resetTooltip.yesDeleteEverything")) then
            Logic.DeleteAllLocations()
            confirmDeleteAll = false
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            confirmDeleteAll = false
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            confirmDeleteAll = false
        end
    })
end

-- Preset cleanup modal geometry. The lists scroll inside a fixed height so a player with
-- forty orphaned locations gets the same modal as one with three.
local PRESET_CLEANUP_WIDTH = 720
local PRESET_CLEANUP_FILE_COL = 300
-- Tall enough for roughly a dozen entries, because a row is two lines whenever more than
-- one preset is ticked and the owning file is named under each location.
local PRESET_CLEANUP_LIST_HEIGHT = 400

-- Lines the owning file name up with the location name above it, past the bullet.
local PRESET_CLEANUP_OWNER_INDENT = 22

-- One line per category, so this holds about a dozen before it scrolls.
local CATEGORY_CLEANUP_WIDTH = 320
local CATEGORY_CLEANUP_HEIGHT = 260

--- One side of the preset cleanup location list.
--- @param wantEdited boolean Draw the edited locations rather than the ones being deleted
--- @param showOwner boolean Name the preset each location came from
local function DrawPresetCleanupLocations(wantEdited, showOwner)
    for _, orphan in ipairs(presetOrphans) do
        if presetCleanupSelection[orphan.file] then
            for _, entry in ipairs(orphan.locations) do
                -- With deleteEdited on, an edited location is being deleted like any other,
                -- so it belongs in the removal list rather than in the kept list.
                local isKept = entry.edited and not presetCleanupDeleteEdited
                if isKept == wantEdited then
                    ImGui.Bullet()
                    ImGui.SameLine()
                    ImGui.PushTextWrapPos(0.0)
                    ImGui.Text(entry.name)
                    -- On its own line under the name rather than beside it: a long name and a
                    -- long file name on one row wrap into each other and the pairing is lost.
                    if showOwner then
                        ImGui.Indent(PRESET_CLEANUP_OWNER_INDENT)
                        ImGui.TextColored(0.5, 0.5, 0.5, 1.0, orphan.file)
                        ImGui.Unindent(PRESET_CLEANUP_OWNER_INDENT)
                    end
                    ImGui.PopTextWrapPos()
                end
            end
        end
    end
end

-- Remove Preset Locations Modal
-- Lists only presets whose file has gone from the presets directory. An installed preset
-- re-imports itself on the next load, so offering to delete its locations would promise a
-- removal that undoes itself.
local function DrawPresetCleanupModal()
    -- Two side-by-side lists need a width stated rather than derived: auto-resize measures
    -- the widest row, so one long location name would decide how wide the modal is.
    local flags = (#presetOrphans == 0) and ImGuiWindowFlags.AlwaysAutoResize
        or ImGuiWindowFlags.NoResize

    UI.WrapperModal(L("presetCleanup.title"), showPresetCleanupModal, flags,
        function()
            if #presetOrphans == 0 then
                ImGui.Text(L("presetCleanup.everyPresetYourLocationsCame"))
                ImGui.Spacing()
                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
                ImGui.TextWrapped(L("presetCleanup.uninstallPresetDownloadFirstThen") ..
                    L("presetCleanup.outTheLocationsItLeft"))
                ImGui.PopStyleColor()
                ImGui.Spacing()

                if ImGui.Button(IconGlyphs.Check .. L("presetCleanup.close")) then
                    showPresetCleanupModal = false
                    ImGui.CloseCurrentPopup()
                end
                return
            end

            ImGui.Text(L("presetCleanup.thesePresetsAreNoLonger"))
            ImGui.Spacing()

            local totalSelected = 0
            local editedSelected = 0
            local selectedFiles = 0
            for _, orphan in ipairs(presetOrphans) do
                if presetCleanupSelection[orphan.file] then
                    totalSelected = totalSelected + orphan.total
                    editedSelected = editedSelected + orphan.edited
                    selectedFiles = selectedFiles + 1
                end
            end

            ImGui.Columns(2, "PresetCleanupCols", false)
            ImGui.SetColumnWidth(0, PRESET_CLEANUP_FILE_COL)

            -- Left: the preset files, one tick each.
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0, L("presetCleanup.presetFiles"))
            ImGui.Spacing()

            if ImGui.BeginChild("PresetFiles", 0, PRESET_CLEANUP_LIST_HEIGHT, false) then
                for _, orphan in ipairs(presetOrphans) do
                    local ticked = presetCleanupSelection[orphan.file] or false
                    local newTicked, changed = ImGui.Checkbox("##preset_" .. orphan.file, ticked)
                    if changed then
                        presetCleanupSelection[orphan.file] = newTicked
                    end
                    ImGui.SameLine()
                    ImGui.PushTextWrapPos(0.0)
                    ImGui.Text(orphan.file)

                    local detail = L(orphan.total == 1 and "presetCleanup.oneLocation"
                        or "presetCleanup.manyLocations", orphan.total)
                    if orphan.edited > 0 then
                        detail = detail .. L("presetCleanup.editedSuffix", orphan.edited)
                    end
                    ImGui.Indent(24)
                    ImGui.TextColored(0.7, 0.7, 0.7, 1.0, detail)
                    ImGui.Unindent(24)
                    ImGui.PopTextWrapPos()
                    ImGui.Spacing()
                end
                ImGui.EndChild()
            end

            ImGui.NextColumn()

            -- Right: what the tick boxes on the left actually add up to. The file name is
            -- only worth a column once more than one preset is ticked; with one, every row
            -- would repeat the same name.
            local showOwner = selectedFiles > 1
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0,
                L("presetCleanup.willBeRemovedHeader", totalSelected - (presetCleanupDeleteEdited and 0 or editedSelected)))
            ImGui.Spacing()

            if ImGui.BeginChild("PresetLocations", 0, PRESET_CLEANUP_LIST_HEIGHT, true) then
                if totalSelected == 0 then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.5, 1.0)
                    ImGui.TextWrapped(L("presetCleanup.tickAPresetToSeeWhat"))
                    ImGui.PopStyleColor()
                else
                    DrawPresetCleanupLocations(false, showOwner)

                    -- Edited locations are listed apart rather than mixed in, because what
                    -- happens to them is the opposite of what happens to the rest.
                    if editedSelected > 0 and not presetCleanupDeleteEdited then
                        ImGui.Spacing()
                        ImGui.Separator()
                        ImGui.Spacing()
                        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.8, 0.3, 1.0)
                        ImGui.TextWrapped(L("presetCleanup.keptEditedHeader", editedSelected))
                        ImGui.PopStyleColor()
                        ImGui.Spacing()
                        DrawPresetCleanupLocations(true, showOwner)
                    end
                end
                ImGui.EndChild()
            end

            ImGui.Columns(1)
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()

            -- Only offered when a ticked preset actually has edited locations, so the choice
            -- appears beside a number rather than as a standing option about nothing.
            if editedSelected > 0 then
                local newDeleteEdited, changedDeleteEdited =
                    ImGui.Checkbox("##delete_edited", presetCleanupDeleteEdited)
                if changedDeleteEdited then
                    presetCleanupDeleteEdited = newDeleteEdited
                end
                ImGui.SameLine()
                ImGui.PushTextWrapPos(0.0)
                ImGui.Text(L("presetCleanup.alsoDeleteEdited", editedSelected))
                ImGui.PopTextWrapPos()

                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
                if presetCleanupDeleteEdited then
                    ImGui.TextWrapped(L("presetCleanup.yourEditsGoWithThem"))
                else
                    ImGui.TextWrapped(L("presetCleanup.editedLocationsAreKeptAnd"))
                end
                ImGui.PopStyleColor()
                ImGui.Spacing()
            end

            local toDelete = totalSelected
            if editedSelected > 0 and not presetCleanupDeleteEdited then
                toDelete = totalSelected - editedSelected
            end

            if toDelete > 0 then
                ImGui.TextColored(1.0, 0.4, 0.4, 1.0, L("resetTooltip.thisActionCannotBeUndone"))
                ImGui.Spacing()
            end

            -- Ticking only presets whose locations are all edited-and-kept deletes nothing, but
            -- it still re-tags them, which is what stops them being listed here again. The
            -- button says what it will do rather than reporting a delete count of zero.
            if totalSelected == 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.5, 1.0)
                ImGui.Text(L("presetCleanup.tickPresetToRemoveIts"))
                ImGui.PopStyleColor()
            else
                local label = toDelete > 0
                    and (IconGlyphs.Delete .. L("presetCleanup.deleteCount", toDelete))
                    or (IconGlyphs.Check .. L("presetCleanup.keepCount", totalSelected))

                if toDelete > 0 then
                    ImGui.PushStyleColor(ImGuiCol.Button, 0.6, 0.1, 0.1, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.7, 0.15, 0.15, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.05, 0.05, 1.0)
                end
                if ImGui.Button(label) then
                    local removed, kept =
                        Impex.RemovePresetLocations(presetCleanupSelection, presetCleanupDeleteEdited)

                    Utils.Notify(kept > 0
                        and L("presetCleanup.removedAndKept", removed, kept)
                        or L("presetCleanup.removed", removed))

                    showPresetCleanupModal = false
                    ImGui.CloseCurrentPopup()
                end
                if toDelete > 0 then
                    ImGui.PopStyleColor(3)
                end
            end

            ImGui.SameLine()
            if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
                showPresetCleanupModal = false
                ImGui.CloseCurrentPopup()
            end
        end, {
            onClose = function()
                showPresetCleanupModal = false
            end,
            onPreOpen = function()
                if #presetOrphans > 0 then
                    ImGui.SetNextWindowSize(PRESET_CLEANUP_WIDTH, 0, ImGuiCond.Appearing)
                end
            end
        })
end

-- Remove Unused Categories Modal
-- Custom categories only. A default with nothing in it is the normal state of the list every
-- location falls back into, not something to tidy away.
local function DrawCategoryCleanupModal()
    UI.WrapperModal(L("categoryCleanup.title"), showCategoryCleanupModal,
        ImGuiWindowFlags.AlwaysAutoResize, function()
            if #unusedCategories == 0 then
                ImGui.Text(L("categoryCleanup.everyCategoryIsInUse"))
                ImGui.Spacing()

                if ImGui.Button(IconGlyphs.Check .. L("presetCleanup.close")) then
                    showCategoryCleanupModal = false
                    ImGui.CloseCurrentPopup()
                end
                return
            end

            ImGui.Text(L("categoryCleanup.theseCategoriesHaveNoLocations"))
            ImGui.Spacing()

            local selected = 0
            if ImGui.BeginChild("UnusedCategories", CATEGORY_CLEANUP_WIDTH,
                    CATEGORY_CLEANUP_HEIGHT, true) then
                for _, cat in ipairs(unusedCategories) do
                    local ticked = categoryCleanupSelection[cat.name] or false
                    local newTicked, changed = ImGui.Checkbox("##unusedcat_" .. cat.name, ticked)
                    if changed then
                        categoryCleanupSelection[cat.name] = newTicked
                    end
                    ImGui.SameLine()
                    ImGui.Text((IconGlyphs[cat.icon] or IconGlyphs.Help) .. " " .. cat.name)
                end
                ImGui.EndChild()
            end

            for _, cat in ipairs(unusedCategories) do
                if categoryCleanupSelection[cat.name] then selected = selected + 1 end
            end

            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
            ImGui.TextWrapped(L("categoryCleanup.noLocationsAreChanged"))
            ImGui.PopStyleColor()
            ImGui.Spacing()

            if selected == 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.5, 1.0)
                ImGui.Text(L("categoryCleanup.tickACategoryToRemoveIt"))
                ImGui.PopStyleColor()
            else
                ImGui.PushStyleColor(ImGuiCol.Button, 0.6, 0.1, 0.1, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.7, 0.15, 0.15, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.05, 0.05, 1.0)
                if ImGui.Button(IconGlyphs.Delete .. L("categoryCleanup.removeCount", selected)) then
                    local removed = Logic.DeleteCategories(categoryCleanupSelection)
                    Utils.Notify(L(removed == 1 and "categoryCleanup.removedOne"
                        or "categoryCleanup.removedMany", removed))
                    showCategoryCleanupModal = false
                    ImGui.CloseCurrentPopup()
                end
                ImGui.PopStyleColor(3)
            end

            ImGui.SameLine()
            if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
                showCategoryCleanupModal = false
                ImGui.CloseCurrentPopup()
            end
        end, {
            onClose = function()
                showCategoryCleanupModal = false
            end
        })
end

-- Reset Settings Confirmation Modal
local function DrawResetSettingsConfirmModal()
    UI.WrapperModal(L("resetSettingsConfirm.resetSettings"), showResetConfirm, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text(L("resetSettingsConfirm.areYouSureYouWant"))
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, L("resetSettingsConfirm.thisWillAlsoRemoveAll"))
        ImGui.Spacing()
        ImGui.Text(L("resetSettingsConfirm.locationsWillNotBeDeleted"))
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Refresh .. L("resetSettingsConfirm.yesResetEverything")) then
            Logic.ResetSettings()
            showResetConfirm = false
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            showResetConfirm = false
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            showResetConfirm = false
        end
    })
end


-- Duplicate Popup
local function DrawDuplicateWarningModal()
    UI.WrapperModal(L("duplicateWarning.duplicateWarning2"), showDuplicateModal, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, IconGlyphs.Alert .. L("duplicateWarning.duplicateWarning"))
        ImGui.Spacing()
        ImGui.Text(L("duplicateWarning.youAreVeryCloseTo"))
        ImGui.Text(L("duplicateWarning.nameQuoted", duplicateWarningName or L("duplicateWarning.unknown")))
        ImGui.Spacing()
        ImGui.Text(L("duplicateWarning.doYouWantToUpdate"))
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.ContentSave .. L("duplicateWarning.repositionExistingLocation")) then
            if duplicateWarningId then
                Logic.UpdateLocationPosition(duplicateWarningId) -- Use Position Update logic
                Utils.Notify(L("duplicateWarning.locationUpdated",
                    duplicateWarningName or L("duplicateWarning.unknown")))
            end
            showDuplicateModal = false
            ImGui.CloseCurrentPopup()
        end

        ImGui.SameLine()

        if ImGui.Button(IconGlyphs.Pencil .. L("duplicateWarning.editExisting")) then
            if duplicateWarningId then
                local existingLoc = Logic.GetLocation(duplicateWarningId)
                if existingLoc then
                    OpenEditModal(existingLoc)
                end
            end
            showDuplicateModal = false
            ImGui.CloseCurrentPopup()
        end

        ImGui.SameLine()

        if ImGui.Button(L("duplicateWarning.cancel")) then
            showDuplicateModal = false
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            showDuplicateModal = false
        end
    })
end

--- Draw the Add/Edit Category Modal
local function DrawAddCategoryModal()
    local suffix = isEditingCategory and "Edit Category" or "Add Category"

    UI.WrapperModal(suffix, showCategoryModal, ImGuiWindowFlags.None, function()
        ImGui.Text(L("addCategory.categoryName"))
        newCatName = ImGui.InputText("##catName", newCatName, 50)

        -- Check for duplicates
        local isDuplicate = false
        if newCatName ~= "" then
            for _, c in ipairs(Logic.GetCategories()) do
                -- Check equality, but ignore self if editing
                if string.lower(c.name) == string.lower(newCatName) then
                    if not isEditingCategory or (isEditingCategory and c.name ~= editingCategoryOriginalName) then
                        isDuplicate = true
                        break
                    end
                end
            end
        end

        if isDuplicate then
            ImGui.SameLine()
            ImGui.TextColored(1.0, 0.4, 0.4, 1.0, L("addCategory.alreadyExists"))
        end

        ImGui.Spacing()
        ImGui.Text(L("addCategory.icon"))
        ImGui.SameLine()
        ImGui.Text((IconGlyphs[newCatIcon] or "?") .. " " .. newCatIcon)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Text(L("addCategory.selectIcon"))

        -- Icon Picker
        IconPicker.Draw(newCatIcon, function(iconName)
            newCatIcon = iconName
        end, 300) -- Height 300

        ImGui.Separator()
        ImGui.Spacing()

        if isEditingCategory then
            -- SAVE CHANGES (EDIT MODE)
            if ImGui.Button(IconGlyphs.ContentSave .. L("addCategory.saveChanges")) then
                if newCatName ~= "" then
                    local success = Logic.UpdateCategory(editingCategoryOriginalName, newCatName, newCatIcon)
                    if success then
                        showCategoryModal = false
                        isEditingCategory = false
                        IconPicker.ClearSearch()
                        ImGui.CloseCurrentPopup()
                    else
                        Utils.NotifyWarning(L("addCategory.nameAlreadyTakenOrInvalid"))
                    end
                else
                    Utils.NotifyWarning(L("addCategory.nameCannotBeEmpty"))
                end
            end
        else
            -- ADD CATEGORY (CREATE MODE)
            if ImGui.Button(IconGlyphs.Plus .. L("addCategory.addCategory")) then
                if newCatName ~= "" then
                    if Logic.AddCategory(newCatName, newCatIcon) then
                        showCategoryModal = false
                        IconPicker.ClearSearch()
                        ImGui.CloseCurrentPopup()
                    else
                        Utils.NotifyWarning(L("addCategory.categoryAlreadyExistsOrInvalid"))
                    end
                else
                    Utils.NotifyWarning(L("addCategory.nameCannotBeEmpty"))
                end
            end
        end

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            showCategoryModal = false
            isEditingCategory = false
            IconPicker.ClearSearch()
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            showCategoryModal = false
            isEditingCategory = false
            IconPicker.ClearSearch()
        end,
        onPreOpen = function()
            -- Set Fixed Width (900) to allow 13 icons with scrollbar
            ImGui.SetNextWindowSize(900, 0, ImGuiCond.Always)
        end
    })
end

---- Draws the Delete Category Confirmation Modal
local function DrawDeleteCategoryConfirmModal()
    UI.WrapperModal(L("deleteCategoryConfirm.title"), showDeleteCategoryModal, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text(L("deleteCategoryConfirm.areYouSureYouWant",
            categoryToDelete or L("duplicateWarning.unknown")))
        ImGui.Spacing()
        ImGui.TextColored(1.0, 0.6, 0.0, 1.0,
            L("deleteCategoryConfirm.locationsUsingThisCategoryWill"))
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Delete .. L("deleteCategoryConfirm.deleteForever")) then
            if categoryToDelete then
                Logic.DeleteCategory(categoryToDelete)
                Utils.Notify(L("deleteCategoryConfirm.categoryDeleted", categoryToDelete))
            end
            showDeleteCategoryModal = false
            categoryToDelete = nil
            ImGui.CloseCurrentPopup()
        end

        ImGui.SameLine()

        if ImGui.Button(IconGlyphs.Cancel .. L("exportSelect.cancel")) then
            showDeleteCategoryModal = false
            categoryToDelete = nil
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            showDeleteCategoryModal = false
        end
    })
end

-- The modal's action buttons, in the order they are drawn. They share one row, and the
-- window is sized from these same strings, so the two cannot drift apart.
local MANUAL_ACTION_LABELS = {
    IconGlyphs.ContentSave .. " Save",
    IconGlyphs.ContentSaveMove .. " Save & Teleport",
    IconGlyphs.RunFast .. " Teleport",
    IconGlyphs.Cancel .. " Cancel",
}

--- Draw the Manual Coordinates modal (save/teleport to typed or pasted XYZ)
local function DrawManualModal()
    local shouldOpen = showManualModal
    -- Fixed width with NoResize: AlwaysAutoResize collapses the window onto its content
    -- (the -1 width fields). The width is pinned; the 0 height auto-fits, and it is re-applied
    -- every frame so the window grows when the icon picker opens inside it.
    --
    -- The width has to hold the four action buttons on one row, and NoResize means a window
    -- too narrow for them clips the last one with no way for the user to widen it. Measuring
    -- the labels keeps that true whatever the font does to their width.
    if shouldOpen then
        local style = ImGui.GetStyle()
        local buttonsW = 0
        for _, label in ipairs(MANUAL_ACTION_LABELS) do
            buttonsW = buttonsW + ImGui.CalcTextSize(label) + (style.FramePadding.x * 2)
        end
        buttonsW = buttonsW + (style.ItemSpacing.x * (#MANUAL_ACTION_LABELS - 1))
            + (style.WindowPadding.x * 2)

        ImGui.SetNextWindowSize(math.max(420, math.ceil(buttonsW) + 4), 0, ImGuiCond.Always)
    end

    UI.WrapperModal(L("manual.title"), shouldOpen, ImGuiWindowFlags.NoResize, function()
        -- Smart paste box (source of truth): any change re-syncs the coordinate fields below.
        ImGui.Text(L("manual.pasteCoordinatesOptional"))

        local style = ImGui.GetStyle()
        local clearBtnW = ImGui.CalcTextSize(IconGlyphs.Eraser) + (style.FramePadding.x * 2)
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail() - clearBtnW - style.ItemSpacing.x)
        manualPaste = ImGui.InputTextWithHint("##manualPaste",
            L("manual.yaw"), manualPaste, 256)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip(L("manual.acceptsYawCetTeleportCommand"))
        end

        -- Paste box drives the fields: parse on change, or reset to 0 when empty/unparseable.
        if manualPaste ~= manualLastPaste then
            manualLastPaste = manualPaste
            local px, py, pz, pyaw = Utils.ParseCoordinates(manualPaste)
            if px and py and pz then
                manualX, manualY, manualZ, manualYaw = px, py, pz, (pyaw or 0.0)
            else
                manualX, manualY, manualZ, manualYaw = 0.0, 0.0, 0.0, 0.0
            end
        end

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Eraser) then
            manualPaste = ""
            manualLastPaste = ""
            manualX, manualY, manualZ, manualYaw = 0.0, 0.0, 0.0, 0.0
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("manual.clearPasteBoxAndCoordinates")) end

        ImGui.Separator()

        -- Coordinate fields (step = 0 hides the +/- spinner buttons)
        ImGui.PushItemWidth(140)
        manualX = ImGui.InputFloat(L("manual.manualx"), manualX, 0, 0, "%.3f")
        manualY = ImGui.InputFloat(L("manual.manualy"), manualY, 0, 0, "%.3f")
        manualZ = ImGui.InputFloat(L("manual.manualz"), manualZ, 0, 0, "%.3f")
        manualYaw = ImGui.InputFloat(L("manual.yawOptionalManualyaw"), manualYaw, 0, 0, "%.3f")
        ImGui.PopItemWidth()

        ImGui.Separator()

        -- Name
        ImGui.Text(L("edit.name"))
        ImGui.SetNextItemWidth(-1)
        manualName = ImGui.InputText("##manualName", manualName, 100)

        -- Category (same input + dropdown pattern as the Edit modal)
        ImGui.Text(L("edit.category"))
        ImGui.SameLine()
        local currentCatIcon = nil
        for _, c in ipairs(Logic.GetCategories()) do
            if c.name == manualCategory then
                currentCatIcon = c.icon
                break
            end
        end
        local isNewCategory = (currentCatIcon == nil and manualCategory ~= "")
        if isNewCategory then
            currentCatIcon = manualCategoryIcon or DEFAULT_NEW_CATEGORY_ICON
        end
        local glyph = IconGlyphs[currentCatIcon or "Help"] or IconGlyphs.Help
        ImGui.AlignTextToFramePadding()
        if isNewCategory then
            if ImGui.Button(glyph .. "##manualCatIconBtn") then
                showManualCatPicker = not showManualCatPicker
                IconPicker.ClearSearch()
            end
            if ImGui.IsItemHovered() then ImGui.SetTooltip(L("category.chooseIconFor", manualCategory)) end
        else
            ImGui.Text(glyph .. " ")
            showManualCatPicker = false
        end
        ImGui.SameLine()
        ImGui.SetNextItemWidth(200)
        manualCategory = ImGui.InputText("##manualCatInput", manualCategory, 50)
        if ImGui.IsItemHovered() then ImGui.SetTooltip(L("manual.typeNewCategoryNameOr")) end
        ImGui.SameLine()
        ImGui.SetNextItemWidth(20)
        if ImGui.BeginCombo("##manualCatSelect", "", ImGuiComboFlags.NoPreview) then
            for _, c in ipairs(Logic.GetCategories()) do
                local icon = IconGlyphs[c.icon] or IconGlyphs.Help
                if ImGui.Selectable(icon .. " " .. c.name, false) then
                    manualCategory = c.name
                    manualCategoryIcon = nil
                    showManualCatPicker = false
                end
            end
            ImGui.EndCombo()
        end

        if isNewCategory and showManualCatPicker then
            IconPicker.Draw(currentCatIcon, function(iconName)
                manualCategoryIcon = iconName
                showManualCatPicker = false
                IconPicker.ClearSearch()
            end, 200)
        end

        ImGui.Separator()

        -- Local helpers
        local function allZero()
            return manualX == 0.0 and manualY == 0.0 and manualZ == 0.0
        end
        local function ensureCategory()
            for _, c in ipairs(Logic.GetCategories()) do
                if c.name == manualCategory then return end
            end
            if manualCategory ~= "" then
                Logic.AddCategory(manualCategory, manualCategoryIcon or DEFAULT_NEW_CATEGORY_ICON)
            end
        end
        local function buildLoc()
            return Logic.CreateManualLocationData(manualX, manualY, manualZ, manualYaw, manualName, manualCategory)
        end
        local function close()
            showManualModal = false
            ImGui.CloseCurrentPopup()
        end

        -- Action buttons
        if ImGui.Button(MANUAL_ACTION_LABELS[1]) then
            if allZero() then
                Utils.NotifyWarning(L("close.enterCoordinatesFirstAreAll"))
            else
                ensureCategory()
                local loc = Logic.AddLocation(buildLoc())
                Utils.Notify(L("close.savedManualLocation") .. (loc and loc.name or manualName))
                close()
            end
        end
        ImGui.SameLine()
        if ImGui.Button(MANUAL_ACTION_LABELS[2]) then
            if allZero() then
                Utils.NotifyWarning(L("close.enterCoordinatesFirstAreAll"))
            else
                ensureCategory()
                local loc = Logic.AddLocation(buildLoc())
                if loc then Logic.TeleportTo(loc) end
                Utils.Notify(L("close.savedAndTeleported") .. (loc and loc.name or manualName))
                close()
            end
        end
        ImGui.SameLine()
        if ImGui.Button(MANUAL_ACTION_LABELS[3]) then
            if allZero() then
                Utils.NotifyWarning(L("close.enterCoordinatesFirstAreAll"))
            else
                Logic.TeleportTo(buildLoc())
                close()
            end
        end
        ImGui.SameLine()
        if ImGui.Button(MANUAL_ACTION_LABELS[4]) then
            close()
        end
    end, {
        onClose = function()
            showManualModal = false
        end
    })
end

--- Main Draw Function
function UI.Draw()
    if not isOverlayOpen then return end

    -- Calc Dynamic Min Width based on longest Setting Button
    local style = ImGui.GetStyle()
    local longestText = IconGlyphs.Delete .. " Delete All Locations" -- Roughly the longest
    local btnW = ImGui.CalcTextSize(longestText) + (style.FramePadding.x * 2)
    local minW = (btnW * 2) + (style.ItemSpacing.x * 3) + 40         -- +40 buffer for scrolling/margin

    ResolveWindowUtils()

    ImGui.SetNextWindowSize(500, 600, ImGuiCond.FirstUseEver)

    -- SetConstraints is Window Utils only: it aligns the bounds to the snap grid so a
    -- snapped window is not immediately clamped back off it.
    if wu.SetConstraints then
        wu.SetConstraints(minW, 300, 9999, 9999, MOD_NAME)
    else
        ImGui.SetNextWindowSizeConstraints(minW, 300, 9999, 9999)
    end

    -- CET's ImGui.Begin(name, open) returns (open, open and shouldDraw) - the close
    -- button FIRST, visibility second. Reading them the other way round closes the
    -- window every time it is collapsed, because collapsed means shouldDraw is false.
    local stillOpen, visible = wu.Begin(MOD_NAME, true)
    if visible then
        local frameH = ImGui.GetFrameHeightWithSpacing()
        -- Dynamic Footer: FrameHeight + small padding for Separator + text
        local footerHeight = frameH + 10

        -- CONTENT WRAPPER: Pins content to available space minus footer
        -- Height < 0 means "Available Height - abs(height)"
        if ImGui.BeginChild("MainWindowContent", 0, -footerHeight) then
            if ImGui.BeginTabBar("MainTabs") then
                if ImGui.BeginTabItem(L("ui.locations")) then
                    -- No specific size needed here, LocHeader+LocList handles it inside Content
                    DrawLocationsTab()
                    ImGui.EndTabItem()
                end

                if ImGui.BeginTabItem(L("ui.settings")) then
                    DrawSettingsTab()
                    ImGui.EndTabItem()
                end
                ImGui.EndTabBar()
            end

            ImGui.EndChild() -- End MainWindowContent
        end


        local winHeight = ImGui.GetWindowHeight()

        ImGui.Separator()

        -- Left: Location Count (QOL: Show Filtered / Total)
        local totalCount = Logic.locations and #Logic.locations or 0
        local countText = "Locations: " .. totalCount

        if searchQuery ~= "" then
            countText = "Locations: " .. filteredLocationCount .. " / " .. totalCount
        end

        ImGui.TextColored(0.5, 0.5, 0.5, 1.0, countText)

        -- Middle: live time and weather, so what the mod is doing to them is visible
        -- without opening another mod's window.
        envReadout = Env.GetReadout()
        if envReadout then
            ImGui.SameLine()

            local readoutText = IconGlyphs.ClockOutline .. " " .. envReadout.time ..
                "   " .. IconGlyphs.WeatherPartlyCloudy .. " " .. envReadout.weather

            -- The padlock is the plain signal that this state is being held rather
            -- than cycling; the colour alone reads as decoration.
            local locked = (envReadout.status ~= nil)
            if envReadout.status == "held" then
                readoutText = readoutText .. " " .. IconGlyphs.Lock
            elseif envReadout.status == "overridden" then
                readoutText = readoutText .. " " .. IconGlyphs.LockAlert
            end

            local r, g, b = 0.5, 0.5, 0.5
            if envReadout.status == "held" then
                r, g, b = 0.9, 0.75, 0.35
            elseif envReadout.status == "overridden" then
                r, g, b = 1.0, 0.5, 0.4
            end

            local readoutW = ImGui.CalcTextSize(readoutText)
            ImGui.SetCursorPosX((ImGui.GetWindowWidth() - readoutW) * 0.5)
            ImGui.TextColored(r, g, b, 1.0, readoutText)

            -- Right-click releases the lock, at the place the lock is shown.
            if locked and ImGui.IsItemClicked(1) then
                if Env.ResetWeather(Logic.settings.envBlendTime) then
                    Utils.Notify(L("ui.weatherHandedBackToThe"))
                else
                    Utils.NotifyWarning(L("ui.couldNotReleaseTheWeather"))
                end
            end

            if ImGui.IsItemHovered() then
                local tip = "Game time and current weather state"
                if envReadout.weatherId then
                    tip = tip .. "\n" .. envReadout.weatherId
                end
                if envReadout.status == "held" then
                    tip = tip .. "\n\nSLM is holding this state, so the weather cycle is stopped." ..
                        "\nRight-click to unlock the weather cycle."
                elseif envReadout.status == "overridden" then
                    tip = tip .. "\n\nSLM set " .. Env.GetWeatherLabel(envReadout.forcedState) ..
                        " and another mod replaced it." ..
                        "\nRight-click to stop holding it."
                else
                    -- The engine's cycle flag is not readable from script, so no
                    -- padlock means SLM is not holding it, not that the cycle is running.
                    tip = tip .. "\n\nSLM is not holding the weather."
                end
                ImGui.SetTooltip(tip)
            end
        end

        -- Right: Version
        ImGui.SameLine()
        local footerText = "v" .. MOD_VERSION
        local windowWidth = ImGui.GetWindowWidth()
        local textWidth = ImGui.CalcTextSize(footerText)
        ImGui.SetCursorPosX(windowWidth - textWidth - 20)
        ImGui.TextColored(0.5, 0.5, 0.5, 1.0, footerText)

        if editingId then
            DrawEditModal()
        end
        if updateConfirmId then
            DrawUpdateConfirmModal()
        end

        -- Always check these (they rely on internal flags)
        DrawImportModal()
        DrawDeleteCategoryConfirmModal()
        DrawDuplicateWarningModal()
        DrawDeleteConfirmModal()

        if showCategoryModal then
            DrawAddCategoryModal()
        end

        if showResetConfirm then
            DrawResetSettingsConfirmModal()
        end

        if showPresetCleanupModal then
            DrawPresetCleanupModal()
        end

        if showCategoryCleanupModal then
            DrawCategoryCleanupModal()
        end

        if showManualModal then
            DrawManualModal()
        end

        if showExportSelectModal then
            DrawExportSelectModal()
        end
    end

    wu.End()

    -- Only the title-bar close button ends the session; collapsing does not.
    if not stillOpen then
        isOverlayOpen = false
    end
end

return UI
