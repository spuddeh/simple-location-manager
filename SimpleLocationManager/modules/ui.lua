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

local MOD_NAME = "Simple Location Manager"
local MOD_VERSION = "1.7.0"
local MODAL_PREFIX = "SLM - "

-- Icon a category gets when it is created without one being picked.
local DEFAULT_NEW_CATEGORY_ICON = "Star"

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
end

function UI.OnOverlayClose()
    isOverlayOpen = false
end

--- Exports data to clipboard and notifies user
local function OpenExport(title, dataStr)
    if not dataStr then
        Utils.NotifyWarning("Nothing to export!")
        return
    end

    -- Copy to Clipboard
    ImGui.SetClipboardText(dataStr)

    -- Notifications
    Utils.Notify("Copied to clipboard: " .. title)

    -- Verbose Console Log
    Utils.Print(title)
    Utils.Print("Export string copied to clipboard.")
end

local importOpenCount = 0

--- Draw Import Modal
local function DrawImportModal()
    UI.WrapperModal("Import Data", showImportRed, ImGuiWindowFlags.AlwaysAutoResize, function()
        if ImGui.BeginTabBar("ImportTabs" .. importOpenCount) then
            -- TAB 1: String Import (Paste)
            if ImGui.BeginTabItem("String Import") then
                ImGui.Spacing()
                ImGui.Text("Paste text here (SLM Export Code OR AMM JSON):")

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

                if ImGui.Button(IconGlyphs.Download .. " Process Import") then
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
            if ImGui.BeginTabItem("AMM Bulk Import") then
                ImGui.Spacing()
                ImGui.TextWrapped("Bulk import JSON files from Appearance Menu Mod.")
                ImGui.TextWrapped("Files must be located in:")
                ImGui.TextColored(0.5, 1.0, 1.0, 1.0,
                    "bin/x64/plugins/cyber_engine_tweaks/mods/SimpleLocationManager/import")
                ImGui.TextWrapped(
                    "(You must manually copy AMM .json files to this folder due to CET Sandbox limitations)")


                ImGui.Spacing()

                if ImGui.Button(IconGlyphs.FolderSearch .. " Scan Directory & Import") then
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
                string.format("Imported: %d, Skipped: %d", importReport.imported, importReport.skipped))

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
        if ImGui.Button("Close", 100, 0) then
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
            if not ImGui.IsPopupOpen(MODAL_PREFIX .. "Import Data") then
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

    UI.WrapperModal("Export Selected Locations", shouldOpen, ImGuiWindowFlags.NoResize, function()
        local candidates = GetExportCandidates()

        -- Filter
        local style = ImGui.GetStyle()
        local clearBtnW = ImGui.CalcTextSize(IconGlyphs.Eraser) + (style.FramePadding.x * 2)
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail() - clearBtnW - style.ItemSpacing.x)
        exportSelectSearch = ImGui.InputTextWithHint("##exportSearch",
            IconGlyphs.Magnify .. " Filter locations...", exportSelectSearch, 100)
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Eraser) then exportSelectSearch = "" end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Clear filter") end

        -- Bulk actions apply to what the filter is showing, not to everything.
        if ImGui.Button(IconGlyphs.CheckAll .. " Select shown") then
            for _, loc in ipairs(candidates) do exportSelection[loc.id] = true end
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.CloseBoxMultipleOutline .. " Deselect shown") then
            for _, loc in ipairs(candidates) do exportSelection[loc.id] = nil end
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Eraser .. " Clear all") then
            exportSelection = {}
        end

        ImGui.Separator()

        if #candidates == 0 then
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0, "No locations match that filter.")
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
                ImGui.Text((IconGlyphs[catIcon] or IconGlyphs.Help) .. " " .. (loc.name or "Unnamed"))

                local districtStr = (loc.district or "Unknown")
                if loc.subDistrict and loc.subDistrict ~= "" then
                    districtStr = districtStr .. " (" .. loc.subDistrict .. ")"
                end
                ImGui.SameLine()
                ImGui.TextColored(0.5, 0.5, 0.5, 1.0, "- " .. districtStr)

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
        ImGui.Text(#selectedList .. " selected")
        ImGui.SameLine()

        ImGui.BeginDisabled(#selectedList == 0)
        if ImGui.Button(IconGlyphs.ContentCopy .. " Copy export string") then
            local data, count = Impex.ExportList(selectedList)
            if data then
                OpenExport("Export Selected (" .. count .. ")", data)
                showExportSelectModal = false
                ImGui.CloseCurrentPopup()
            else
                Utils.NotifyWarning("Nothing to export.")
            end
        end
        ImGui.EndDisabled()
        if ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled) then
            ImGui.SetTooltip("Copy one export string covering every selected location.\n" ..
                "Paste it into a .txt file to share it as a preset.")
        end

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
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
    tempEnvEnabled = ImGui.Checkbox("Save time and weather", tempEnvEnabled)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Set the time of day and weather when teleporting to this location")
    end

    if not tempEnvEnabled then return end

    ImGui.Indent(20)

    -- Time. The checkbox is the counterpart of the weather picker's "Leave as is":
    -- either half can be saved without the other.
    tempEnvTimeEnabled = ImGui.Checkbox("##envTimeOn", tempEnvTimeEnabled)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Off leaves the time of day alone")
    end
    ImGui.SameLine()

    ImGui.AlignTextToFramePadding()
    ImGui.Text("Time:")
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
        ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "Leave as is")
    end

    -- Weather
    local weatherAvailable = Env.IsWeatherAvailable()
    local states = weatherAvailable and Env.GetWeatherStates() or {}

    ImGui.AlignTextToFramePadding()
    ImGui.Text("Weather:")
    ImGui.SameLine()

    ImGui.BeginDisabled(not weatherAvailable)
    ImGui.SetNextItemWidth(220)

    local preview = (tempEnvWeather == "") and "Leave as is" or Env.GetWeatherLabel(tempEnvWeather)
    if ImGui.BeginCombo("##envWeather", preview) then
        if ImGui.Selectable("Leave as is", tempEnvWeather == "") then
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
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0, "Weather needs Codeware - time still works")
    elseif tempEnvWeather ~= "" and not Env.HasWeatherState(tempEnvWeather) then
        -- The location came from a playthrough with a weather mod this one does not
        -- have. The id is kept so it works again once that mod is reinstalled.
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0, "Not installed - this weather will be skipped")
    end

    ImGui.Spacing()
    if ImGui.Button(IconGlyphs.MapClock .. " Use current") then
        local now = Env.Capture()
        if now then
            tempEnvTimeEnabled = true
            tempEnvHour = now.time.h
            tempEnvMinute = now.time.m
            tempEnvWeather = now.weather or ""
        end
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Copy the game's current time and weather") end

    -- Both halves off records nothing, so say so rather than saving an empty block.
    if not tempEnvTimeEnabled and tempEnvWeather == "" then
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0,
            "Nothing selected - this location will not change the time or the weather.")
        ImGui.PopTextWrapPos()
    end

    ImGui.Unindent(20)
