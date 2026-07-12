-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Import/Export module using Base64 encoded JSON strings.
-- Mod Version: 1.5.0
-- Credits: psiberx (CET Kit), community
-------------------------------------------------------------------
local Impex = {}

local Utils = require("modules/utils")
local Logic = require("modules/logic")


-- Configuration
Impex.AMM_LOCATIONS_PATH = "import"
Impex.PRESETS_PATH = "presets"

--- Base64 Character Set
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

--- Encodes a string to Base64
---@param data string
---@return string
local function Base64Encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return b64chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

--- Decodes a Base64 string
---@param data string
---@return string
local function Base64Decode(data)
    data = string.gsub(data, '[^' .. b64chars .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', b64chars:find(x) - 1
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end


-- ====================================================================
--  COMPRESSION / MINIFICATION (V2)
-- ====================================================================

-- MAPPINGS (Hardcoded for stability across updates)
-- These IDs MUST NOT CHANGE once released. Add new items to the end.

local DistrictMap = {
    ["Watson"] = 1,
    ["Westbrook"] = 2,
    ["City Center"] = 3,
    ["Heywood"] = 4,
    ["Santo Domingo"] = 5,
    ["Pacifica"] = 6,
    ["Badlands"] = 7,
    ["Dogtown"] = 8
}
local DistrictMapRev = {}
for k, v in pairs(DistrictMap) do DistrictMapRev[v] = k end

local SubDistrictMap = {
    -- Watson
    ["Little China"] = 1,
    ["Kabuki"] = 2,
    ["Northside"] = 3,
    ["Arasaka Waterfront"] = 4,
    -- Westbrook
    ["Japantown"] = 5,
    ["Charter Hill"] = 6,
    ["North Oak"] = 7,
    -- City Center
    ["Corpo Plaza"] = 8,
    ["Downtown"] = 9,
    -- Heywood
    ["Wellsprings"] = 10,
    ["The Glen"] = 11,
    ["Vista del Rey"] = 12,
    -- Santo Domingo
    ["Arroyo"] = 13,
    ["Rancho Coronado"] = 14,
    -- Pacifica
    ["Coastview"] = 15,
    ["West Wind Estate"] = 16,
    -- Badlands
    ["Badlands"] = 17, -- Generic
    ["Rocky Ridge"] = 18,
    ["Sierra Sonora"] = 19,
    ["Laguna Bend"] = 20,
    ["Jackson Plains"] = 21,
    ["Rattlesnake Creek"] = 22,
    ["Red Peaks"] = 23,
    ["Biotechnica Flats"] = 24,
    -- Dogtown
    ["Dogtown"] = 25,
    -- Generic
    ["Unknown"] = 99
}
local SubDistrictMapRev = {}
for k, v in pairs(SubDistrictMap) do SubDistrictMapRev[v] = k end

local CategoryMap = {}
local CategoryMapRev = {}

-- Build CategoryMap dynamically from Logic (Single Source of Truth)
if Logic and Logic.defaultCategories then
    for _, cat in ipairs(Logic.defaultCategories) do
        if cat.id then
            CategoryMap[cat.name] = cat.id
            CategoryMapRev[cat.id] = cat.name
        end
    end
end

--- Round a number to N decimal places
local function Round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

--- Minify a single location object (V1 -> V2)
---@param loc table Full location object
---@return table minified Condensed table
local function MinifyLocation(loc)
    local min = {}

    -- 1. Name & Desc (Keep as is, just short keys)
    min.n = loc.name
    if loc.description and loc.description ~= "" then
        min.desc = loc.description -- Key: 'desc'
    end
    -- The ID is preserved in the V2 export.
    min.i = loc.id -- Key: 'i' (Critical for Preset Updates)

    -- 2. IDs (District, SubD, Category)
    -- If found in map, use ID. Else keep string (for custom/unknown stuff)
    min.d = DistrictMap[loc.district] or loc.district
    min.s = SubDistrictMap[loc.subDistrict] or loc.subDistrict
    min.c = CategoryMap[loc.category] or loc.category

    -- 3. Position (Array [x,y,z], Rounded 3 decimals)
    -- w is always 1.0 for a player position, so it is omitted from the payload and restored as 1.0 on expand.
    min.p = {
        Round(loc.pos.x, 3),
        Round(loc.pos.y, 3),
        Round(loc.pos.z, 3)
    }

    -- 4. Rotation (Yaw only if roll/pitch are 0)
    local r = Round(loc.rot.yaw, 3) -- Store Yaw directly if others are 0
    if (not loc.rot.roll or math.abs(loc.rot.roll) < 0.01) and
        (not loc.rot.pitch or math.abs(loc.rot.pitch) < 0.01) then
        min.r = r
    else
        -- Rare case: Store array [roll, pitch, yaw]
        min.r = {
            Round(loc.rot.roll, 3),
            Round(loc.rot.pitch, 3),
            Round(loc.rot.yaw, 3)
        }
    end

    return min
end


--- Expand a single minified object (V2 -> V1)
---@param min table Minified object
---@return table loc Full location object
local function ExpandLocation(min)
    local loc = {}

    -- 1. Basics
    loc.name = min.n or "Unknown"
    loc.description = min.desc or ""
    loc.id = min.i -- Restore ID (Critical for Preset Updates)

    -- 2. Restore IDs
    loc.district = DistrictMapRev[min.d] or min.d or "Unknown"
    loc.subDistrict = SubDistrictMapRev[min.s] or min.s or "Unknown"
    loc.category = CategoryMapRev[min.c] or min.c or "Imported"

    -- 3. Restore Pos
    if min.p then
        loc.pos = {
            x = min.p[1] or 0,
            y = min.p[2] or 0,
            z = min.p[3] or 0,
            w = 1.0
        }
    else
        loc.pos = { x = 0, y = 0, z = 0, w = 1 }
    end

    -- 4. Restore Rot
    loc.rot = {}
    if type(min.r) == "table" then
        loc.rot.roll = min.r[1] or 0
        loc.rot.pitch = min.r[2] or 0
        loc.rot.yaw = min.r[3] or 0
    else
        -- If just a number, it's Yaw
        loc.rot.roll = 0
        loc.rot.pitch = 0
        loc.rot.yaw = min.r or 0
    end

    -- Defaults
    loc.favorite = false

    return loc
end


--- Helper to find any Custom Categories used by a list of locations
---@param locList table List of locations
---@return table|nil customCats List of {name, icon} or nil
local function GetUsedCustomCategories(locList)
    if not Logic.settings.customCategories or #Logic.settings.customCategories == 0 then return nil end

    local used = {}
    local result = {}
    local hasAny = false

    -- Map existing custom cats for fast lookup
    local customMap = {}
    for _, c in ipairs(Logic.settings.customCategories) do
        customMap[c.name] = c.icon
    end

    for _, loc in ipairs(locList) do
        local catName = loc.category
        if catName and customMap[catName] and not used[catName] then
            table.insert(result, { name = catName, icon = customMap[catName] })
            hasAny = true
        end
    end

    if hasAny then return result end
    return nil
end

--- Creates the export package structure
---@param dataArray table List of location objects
---@param customCats table|nil List of custom category definitions
---@return table
local function CreatePackage(dataArray, customCats)
    -- Convert dataArray to Minified V2
    local minData = {}
    for _, loc in ipairs(dataArray) do
        table.insert(minData, MinifyLocation(loc))
    end

    return {
        v = 2,
        type = "batch",
        data = minData,
        categories = customCats
    }
end

--- Exports a single location by ID
---@param id string
---@return string|nil base64_string
function Impex.ExportLocation(id)
    local loc = Logic.GetLocation(id)
    if not loc then return nil end

    local list = { loc }
    local cats = GetUsedCustomCategories(list)
    local package = CreatePackage(list, cats)
    local jsonStr = json.encode(package)
    return Base64Encode(jsonStr)
end

--- Exports all locations in a specific district
---@param districtName string
---@return string|nil base64_string, number count
function Impex.ExportDistrict(districtName)
    local exportList = {}
    for _, loc in ipairs(Logic.locations) do
        if loc.district == districtName then
            table.insert(exportList, loc)
        end
    end

    if #exportList == 0 then return nil, 0 end

    local cats = GetUsedCustomCategories(exportList)
    local package = CreatePackage(exportList, cats)
    local jsonStr = json.encode(package)
    return Base64Encode(jsonStr), #exportList
end

--- Exports all locations in a specific category
---@param categoryName string
---@return string|nil base64_string, number count
function Impex.ExportCategory(categoryName)
    local exportList = {}
    for _, loc in ipairs(Logic.locations) do
        if loc.category == categoryName then
            table.insert(exportList, loc)
        end
    end

    if #exportList == 0 then return nil, 0 end

    local cats = GetUsedCustomCategories(exportList)
    local package = CreatePackage(exportList, cats)
    local jsonStr = json.encode(package)
    return Base64Encode(jsonStr), #exportList
end

--- Exports ALL locations
---@return string|nil base64_string, number count
function Impex.ExportAll()
    if #Logic.locations == 0 then return nil, 0 end

    local cats = GetUsedCustomCategories(Logic.locations)
    local package = CreatePackage(Logic.locations, cats)
    local jsonStr = json.encode(package)
    return Base64Encode(jsonStr), #Logic.locations
end

--- Exports a custom list of locations
---@param list table Array of location objects
---@return string|nil base64_string, number count
function Impex.ExportList(list)
    if not list or #list == 0 then return nil, 0 end

    local cats = GetUsedCustomCategories(list)
    local package = CreatePackage(list, cats)
    local jsonStr = json.encode(package)
    return Base64Encode(jsonStr), #list
end

---Parses AMM JSON string and maps to SLM format
---@param jsonString string
---@return table|nil locationData
function Impex.ParseAMMJson(jsonString)
    local success, data = pcall(json.decode, jsonString)
    if not success or not data then return nil end

    -- Validation: Check for required AMM fields
    if not data.loc_name or not data.x or not data.y or not data.z then
        return nil
    end

    -- Map to SLM structure
    local loc = {}
    loc.name = data.loc_name
    loc.description = "Imported from AMM"
    loc.category = "Imported"
    loc.district = "Unknown"
    loc.subDistrict = "Unknown"
    loc.favorite = false

    loc.pos = {
        x = tonumber(data.x),
        y = tonumber(data.y),
        z = tonumber(data.z),
        w = tonumber(data.w) or 1.0
    }

    -- AMM only provides yaw, pitch/roll are usually flat
    loc.rot = {
        pitch = 0,
        roll = 0,
        yaw = tonumber(data.yaw) or 0
    }

    return loc
end

---Import all JSON files from the AMM User Locations directory
---@param path string Directory path
---@return table report { imported=int, skipped=int, logs=table }
function Impex.ImportFromAMMDirectory(path)
    local report = { imported = 0, skipped = 0, logs = {} }

    -- Check if dir exists (basic check)
    local files = dir(path)
    if not files then
        table.insert(report.logs, "Directory not found: " .. tostring(path))
        return report
    end

    for _, fileInfo in ipairs(files) do
        if string.find(fileInfo.name, "%.json$") then
            -- Read file
            local filePath = path .. "/" .. fileInfo.name
            local f = io.open(filePath, "r")
            if f then
                local content = f:read("*a")
                f:close()

                -- Parse
                local ammLoc = Impex.ParseAMMJson(content)
                if ammLoc then
                    -- Import via Logic
                    if Logic and Logic.ImportLocation then
                        -- DUPLICATE / CONFLICT CHECK
                        if Impex.IsExactDuplicate(ammLoc) then
                            -- Tag the existing location with conflict info
                            local checkDist = 0.5
                            local pos1 = Vector4.new(ammLoc.pos.x, ammLoc.pos.y, ammLoc.pos.z, ammLoc.pos.w)

                            report.skipped = report.skipped + 1
                            local msg = "Skipped (Duplicate): " .. fileInfo.name
                            table.insert(report.logs, msg)
                        else
                            Logic.ImportLocation(ammLoc, false, "AMM Bulk Import", fileInfo.name)
                            report.imported = report.imported + 1
                            table.insert(report.logs, "Imported: " .. fileInfo.name)
                        end
                    else
                        table.insert(report.logs, "Error: Logic/ImportLocation missing for " .. fileInfo.name)
                        report.skipped = report.skipped + 1
                    end
                else
                    report.skipped = report.skipped + 1
                    table.insert(report.logs, "Skipped (Invalid/Format): " .. fileInfo.name)
                end
            else
                report.skipped = report.skipped + 1
                table.insert(report.logs, "Error reading: " .. fileInfo.name)
            end
        end
    end

    return report
end

---Process an import string (Base64 SLM or JSON AMM)
---@param importString string
---@return table|nil locationData, string|nil sourceType, string|nil errorMsg, table|nil customCats
function Impex.ProcessImport(importString)
    if not importString or importString == "" then
        return nil, nil, "Empty string"
    end

    -- DETECT FORMAT:
    -- If it starts with "{" it is likely a plain JSON string (AMM)
    local firstChar = string.sub(importString, 1, 1)
    if firstChar == "{" then
        local ammLoc = Impex.ParseAMMJson(importString)
        if ammLoc then
            return { ammLoc }, "AMM String", nil, nil -- Return as a table containing one location for consistency
        else
            return nil, nil, "Invalid AMM Data or Missing Keys (loc_name, x, y, z)"
        end
    end

    -- Otherwise assume Base64 (Classic SLM Import)
    -- simple cleanup of whitespace
    local str = importString:gsub("%s+", "")

    local success, decoded = pcall(Base64Decode, str)
    if not success or not decoded then return nil, nil, "Base64 Decode Failed" end

    local jsonSuccess, package = pcall(json.decode, decoded)
    if not jsonSuccess or not package then return nil, nil, "JSON Parse Failed" end

    -- Basic Validation
    if not package.data then return nil, nil, "Invalid Data Format" end

    -- V2 DETECTION & EXPANSION
    -- If version is 2 OR if the data looks minified (has keys like 'n', 'p', 'd')
    local function IsMinified(d)
        return d.n and d.p
    end

    local expandedData = {}
    if package.v == 2 or (package.data[1] and IsMinified(package.data[1])) then
        for _, minLoc in ipairs(package.data) do
            table.insert(expandedData, ExpandLocation(minLoc))
        end
    else
        -- V1 Legacy
        expandedData = package.data
    end


    if package.categories and #package.categories > 0 then
    end

    return expandedData, "SLM String", nil, package.categories
end

--- Internal: Check strictly for duplicate (Same Position)
---@param newLoc table
---@return boolean isDuplicate
function Impex.IsExactDuplicate(newLoc)
    -- We ignore warning distance here. Only exact duplicates (very small tolerance)
    -- Logic.CheckForDuplicate uses warningDistance, so we roll our own strict check
    local epsilon = 0.5 * 0.5 -- 0.5m tolerance squared
    local p1 = newLoc.pos

    for _, existing in ipairs(Logic.locations) do
        -- If the ID matches this is an UPDATE, not a duplicate: return false so it gets processed.
        if newLoc.id and existing.id and newLoc.id == existing.id then
            return false
        end

        local p2 = existing.pos
        if p1 and p2 then -- Safety check
            local dx = p1.x - p2.x
            local dy = p1.y - p2.y
            local dz = p1.z - p2.z
            local distSq = (dx * dx) + (dy * dy) + (dz * dz)

            if distSq <= epsilon then
                return true
            end
        end
    end
    return false
end

--- Process an array of location data (Generic Import)
---@param dataArray table List of location tables
---@param sourceType string|nil
---@param sourceDetail string|nil
---@param customCats table|nil List of custom category definitions
---@return table report {imported, skipped, logs}
function Impex.ProcessImportDataArray(dataArray, sourceType, sourceDetail, customCats)
    local report = { imported = 0, skipped = 0, logs = {} }

    -- Process Custom Categories First
    if customCats and #customCats > 0 then
        local catCount = Logic.MergeCustomCategories(customCats)
        if catCount > 0 then
            local msg = "[INFO] Added " .. catCount .. " new custom categories."
            table.insert(report.logs, msg)
            print(Utils.ConsolePrefix .. " " .. msg)
        end
    end

    for _, loc in ipairs(dataArray) do
        -- Validate mandatory fields
        if not loc.pos or not loc.name then
            local msg = "[SKIP] Invalid Data: Missing pos or name."
            table.insert(report.logs, msg)
            print(Utils.ConsolePrefix .. " " .. msg) -- Verbose Console
            report.skipped = report.skipped + 1
        else
            -- Default "Misc" or None to "Imported"
            if not loc.category or loc.category == "" or loc.category == "Misc" then
                loc.category = "Imported"
            end

            if Impex.IsExactDuplicate(loc) then
                local districtStr = (loc.district or "Unknown") .. " \\ " .. (loc.subDistrict or "Unknown")
                local msg = "[SKIP] Duplicate Position: " .. districtStr .. " \\ " .. loc.name
                table.insert(report.logs, msg)
                print(Utils.ConsolePrefix .. " " .. msg) -- Verbose Console
                report.skipped = report.skipped + 1
            else
                -- Import (Pass true for preserveId to allow updates)
                Logic.ImportLocation(loc, true, sourceType, sourceDetail)

                local districtStr = (loc.district or "Unknown") .. " \\ " .. (loc.subDistrict or "Unknown")
                local msg = "[OK] Imported: " .. districtStr .. " \\ " .. loc.name
                table.insert(report.logs, msg)
                print(Utils.ConsolePrefix .. " " .. msg) -- Verbose Console
                report.imported = report.imported + 1
            end
        end
    end


    if report.imported > 0 then
        Logic.Save()
    end

    print(Utils.ConsolePrefix ..
        " Import Processed: " ..
        report.imported .. " imported, " .. report.skipped .. " skipped.")

    return report
end

--- Load Presets from presets/ directory
function Impex.LoadPresets()
    local path = Impex.PRESETS_PATH
    local files = dir(path)
    if not files then return end

    local count = 0
    print(Utils.ConsolePrefix .. " Scanning presets...")

    for _, fileInfo in ipairs(files) do
        if string.find(fileInfo.name, "%.txt$") then
            local filePath = path .. "/" .. fileInfo.name
            local f = io.open(filePath, "r")
            if f then
                local content = f:read("*a")
                f:close()

                if content and content ~= "" then
                    local data, err, _, customCats = Impex.ProcessImport(content) -- Decodes Base64

                    -- Merge Custom Categories from Preset
                    if customCats and #customCats > 0 then
                        Logic.MergeCustomCategories(customCats)
                    end

                    if data then
                        -- Handle Array or Single
                        local list = data
                        if not data[1] then list = { data } end

                        for _, pLoc in ipairs(list) do
                            if pLoc.pos then
                                -- 1. Check ID Match (Update)
                                local idMatch = false
                                local existing = nil

                                if pLoc.id then
                                    -- Ensure ID is string
                                    pLoc.id = tostring(pLoc.id)
                                    existing = Logic.GetLocation(pLoc.id)
                                    if existing then
                                        idMatch = true
                                    end
                                end

                                -- 2. Check Pos Match (Conflict/Resync)
                                local posMatch = false
                                local conflictLoc = nil

                                if not idMatch then -- Only check conflict if not syncing
                                    local checkDist = 0.5
                                    local pos1 = Vector4.new(pLoc.pos.x, pLoc.pos.y, pLoc.pos.z, pLoc.pos.w)
                                    for _, ex in ipairs(Logic.locations) do
                                        local pos2 = Vector4.new(ex.pos.x, ex.pos.y, ex.pos.z, ex.pos.w)
                                        if Vector4.DistanceSquared(pos1, pos2) <= (checkDist * checkDist) then
                                            posMatch = true
                                            conflictLoc = ex
                                            break
                                        end
                                    end
                                end

                                if idMatch then
                                    -- UPDATE
                                    -- Check Protection
                                    if existing.sourceType and string.find(existing.sourceType, "%(Edited%)") then
                                        print(Utils.ConsolePrefix ..
                                            " [SKIP] Protected User-Edited Location: " .. existing.name)
                                    else
                                        Logic.ImportLocation(pLoc, true, "SLM Preset", fileInfo.name)
                                        count = count + 1
                                    end
                                elseif posMatch and conflictLoc then
                                    -- CONFLICT or BROKEN LINK?
                                    -- Check Protection on the *conflicting* loction
                                    local isEdited = conflictLoc.sourceType and
                                    string.find(conflictLoc.sourceType, "%(Edited%)")

                                    -- Check Source Compatibility (Only Heal if it's likely a broken link from a preset)
                                    -- If sourceType is nil, it's Legacy (assume it might be a preset).
                                    -- If sourceType contains "Preset", it's definitely a preset.
                                    -- If sourceType is "Manual Input" or "AMM", we should NOT touch it (treat as Conflict).
                                    local isSimpatia = (not conflictLoc.sourceType) or
                                    string.find(conflictLoc.sourceType, "Preset")

                                    if isEdited then
                                        print(Utils.ConsolePrefix ..
                                            " [SKIP] Protected User-Edited Location (Conflict): " .. conflictLoc.name)
                                    elseif not isSimpatia then
                                        -- It's a Manual Input or AMM Import at the same spot. Do not overwrite.
                                        print(Utils.ConsolePrefix ..
                                            " [SKIP] Conflict: Position match with " ..
                                            (conflictLoc.sourceType or "Unknown") .. " location: " .. conflictLoc.name)
                                    else
                                        -- ** SELF HEALING **
                                        -- IDs differ, but position matches and user hasn't edited it.
                                        -- Fix: Update existing ID to match Preset ID, then Update.
                                        print(Utils.ConsolePrefix ..
                                            " [FIX] Resyncing ID for location: " .. conflictLoc.name)

                                        conflictLoc.id = pLoc.id                                      -- Restore Link
                                        Logic.ImportLocation(pLoc, true, "SLM Preset", fileInfo.name) -- Now performs valid update
                                        count = count + 1
                                    end
                                else
                                    -- NEW IMPORT (Preserve ID!)
                                    Logic.ImportLocation(pLoc, true, "SLM Preset", fileInfo.name)
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if count > 0 then
        print(Utils.ConsolePrefix .. " Loaded " .. count .. " preset locations.")
    end
end

return Impex