end

--- Draw the Edit Location Modal
local function DrawEditModal()
    local shouldOpen = (editingId ~= nil)

    -- SetNextWindowSize pins the initial width so AlwaysAutoResize cannot run away.
    if shouldOpen then ImGui.SetNextWindowSize(500, 0, ImGuiCond.Appearing) end

    UI.WrapperModal("Edit Location", shouldOpen, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text("Name:")
        tempName = ImGui.InputText("##name", tempName, 100)

        ImGui.Text("Description:")
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
        ImGui.Text("Category:")
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
            if ImGui.IsItemHovered() then ImGui.SetTooltip("Choose an icon for \"" .. tempCategory .. "\"") end
        else
            ImGui.Text(glyph .. " ")
            showTempCatPicker = false
        end
        ImGui.SameLine()

        ImGui.SetNextItemWidth(200)
        tempCategory = ImGui.InputText("##catInput", tempCategory, 50)
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Type new category name or select from dropdown") end
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
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Select existing category") end

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
                        ImGui.TextColored(0.5, 0.5, 0.5, 1.0, "(" .. loc.subDistrict .. ")")
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

        if ImGui.Button(IconGlyphs.ContentSave .. " Save") then
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
                        Utils.Notify("Saved new location: " .. tempName)
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
        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
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
    UI.WrapperModal("Update Position?", shouldOpen, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text("Update location position to current player position?")
        ImGui.TextColored(0.7, 0.7, 0.7, 1.0, "(Name and Description will be preserved)")
        ImGui.Spacing()

        if ImGui.Button("Yes, Update") then
            Logic.UpdateLocationPosition(updateConfirmId)
            updateConfirmId = nil
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
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
    UI.WrapperModal("Delete Location?", shouldOpen, ImGuiWindowFlags.AlwaysAutoResize, function()
        if not confirmDeleteId then return end
        local loc = Logic.GetLocation(confirmDeleteId)
        ImGui.Text("Are you sure you want to delete this location?")
        if loc then
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0, loc.name or "Unknown Location")
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
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "This action cannot be undone.")
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Delete .. " Yes, Delete") then
            Logic.DeleteLocation(confirmDeleteId)
            confirmDeleteId = nil
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
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
        ImGui.Text("Category: " .. glyph .. " " .. catName)
        ImGui.PopStyleColor()
    end

    -- District Information (Conditional OR Favorite)
    if Logic.settings.showDistrict or loc.favorite then
        local districtName = loc.district or "Unknown"
        local subDistrictName = loc.subDistrict

        -- District: Electric Blue (0.2, 0.85, 1.0) - Tech/Hologram feel
        ImGui.PushStyleColor(ImGuiCol.Text, 0.2, 0.85, 1.0, 1.0)
        ImGui.Text("District: " .. districtName)
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
            ImGui.Text("Sub-District: " .. subDistrictName)
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
                ImGui.TextColored(1.0, 0.5, 0.4, 1.0, "(not installed)")
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
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Remove from Favorites") end
    else
        if ImGui.Button(IconGlyphs.StarOutline) then
            Logic.UpdateLocation(loc.id, nil, nil, true)
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Add to Favorites") end
    end
    ImGui.SameLine()

    -- Map Pin Button
    if ImGui.Button(IconGlyphs.MapMarker) then
        Logic.SetMappin(loc)
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Place custom map pin") end
    ImGui.SameLine()

    -- Teleport Button (Lazy Mode)
    if Logic.settings.lazyMode then
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
                ImGui.SetTooltip("Teleport instantly\nRight-click: teleport and set " ..
                    Env.Describe(loc.env))
            else
                ImGui.SetTooltip("Teleport instantly, releasing any held weather")
            end
        end
        ImGui.SameLine()
    end

    -- Universal Actions (Edit/Update/Delete) - Now available for all

    -- Edit
    if ImGui.Button(IconGlyphs.Pencil) then
        OpenEditModal(loc)
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Edit name/description") end
    ImGui.SameLine()

    -- Update Pos
    if ImGui.Button(IconGlyphs.Refresh) then
        updateConfirmId = loc.id
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Update coordinates to your current location") end
    ImGui.SameLine()

    -- Export (New)
    if ImGui.Button(IconGlyphs.ContentCopy) then
        local data = Impex.ExportLocation(loc.id)
        OpenExport("Export Code: " .. (loc.name or "Location"), data)
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Export to clipboard") end
    ImGui.SameLine()

    -- Delete (Red Button)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.15, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.2, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.1, 0.1, 1.0)
    if ImGui.Button(IconGlyphs.Delete) then
        confirmDeleteId = loc.id
    end
    ImGui.PopStyleColor(3)
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Delete location") end

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
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Add current location") end

        -- Manual Coordinates Button (add a location from typed/pasted XYZ)
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.CrosshairsGps) then
            OpenManualModal()
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Add location from manual coordinates") end

        -- Import Button (same modal the Settings tab opens; the flag is read in the main draw)
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Download) then
            showImportRed = true
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Import locations") end

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

        if ImGui.BeginCombo("##sort", currentSort) then
            if ImGui.Selectable("District", currentSort == "District") then
                if currentSort ~= "District" then
                    Logic.settings.groupBy = "District"
                    Logic.Save()
                end
            end
            if ImGui.Selectable("Category", currentSort == "Category") then
                if currentSort ~= "Category" then
                    Logic.settings.groupBy = "Category"
                    Logic.Save()
                end
            end
            if ImGui.Selectable("A-Z", currentSort == "A-Z") then
                if currentSort ~= "A-Z" then
                    Logic.settings.groupBy = "A-Z"
                    Logic.Save()
                end
            end
            ImGui.EndCombo()
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Sort By: " .. currentSort) end

        ImGui.SameLine()

        ImGui.BeginDisabled(not showGroupButtons)

        if ImGui.Button(IconGlyphs.ArrowExpandAll) then
            forceExpand = true
        end
        if ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled) then
            ImGui.SetTooltip(showGroupButtons and "Expand All Groups" or "No groups to expand in A-Z view")
        end

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.ArrowCollapseAll) then
            forceCollapse = true
        end
        if ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled) then
            ImGui.SetTooltip(showGroupButtons and "Collapse All Groups" or "No groups to collapse in A-Z view")
        end

        ImGui.EndDisabled()

        -- Row 2: Search Bar with Clear Button AND Export Button
        local style = ImGui.GetStyle()
        local clearBtnW = ImGui.CalcTextSize(IconGlyphs.Eraser) + (style.FramePadding.x * 2)
        local exportBtnW = ImGui.CalcTextSize(IconGlyphs.ContentCopy) + (style.FramePadding.x * 2)
        local availW = ImGui.GetContentRegionAvail()

        -- Subtract both buttons + spacings
        ImGui.SetNextItemWidth(availW - clearBtnW - exportBtnW - (style.ItemSpacing.x * 2))
        searchQuery = ImGui.InputTextWithHint("##search", IconGlyphs.Magnify .. " Search locations...", searchQuery, 100)

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Eraser) then
            searchQuery = ""
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Clear Search") end

        -- QOL: Export Filtered Button
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.ContentCopy) then
            -- SearchLocations applies the same filter as the list view.
            local list = Logic.SearchLocations(searchQuery)
            if list and #list > 0 then
                local b64, count = Impex.ExportList(list)
                if b64 then
                    OpenExport("Export Filtered (" .. count .. ")", b64)
                end
            else
                Utils.NotifyWarning("No locations to export.")
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Export " ..
                (searchQuery == "" and "ALL" or "FILTERED") .. " locations")
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

        local favOpen = ImGui.CollapsingHeader(IconGlyphs.Star .. " Favorites (" .. #filteredFavorites .. ")##fav")
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
                    if ImGui.MenuItem(IconGlyphs.ContentCopy .. " Export Category") then
                        local data, c = Impex.ExportCategory(catInfo.name)
                        if data then
                            OpenExport("Export Category: " .. catInfo.name .. " (" .. c .. ")", data)
                        else
                            Utils.NotifyWarning("No locations to export!")
                        end
                    end
                    ImGui.EndPopup()
                end
                if ImGui.IsItemHovered() then ImGui.SetTooltip("Right-click for options") end

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
                if ImGui.MenuItem(IconGlyphs.ContentCopy .. " Export District") then
                    local data, c = Impex.ExportDistrict(dName)
                    if data then
                        OpenExport("Export District: " .. dName .. " (" .. c .. ")", data)
                    else
                        Utils.NotifyWarning("No locations to export!")
                    end
                end
                ImGui.EndPopup()
            end
            if ImGui.IsItemHovered() then ImGui.SetTooltip("Right-click for options") end

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

        ImGui.TextWrapped("Subject: High-Velocity Quantum Displacement (Teleporting while in a moving vehicle)")
        ImGui.Spacing()
        ImGui.TextWrapped(
            "By engaging the Blink-Drive or any third-party unauthorized teleportation shard while occupying a vehicle moving at speeds exceeding 0.5 m/s, you (the \"User\") acknowledge and accept the following existential risks:")
        ImGui.Spacing()

        ImGui.BulletText("Kinetic Inheritance:")
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            "Newton is a jerk and he doesn't forget. Your body will retain the vehicle's forward momentum. Teleporting into a stationary living room while your car was doing 140 km/h will result in you becoming high-velocity interior decor.")
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.BulletText("The \"Inside-Out\" Clause:")
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            "If you attempt to teleport out of a vehicle but your lag spikes, there is a 42% chance you will leave your skeleton in the driver's seat while your soft tissue arrives at the destination. We do not provide cleaning services for either location.")
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.BulletText("Molecular Souvenirs:")
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            "Attempting to teleport into a moving vehicle may result in \"Partial Fusion.\" If you arrive and find yourself sharing the same physical space as the gear shift, congratulations-you are now a cyborg-unicycle.")
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.BulletText("The Ghost Ride:")
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            "Your vehicle will continue to its destination without you. The Corporation is not responsible for any pedestrian casualties, property damage, or \"Sentient Vehicular Uprisings\" caused by leaving your AI-driven sedan unattended in a state of existential confusion.")
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.TextWrapped(
            "LIABILITY WAIVER: By clicking \"I AGREE,\" you waive your right to sue the manufacturer for being smeared across the spacetime continuum. In the event of a \"Splinch-Splatter\" event, your remaining credits will be automatically diverted to cover the local municipal \"Bio-Hazard Cleanup\" fee.")
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 1.0, 0.5, 1.0)
        ImGui.TextWrapped(
            "Safe travels, Choom. Please keep all limbs, organs, and digital consciousnesses inside the reality-stream until the vehicle has come to a complete stop.")
        ImGui.PopStyleColor()

        ImGui.Spacing()
        ImGui.SetWindowFontScale(1.0) -- Reset

        local buttonW = 120
        local availW, _ = ImGui.GetContentRegionAvail()
        ImGui.SetCursorPosX((availW - buttonW) * 0.5)

        if ImGui.Button("I AGREE", buttonW, 30) then
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
    ImGui.Text("Defaults")
    ImGui.TextColored(0.7, 0.7, 0.7, 1.0, "Overrides standard defaults for new locations.")
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "DefaultsCols", false)

    -- Col 1: Name
    ImGui.Text("Default Name:")
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
        Utils.Notify("Reset 'Default Name'")
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Right-click to reset to default.") end
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "Leave empty to use generic name.")
    ImGui.PopTextWrapPos()

    ImGui.NextColumn()

    -- Col 2: Description
    ImGui.Text("Default Description:")
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
        Utils.Notify("Reset 'Default Description'")
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Right-click to reset to default.") end
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "Defaults to 'Timestamp' (auto-generated).")
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "Leave empty to disable.")
    ImGui.PopTextWrapPos()

    ImGui.Columns(1) -- Reset
    ImGui.Spacing()
    ImGui.Spacing()

    -- 2. Configuration Section
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Configuration")
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "ConfigCols", false)

    -- Col 1: list and display
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Duplicate Warning Distance (m)")
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
            ImGui.Text("Right-click to reset to default.")
            ImGui.EndTooltip()
        end
    end

    if ImGui.IsItemClicked(1) then
        Logic.settings.warningDistance = Logic.defaultSettings.warningDistance
        Logic.Save()
        Utils.Notify("Reset 'Duplicate Warning Distance'")
    end
    ResetTooltip()
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "Set 0 to disable. Exact dupes always blocked.")
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
        Utils.Notify("Reset 'Show Coordinates'")
    end
    ResetTooltip()
    ImGui.SameLine()
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Show Coordinates")
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
        Utils.Notify("Reset 'Show District/Category'")
    end
    ResetTooltip()
    ImGui.SameLine()
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Show District Details")
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
        Utils.Notify("Reset 'Show Import Source'")
    end
    ResetTooltip()
    ImGui.SameLine()
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Show Import Source")
    ImGui.PopTextWrapPos()

    ImGui.Spacing()

    -- Default Group State
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Default Group State")
    ImGui.PopTextWrapPos()

    ImGui.SetNextItemWidth(-1)
    if ImGui.BeginCombo("##GroupState", (Logic.settings.defaultGroupState or "Expanded")) then
        if ImGui.Selectable("Expanded", Logic.settings.defaultGroupState == "Expanded") then
            Logic.settings.defaultGroupState = "Expanded"
            Logic.Save()
        end
        if ImGui.Selectable("Collapsed", Logic.settings.defaultGroupState == "Collapsed") then
            Logic.settings.defaultGroupState = "Collapsed"
            Logic.Save()
        end
        ImGui.EndCombo()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.defaultGroupState = "Expanded"
        Logic.Save()
        Utils.Notify("Reset 'Default Group State'")
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Default state for location groups (Expanded or Collapsed).\nRight-click to reset.")
    end

    ImGui.NextColumn()

    -- Col 2: environment, logging, and the teleport buttons. The safety protocol button stays
    -- last in this column, so anything added here goes above it.

    -- Time & Weather. There is no on/off setting: the teleport button's left and right
    -- click are the choice, so it is made per teleport rather than once here.
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Time & Weather")
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0,
        "Right-click a teleport button to apply a location's saved time and weather.")
    ImGui.PopTextWrapPos()

    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Weather Transition (s)")
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
        Utils.Notify("Reset 'Weather Transition'")
    end
    ResetTooltip()
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0,
        "Only visible over short hops. A long teleport reloads the world and arrives at full strength.")
    ImGui.PopTextWrapPos()

    if Env.IsWeatherAvailable() then
        -- Forcing a weather state stops the natural cycle, so there has to be a
        -- way back to it that does not mean loading a save.
        if ImGui.Button(IconGlyphs.WeatherPartlyCloudy .. " Restore natural weather", -1, 0) then
            if Env.ResetWeather(Logic.settings.envBlendTime) then
                Utils.Notify("Weather cycle restored")
            else
                Utils.NotifyWarning("Could not restore the weather cycle")
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Hand weather back to the game's own cycle.\n" ..
                "A weather mod holding its own locked state overrides this - clear that lock first.")
        end
    else
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextColored(1.0, 0.7, 0.3, 1.0, "Codeware is missing - time applies, weather does not.")
        ImGui.PopTextWrapPos()
    end

    ImGui.Spacing()

    -- Console Logging
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Console Logging")
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
        Utils.Notify("Reset 'Console Logging'")
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(
            "How much this mod writes to the CET console and its log file.\n\n" ..
            "Off - nothing\n" ..
            "Error - only failures, such as a save that did not write\n" ..
            "Warn - failures plus problems worth knowing about (default)\n" ..
            "Info - what the mod is doing, one line per action\n" ..
            "Debug - everything, including one line per imported location\n\n" ..
            "Dumps and export confirmations always print.\nRight-click to reset.")
    end

    -- Applied after the item queries above, so IsItemClicked and IsItemHovered still refer
    -- to the combo rather than to whatever came next.
    if chosenLogLevel then
        Logic.settings.logLevel = chosenLogLevel
        Utils.SetLogLevel(chosenLogLevel)
        Logic.Save()
    end

    ImGui.Spacing()

    -- Lazy Mode
    local lazy = Logic.settings.lazyMode or false
    local newLazy, changedLazy = ImGui.Checkbox("##lazy", lazy)
    if changedLazy then
        Logic.settings.lazyMode = newLazy
        Logic.Save()
    end
    if ImGui.IsItemClicked(1) then
        Logic.settings.lazyMode = Logic.defaultSettings.lazyMode
        Logic.Save()
        Utils.Notify("Reset 'Lazy Mode'")
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Right-click to reset to default (false).") end
    ImGui.SameLine()
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Enable Teleport Buttons (Lazy Mode)")
    ImGui.PopTextWrapPos()

    -- Warning / Disclaimer
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.6, 0.0, 1.0)
    if ImGui.Button(IconGlyphs.AlertDecagram .. " Read Safety Protocol") then
        ImGui.OpenPopup(MODAL_PREFIX .. "NOTICE: TRANS-LOCATIONAL SAFETY PROTOCOL 404-B")
    end
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Read important safety disclaimer re: Teleporting.") end

    DrawDisclaimerModal() -- Render the modal if open

    ImGui.Columns(1)      -- Reset
    ImGui.Spacing()
    ImGui.Spacing()

    -- 2.5 Manage Categories
    ImGui.PushTextWrapPos(0.0)
    ImGui.Text("Manage Categories")
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    if ImGui.Button(IconGlyphs.Plus .. " Add New Category") then
        showCategoryModal = true
        newCatName = ""
        newCatIcon = "NewBox"
        IconPicker.ClearSearch()
    end
    ImGui.Spacing()

    local cats = Logic.GetCategories()
    -- Table with 3 columns
    -- Category Manager List
    ImGui.Text("Custom Categories:")

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
                        if ImGui.IsItemHovered() then ImGui.SetTooltip("Edit Category") end

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
                        if ImGui.IsItemHovered() then ImGui.SetTooltip("Delete Custom Category") end
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
    ImGui.Text("Data & Tools")
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "ToolsCols", false)

    -- Col 1: Import/Export/Map
    -- Auto-size buttons (remove width arg) to fit content
    if ImGui.Button(IconGlyphs.ContentCopy .. " Export All Data") then
        local data, count = Impex.ExportAll()
        if data then
            OpenExport("Export All Data (" .. count .. ")", data)
        else
            Utils.NotifyWarning("No data to export.")
        end
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Backup all locations to Clipboard.") end

    if ImGui.Button(IconGlyphs.CheckAll .. " Export Selected...") then
        exportSelection = {}
        exportSelectSearch = ""
        showExportSelectModal = true
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Pick locations and copy one export string for them.\n" ..
            "Paste it into a .txt file to share it as a preset.")
    end

    if ImGui.Button(IconGlyphs.Download .. " Import Data") then
        showImportRed = true
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Import locations from Base64 string.") end

    ImGui.Spacing()
    if ImGui.Button(IconGlyphs.MapMarkerOff .. " Clear Last Map Pin") then
        Logic.ClearMappin()
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Remove the currently set custom map pin.") end

    ImGui.NextColumn()

    -- Col 2: Debugging
    if ImGui.Button(IconGlyphs.Console .. " Dump Coordinates") then
        local info = Utils.GetDebugInfoString()
        Utils.Print("Coordinates\n" .. info)
        lastDebugInfo = info
        ImGui.SetClipboardText(info)
        Utils.Notify("Coordinates copied to clipboard.")
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Dumps current coordinates to the CET Console and copies to clipboard.") end

    if ImGui.Button(IconGlyphs.ApplicationExport .. " Dump District Info") then
        Utils.DumpDistrictInfo()
        lastDistrictInfo = Utils.GetDistrictInfoString()
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(
            "Dumps district PreventionSystem structure to CET Console and mod log file.")
    end

    if lastDebugInfo then
        ImGui.Spacing()
        ImGui.TextColored(0.4, 1.0, 0.4, 1.0, "Last debug location:")
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextWrapped(lastDebugInfo)
        ImGui.PopTextWrapPos()
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Middle-click to copy to clipboard")
            if ImGui.IsMouseClicked(2) then
                ImGui.SetClipboardText(lastDebugInfo)
                Utils.Notify("Coordinates copied to clipboard.")
            end
        end
    end

    if lastDistrictInfo then
        ImGui.Spacing()
        ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Last district info:")
        ImGui.PushTextWrapPos(0.0)
        ImGui.TextWrapped(lastDistrictInfo)
        ImGui.PopTextWrapPos()
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Middle-click to copy to clipboard")
            if ImGui.IsMouseClicked(2) then
                ImGui.SetClipboardText(lastDistrictInfo)
                Utils.Notify("District info copied to clipboard.")
            end
        end
    end

    ImGui.Columns(1) -- Reset
    ImGui.Spacing()
    ImGui.Spacing()

    -- 4. Danger Zone Section
    ImGui.PushTextWrapPos(0.0)
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "Danger Zone")
    ImGui.PopTextWrapPos()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Columns(2, "DangerCols", false)

    -- Col 1
    -- Delete All (Red Button)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.6, 0.1, 0.1, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.7, 0.15, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.05, 0.05, 1.0)
    if ImGui.Button(IconGlyphs.Delete .. " Delete All Locations") then
        confirmDeleteAll = true
    end
    ImGui.PopStyleColor(3)
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Permanently delete ALL locations.") end

    ImGui.NextColumn()

    -- Col 2
    if ImGui.Button(IconGlyphs.Refresh .. " Reset Settings") then
        showResetConfirm = true
        ImGui.OpenPopup(MODAL_PREFIX .. "Reset Settings?")
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Reset all settings to default.") end

    ImGui.Columns(1) -- Reset

    ImGui.Spacing()

    ImGui.EndChild()

    -- Confirmation Modal for "Delete All"
    if confirmDeleteAll then
        if not ImGui.IsPopupOpen(MODAL_PREFIX .. "Delete All Data?") then
            ImGui.OpenPopup(MODAL_PREFIX .. "Delete All Data?")
        end
    end

    UI.WrapperModal("Delete All Data?", confirmDeleteAll, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text("Are you sure you want to delete ALL locations?")
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "This action cannot be undone!")
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Delete .. " Yes, Delete Everything") then
            Logic.DeleteAllLocations()
            confirmDeleteAll = false
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
            confirmDeleteAll = false
            ImGui.CloseCurrentPopup()
        end
    end, {
        onClose = function()
            confirmDeleteAll = false
        end
    })
end

-- Reset Settings Confirmation Modal
local function DrawResetSettingsConfirmModal()
    UI.WrapperModal("Reset Settings?", showResetConfirm, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text("Are you sure you want to reset ALL settings?")
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "This will also remove all CUSTOM CATEGORIES!")
        ImGui.Spacing()
        ImGui.Text("Locations will NOT be deleted.")
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Refresh .. " Yes, Reset Everything") then
            Logic.ResetSettings()
            showResetConfirm = false
            ImGui.CloseCurrentPopup()
        end
        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
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
    UI.WrapperModal("Duplicate Warning", showDuplicateModal, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, IconGlyphs.Alert .. " Duplicate Warning")
        ImGui.Spacing()
        ImGui.Text("You are very close to an existing location:")
        ImGui.Text("'" .. (duplicateWarningName or "Unknown") .. "'")
        ImGui.Spacing()
        ImGui.Text("Do you want to update it to your current position?")
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.ContentSave .. " Reposition existing location") then
            if duplicateWarningId then
                Logic.UpdateLocationPosition(duplicateWarningId) -- Use Position Update logic
                Utils.Notify("Location updated: " .. (duplicateWarningName or "Unknown"))
            end
            showDuplicateModal = false
            ImGui.CloseCurrentPopup()
        end

        ImGui.SameLine()

        if ImGui.Button(IconGlyphs.Pencil .. " Edit existing") then
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

        if ImGui.Button("Cancel") then
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
        ImGui.Text("Category Name:")
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
            ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "(Already Exists!)")
        end

        ImGui.Spacing()
        ImGui.Text("Icon:")
        ImGui.SameLine()
        ImGui.Text((IconGlyphs[newCatIcon] or "?") .. " " .. newCatIcon)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Text("Select Icon:")

        -- Icon Picker
        IconPicker.Draw(newCatIcon, function(iconName)
            newCatIcon = iconName
        end, 300) -- Height 300

        ImGui.Separator()
        ImGui.Spacing()

        if isEditingCategory then
            -- SAVE CHANGES (EDIT MODE)
            if ImGui.Button(IconGlyphs.ContentSave .. " Save Changes") then
                if newCatName ~= "" then
                    local success = Logic.UpdateCategory(editingCategoryOriginalName, newCatName, newCatIcon)
                    if success then
                        showCategoryModal = false
                        isEditingCategory = false
                        IconPicker.ClearSearch()
                        ImGui.CloseCurrentPopup()
                    else
                        Utils.NotifyWarning("Name already taken or invalid.")
                    end
                else
                    Utils.NotifyWarning("Name cannot be empty.")
                end
            end
        else
            -- ADD CATEGORY (CREATE MODE)
            if ImGui.Button(IconGlyphs.Plus .. " Add Category") then
                if newCatName ~= "" then
                    if Logic.AddCategory(newCatName, newCatIcon) then
                        showCategoryModal = false
                        IconPicker.ClearSearch()
                        ImGui.CloseCurrentPopup()
                    else
                        Utils.NotifyWarning("Category already exists or invalid.")
                    end
                else
                    Utils.NotifyWarning("Name cannot be empty.")
                end
            end
        end

        ImGui.SameLine()
        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
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
    UI.WrapperModal("Delete Category?", showDeleteCategoryModal, ImGuiWindowFlags.AlwaysAutoResize, function()
        ImGui.Text("Are you sure you want to delete the category: '" .. (categoryToDelete or "Unknown") .. "'?")
        ImGui.Spacing()
        ImGui.TextColored(1.0, 0.6, 0.0, 1.0,
            "Locations using this category will NOT be deleted, but will revert to using the default icon.")
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.Button(IconGlyphs.Delete .. " Delete Forever") then
            if categoryToDelete then
                Logic.DeleteCategory(categoryToDelete)
                Utils.Notify("Category '" .. categoryToDelete .. "' deleted.")
            end
            showDeleteCategoryModal = false
            categoryToDelete = nil
            ImGui.CloseCurrentPopup()
        end

        ImGui.SameLine()

        if ImGui.Button(IconGlyphs.Cancel .. " Cancel") then
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

    UI.WrapperModal("Manual Coordinates", shouldOpen, ImGuiWindowFlags.NoResize, function()
        -- Smart paste box (source of truth): any change re-syncs the coordinate fields below.
        ImGui.Text("Paste coordinates (optional):")

        local style = ImGui.GetStyle()
        local clearBtnW = ImGui.CalcTextSize(IconGlyphs.Eraser) + (style.FramePadding.x * 2)
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail() - clearBtnW - style.ItemSpacing.x)
        manualPaste = ImGui.InputTextWithHint("##manualPaste",
            "e.g. x=-1234.5, y=678.9, z=12.3, yaw=90", manualPaste, 256)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Accepts x= y= z= [yaw=], a CET Teleport(...) command, or plain 'x, y, z [yaw]'")
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
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Clear paste box and coordinates") end

        ImGui.Separator()

        -- Coordinate fields (step = 0 hides the +/- spinner buttons)
        ImGui.PushItemWidth(140)
        manualX = ImGui.InputFloat("X##manualX", manualX, 0, 0, "%.3f")
        manualY = ImGui.InputFloat("Y##manualY", manualY, 0, 0, "%.3f")
        manualZ = ImGui.InputFloat("Z##manualZ", manualZ, 0, 0, "%.3f")
        manualYaw = ImGui.InputFloat("Yaw (optional)##manualYaw", manualYaw, 0, 0, "%.3f")
        ImGui.PopItemWidth()

        ImGui.Separator()

        -- Name
        ImGui.Text("Name:")
        ImGui.SetNextItemWidth(-1)
        manualName = ImGui.InputText("##manualName", manualName, 100)

        -- Category (same input + dropdown pattern as the Edit modal)
        ImGui.Text("Category:")
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
            if ImGui.IsItemHovered() then ImGui.SetTooltip("Choose an icon for \"" .. manualCategory .. "\"") end
        else
            ImGui.Text(glyph .. " ")
            showManualCatPicker = false
        end
        ImGui.SameLine()
        ImGui.SetNextItemWidth(200)
        manualCategory = ImGui.InputText("##manualCatInput", manualCategory, 50)
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Type a new category name or pick from the dropdown") end
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
                Utils.NotifyWarning("Enter coordinates first (X/Y/Z are all 0).")
            else
                ensureCategory()
                local loc = Logic.AddLocation(buildLoc())
                Utils.Notify("Saved manual location: " .. (loc and loc.name or manualName))
                close()
            end
        end
        ImGui.SameLine()
        if ImGui.Button(MANUAL_ACTION_LABELS[2]) then
            if allZero() then
                Utils.NotifyWarning("Enter coordinates first (X/Y/Z are all 0).")
            else
                ensureCategory()
                local loc = Logic.AddLocation(buildLoc())
                if loc then Logic.TeleportTo(loc) end
                Utils.Notify("Saved and teleported: " .. (loc and loc.name or manualName))
                close()
            end
        end
        ImGui.SameLine()
        if ImGui.Button(MANUAL_ACTION_LABELS[3]) then
            if allZero() then
                Utils.NotifyWarning("Enter coordinates first (X/Y/Z are all 0).")
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
                if ImGui.BeginTabItem("Locations") then
                    -- No specific size needed here, LocHeader+LocList handles it inside Content
                    DrawLocationsTab()
                    ImGui.EndTabItem()
                end

                if ImGui.BeginTabItem("Settings") then
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
                    Utils.Notify("Weather handed back to the game")
                else
                    Utils.NotifyWarning("Could not release the weather")
                end
            end

            if ImGui.IsItemHovered() then
                local tip = "Game time and current weather state"
                if envReadout.weatherId then
                    tip = tip .. "\n" .. envReadout.weatherId
                end
                if envReadout.status == "held" then
                    tip = tip .. "\n\nSLM is holding this state, so the weather cycle is stopped." ..
                        "\nRight-click to hand it back."
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
