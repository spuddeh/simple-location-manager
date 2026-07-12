-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Core logic handling state, persistence, and game actions.
-- Mod Version: 1.5.0
-- Credits: psiberx (CET Kit), community
-------------------------------------------------------------------

local Utils = require("modules/utils")

local Logic = {}

-- State
Logic.locations = {}

-- Persistent Settings Defaults (Source of Truth)
Logic.defaultSettings = {
    defaultName = "New Location",
    defaultDesc = "Timestamp",
    warningDistance = 25.0,
    showCoords = false,
    showDistrict = false,
    lazyMode = false,               -- Default: false
    defaultGroupState = "Expanded", -- "Expanded" or "Collapsed"
    groupBy = "District",           -- "District" or "Category"
    showSourceInfo = true,          -- Show source/conflict info
    customCategories = {}           -- List of {name="X", icon="Y"}
}

-- Default Categories (Hardcoded)
Logic.defaultCategories = {
    { name = "Apartment",   icon = "Home",                 id = 1 },
    { name = "Bar",         icon = "GlassWine",            id = 2 },
    { name = "Cityscape",   icon = "City",                 id = 3 },
    { name = "Clothing",    icon = "TshirtCrew",           id = 4 },
    { name = "Coffee",      icon = "Coffee",               id = 5 },
    { name = "Destination", icon = "MapMarkerStar",        id = 6 },
    { name = "Enemy",       icon = "Skull",                id = 7 },
    { name = "Food",        icon = "FoodTakeoutBox",       id = 8 },
    { name = "Imported",    icon = "InboxArrowDown",       id = 9 },
    { name = "Hidden Gem",  icon = "DiamondStone",         id = 10 },
    { name = "Loot",        icon = "TreasureChest",        id = 11 },
    { name = "Misc",        icon = "Help",                 id = 12 },
    { name = "NPC",         icon = "Human",                id = 13 },
    { name = "Photo Spot",  icon = "Camera",               id = 14 },
    { name = "Quest",       icon = "ExclamationThick",     id = 15 },
    { name = "Restaurant",  icon = "SilverwareForkKnife",  id = 16 },
    { name = "Saved",       icon = "ContentSave",          id = 17 },
    { name = "Vehicle",     icon = "CarSide",              id = 18 },
    { name = "Vendor",      icon = "CurrencyUsd",          id = 19 },
    { name = "Vista",       icon = "ImageFilterHdr",       id = 20 },
    { name = "Weapon",      icon = "Pistol",               id = 21 },
    { name = "POI",         icon = "MapMarkerStarOutline", id = 22 },
    { name = "Garage",      icon = "GarageVariant",        id = 23 }
}

-- Current Settings (Initialized from defaults)
Logic.settings = {}

Logic.currentMappinID = nil

local LOCATIONS_FILE = "locations.json"
local SETTINGS_FILE = "settings.json"

--- Initialize the module
function Logic.Init()
    for k, v in pairs(Logic.defaultSettings) do
        Logic.settings[k] = v
    end

    Logic.Load()
end

--- Load data from JSON
function Logic.Load()
    -- 1. Load Settings
    local sFile = io.open(SETTINGS_FILE, "r")
    if sFile then
        local content = sFile:read("*a")
        sFile:close()
        if content and content ~= "" then
            local data = json.decode(content)
            if data then
                for k, v in pairs(Logic.defaultSettings) do
                    if data[k] ~= nil then
                        Logic.settings[k] = data[k]
                    end
                end
            end
        end
    end

    -- 2. Load Locations (and check for legacy settings migration)
    local lFile = io.open(LOCATIONS_FILE, "r")
    if lFile then
        local content = lFile:read("*a")
        lFile:close()
        if content and content ~= "" then
            local data = json.decode(content)
            if data then
                Logic.locations = data.locations or {}

                -- MIGRATION: Ensure all locations have a category
                for _, loc in ipairs(Logic.locations) do
                    if not loc.category then
                        loc.category = "Misc"
                    end
                end

                -- MIGRATION: Check for legacy settings in locations.json
                if data.settings then
                    print(Utils.ConsolePrefix .. " Migrating settings from locations.json to settings.json...")
                    local savedSettings = data.settings
                    for k, v in pairs(Logic.defaultSettings) do
                        if savedSettings[k] ~= nil then
                            Logic.settings[k] = savedSettings[k]
                        end
                    end
                    -- Trigger Save to write clean files (split locations and settings)
                    Logic.Save()
                end
            end
        end
    end
end

--- Save data to JSON (Split Files)
function Logic.Save()
    -- 1. Save Settings
    local settingsToSave = {}
    for k, _ in pairs(Logic.defaultSettings) do
        settingsToSave[k] = Logic.settings[k]
    end

    local sFile = io.open(SETTINGS_FILE, "w")
    if sFile then
        sFile:write(json.encode(settingsToSave))
        sFile:close()
    else
        print(Utils.ConsolePrefix .. " Failed to save settings.")
    end

    -- 2. Save Locations (Clean, no settings)
    local lData = {
        locations = Logic.locations
    }

    local lFile = io.open(LOCATIONS_FILE, "w")
    if lFile then
        lFile:write(json.encode(lData))
        lFile:close()
    else
        print(Utils.ConsolePrefix .. " Failed to save locations.")
    end
end

--- Generates a unique ID
local function GenerateID()
    return os.time() .. "-" .. math.random(1000, 9999)
end

--- Get Player State (Pos, Rot, District)
---@return table|nil state {pos, rot, district, subDistrict}
function Logic.GetPlayerState()
    local player = Game.GetPlayer()
    if not player then return nil end

    local pos = player:GetWorldPosition()                    -- Vector4
    local rot = player:GetWorldOrientation():ToEulerAngles() -- EulerAngles
    local locData = Utils.GetLocationData(pos)

    return {
        pos = { x = pos.x, y = pos.y, z = pos.z, w = pos.w },
        rot = { pitch = rot.pitch, yaw = rot.yaw, roll = rot.roll },
        district = locData.district,
        subDistrict = locData.subDistrict
    }
end

--- Formatting helper for default names
function Logic.GetCoordString(state)
    return string.format("{x=%.0f, y=%.0f}", state.pos.x, state.pos.y)
end

--- Check if location already exists nearby
function Logic.CheckForDuplicate(newPos)
    local checkDist = Logic.settings.warningDistance

    -- If setting is 0 (disabled), we STILL check for essentially exact duplicates (e.g. < 0.5m)
    -- This prevents exact overlapping pins.
    if checkDist <= 0 then checkDist = 0.5 end

    local warningDistSq = checkDist * checkDist
    local pos1 = Vector4.new(newPos.x, newPos.y, newPos.z, newPos.w)

    for _, loc in ipairs(Logic.locations) do
        local pos2 = Vector4.new(loc.pos.x, loc.pos.y, loc.pos.z, loc.pos.w)
        local distSq = Vector4.DistanceSquared(pos1, pos2)

        if distSq <= warningDistSq then
            return true, loc.name, loc.id
        end
    end
    return false, nil, nil
end

--- Check if a location matches a search query
function Logic.CheckSearch(loc, query)
    if not query or query == "" then return true end

    local q = string.lower(query)
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
    return false
end

--- Return a list of locations matching the query (and optional category filter)
function Logic.SearchLocations(query, categoryFilter)
    local result = {}
    for _, loc in ipairs(Logic.locations) do
        if Logic.CheckSearch(loc, query) then
            if not categoryFilter or loc.category == categoryFilter then
                table.insert(result, loc)
            end
        end
    end
    return result
end

--- Create a new location data object (Transient, not added to DB)
function Logic.CreateLocationData()
    local state = Logic.GetPlayerState()
    if not state then return nil end

    local id = GenerateID()
    local name = Logic.settings.defaultName or "New Location"
    local desc = ""

    -- Auto Timestamp logic
    if Logic.settings.defaultDesc == "Timestamp" then
        desc = "Added: " .. os.date("%Y-%m-%d %H:%M:%S")
    elseif Logic.settings.defaultDesc and Logic.settings.defaultDesc ~= "" then
        desc = Logic.settings.defaultDesc
    end

    return {
        id = id,
        name = name,
        description = desc,
        category = "Misc", -- Default
        district = state.district,
        subDistrict = state.subDistrict,
        pos = state.pos,
        rot = state.rot,
        favorite = false,
        sourceType = "Manual Input",
        sourceDetail = ""
    }
end

--- Create a transient location data object from manually-entered coordinates.
--- District is intentionally NOT auto-detected (the game only reports the player's
--- current district, not an arbitrary XYZ) - it is tagged "Manual" so the user can
--- Refresh it once they have visited. Not added to the DB; caller decides.
---@param x number
---@param y number
---@param z number
---@param yaw number|nil Defaults to 0
---@param name string|nil Defaults to "Manual Location"
---@param category string|nil Defaults to "Misc"
---@return table loc
function Logic.CreateManualLocationData(x, y, z, yaw, name, category)
    local desc = ""
    if Logic.settings.defaultDesc == "Timestamp" then
        desc = "Added: " .. os.date("%Y-%m-%d %H:%M:%S")
    elseif Logic.settings.defaultDesc and Logic.settings.defaultDesc ~= "" then
        desc = Logic.settings.defaultDesc
    end

    return {
        id = GenerateID(),
        name = (name and name ~= "") and name or "Manual Location",
        description = desc,
        category = (category and category ~= "") and category or "Misc",
        district = "Manual",
        subDistrict = "",
        pos = { x = x, y = y, z = z, w = 1.0 },
        rot = { pitch = 0, yaw = yaw or 0, roll = 0 },
        favorite = false,
        sourceType = "Manual Coordinates",
        sourceDetail = ""
    }
end

--- Add a location to the database (Accepts existing data object OR name, desc, cat)
function Logic.AddLocation(arg1, arg2, arg3)
    local loc

    if type(arg1) == "table" then
        -- V2: AddLocation(dataObject)
        loc = arg1
    else
        -- V1: AddLocation(name, desc, category) - Legacy/QuickSave support
        loc = Logic.CreateLocationData()
        if loc then
            -- Logic.CreateLocationData() gives default "New Location" name.
            -- If arg1 (name) is provided, override it.
            if arg1 then loc.name = arg1 end
            if arg2 then loc.description = arg2 end
            if arg3 then loc.category = arg3 end
        end
    end

    if not loc then return nil end

    -- Check Timestamp logic only if using defaults
    if loc.name == "New Location" and Logic.settings.defaultDesc == "Timestamp" and (not loc.description or loc.description == "") then
        -- Legacy 3-arg callers get the default timestamp description.
        loc.description = "Added: " .. os.date("%Y-%m-%d %H:%M:%S")
    end

    table.insert(Logic.locations, loc)
    Logic.Save()
    return loc
end

---Imports a location object directly
---@param data table Location data (name, pos, rot, etc)
---@param preserveId boolean|nil If true, attempts to update existing ID instead of generating new
---@param sourceType string|nil Source of import (e.g., "SLM String", "SLM Preset", "AMM Import")
---@param sourceDetail string|nil Detail (e.g. filename)
---@return table newLoc
function Logic.ImportLocation(data, preserveId, sourceType, sourceDetail)
    -- 1. Preserve ID Update (Preset Sync)
    if preserveId and data.id then
        local existing = Logic.GetLocation(data.id)
        if existing then
            -- 1b. User Edit Protection
            if existing.sourceType and string.find(existing.sourceType, "%(Edited%)") then
                print(Utils.ConsolePrefix .. " [SKIP] Protected User-Edited Location: " .. existing.name)
                return existing
            end

            -- Update existing record
            existing.name = data.name or existing.name
            existing.description = data.description or existing.description
            existing.category = data.category or existing.category
            existing.pos = data.pos or existing.pos
            existing.rot = data.rot or existing.rot
            existing.district = data.district or existing.district
            existing.subDistrict = data.subDistrict or existing.subDistrict

            -- Metadata Update
            existing.sourceType = sourceType
            existing.sourceDetail = sourceDetail

            Logic.Save()
            print(Utils.ConsolePrefix .. " Synced Preset Location: " .. existing.name)
            return existing
        end
    end

    -- 2. New Import
    -- If preserveId is true, use data.id (when valid) instead of generating a new one.
    local newId = GenerateID()
    if preserveId and data.id then
        newId = data.id
    end
    local loc = {
        id = newId,
        name = data.name or "Imported Location",
        description = data.description or "",
        category = data.category or "Imported",
        district = data.district or "Unknown",
        subDistrict = data.subDistrict or "Unknown",
        pos = data.pos,
        rot = data.rot or { pitch = 0, yaw = 0, roll = 0 },
        favorite = false,
        sourceType = sourceType,
        sourceDetail = sourceDetail
    }
    table.insert(Logic.locations, loc)
    Logic.Save()
    print(Utils.ConsolePrefix .. " Imported Location: " .. loc.name)
    return loc
end

--- Get Location by ID
function Logic.GetLocationById(id)
    for _, loc in ipairs(Logic.locations) do
        if loc.id == id then
            return loc
        end
    end
    return nil
end

--- Quick save current location (Keybind action)
function Logic.QuickSaveLocation()
    local state = Logic.GetPlayerState()
    if not state then return end

    -- Use fixed name "Quicksave", nil description, nil category (defaults to Misc)
    local result = Logic.AddLocation("Quicksave", nil, nil)

    -- Only notify success if actual location was added (not duplicate)
    if result then
        Utils.Notify("Quick Saved Current Location")
        Utils.PlaySound("ui_hacking_access_granted")
        print(Utils.ConsolePrefix .. " Quick Saved current location.")
    end
end

--- Update an existing location
---@param id string
---@param name string|nil
---@param description string|nil
---@param favorite boolean|nil
---@param category string|nil
function Logic.UpdateLocation(id, name, description, favorite, category)
    for _, loc in ipairs(Logic.locations) do
        if loc.id == id then
            if name ~= nil then loc.name = name end
            if description ~= nil then loc.description = description end
            if favorite ~= nil then loc.favorite = favorite end
            if category ~= nil then loc.category = category end

            -- User Edit Protection: Mark as edited if from Preset
            if loc.sourceType and string.find(loc.sourceType, "SLM Preset") and not string.find(loc.sourceType, "%(Edited%)") then
                loc.sourceType = loc.sourceType .. " (Edited)"
            end

            Logic.Save()
            return true
        end
    end
    return false
end

--- Get a location by ID
---@param id string
---@return table|nil
function Logic.GetLocation(id)
    for _, loc in ipairs(Logic.locations) do
        if loc.id == id then
            return loc
        end
    end
    return nil
end

--- Delete a location
function Logic.DeleteLocation(id)
    for i, loc in ipairs(Logic.locations) do
        if loc.id == id then
            table.remove(Logic.locations, i)
            Logic.Save()
            break
        end
    end
end

--- Delete ALL locations
function Logic.DeleteAllLocations()
    Logic.locations = {}
    Logic.Save()
end

--- Reset settings to defaults
function Logic.ResetSettings()
    for k, v in pairs(Logic.defaultSettings) do
        Logic.settings[k] = v
    end

    Logic.Save()
    print(Utils.ConsolePrefix .. " Settings reset to defaults.")
end

--- Update only the position/district data of a location (Refresh)
function Logic.UpdateLocationPosition(id)
    local state = Logic.GetPlayerState()
    if not state then return end

    for i, loc in ipairs(Logic.locations) do
        if loc.id == id then
            loc.district = state.district
            loc.subDistrict = state.subDistrict
            loc.pos = state.pos
            loc.rot = state.rot
            loc.rot = state.rot

            -- User Edit Protection: Mark as edited if from Preset
            if loc.sourceType and string.find(loc.sourceType, "SLM Preset") and not string.find(loc.sourceType, "%(Edited%)") then
                loc.sourceType = loc.sourceType .. " (Edited)"
            end

            Logic.Save()
            print(Utils.ConsolePrefix .. " Updated position for location: " .. loc.name)
            break
        end
    end
end

--- Get a formatted name string for new locations
function Logic.GetDefaultNewLocationName()
    return "New Location"
end

--- Teleport the player
function Logic.TeleportTo(loc)
    if not loc or not loc.pos then return end

    local player = Game.GetPlayer()
    local pos = Vector4.new(loc.pos.x, loc.pos.y, loc.pos.z, loc.pos.w)
    local rot = EulerAngles.new(loc.rot.roll, loc.rot.pitch, loc.rot.yaw)

    Game.GetTeleportationFacility():Teleport(player, pos, rot)
    print(Utils.ConsolePrefix .. " Teleported to " .. loc.name)
end

--- Set a custom Map Pin
function Logic.SetMappin(loc)
    Logic.ClearMappin() -- Clear existing first

    if not loc or not loc.pos then return end

    local mappinData = MappinData.new()
    mappinData.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
    mappinData.variant = gamedataMappinVariant.CustomPositionVariant
    mappinData.visibleThroughWalls = true

    local pos = Vector4.new(loc.pos.x, loc.pos.y, loc.pos.z, loc.pos.w)

    Logic.currentMappinID = Game.GetMappinSystem():RegisterMappin(mappinData, pos)
    print(Utils.ConsolePrefix .. " Mappin set for " .. loc.name)
end

--- Clear the current Map Pin
function Logic.ClearMappin()
    if Logic.currentMappinID then
        Game.GetMappinSystem():UnregisterMappin(Logic.currentMappinID)
        Logic.currentMappinID = nil
        print(Utils.ConsolePrefix .. " Mappin cleared.")
    end
end

--- Get all categories (Defaults + Custom) sorted alphabetically
function Logic.GetCategories()
    local cats = {}
    -- Add defaults
    for _, c in ipairs(Logic.defaultCategories) do
        table.insert(cats, c)
    end
    -- Add custom
    if Logic.settings.customCategories then
        for _, c in ipairs(Logic.settings.customCategories) do
            table.insert(cats, c)
        end
    end

    -- Sort
    table.sort(cats, function(a, b) return a.name < b.name end)
    return cats
end

--- Add a custom category
function Logic.AddCategory(name, icon)
    if not name or name == "" then return false end

    -- Check duplicates
    local all = Logic.GetCategories()
    for _, c in ipairs(all) do
        if c.name == name then return false end
    end

    table.insert(Logic.settings.customCategories, { name = name, icon = (icon or "NewBox") })
    Logic.Save()
    return true
end

--- Merges imported custom categories into settings
---@param importCats table List of {name, icon}
---@return number countAdded
function Logic.MergeCustomCategories(importCats)
    if not importCats or #importCats == 0 then return 0 end

    local count = 0
    local changed = false

    -- Helper to check existence in Defaults or Custom
    local function Exists(name)
        for _, c in ipairs(Logic.defaultCategories) do
            if string.lower(c.name) == string.lower(name) then return true end
        end
        if Logic.settings.customCategories then
            for _, c in ipairs(Logic.settings.customCategories) do
                if string.lower(c.name) == string.lower(name) then return true end
            end
        end
        return false
    end

    -- Ensure list exists
    if not Logic.settings.customCategories then Logic.settings.customCategories = {} end

    for _, cat in ipairs(importCats) do
        if cat.name and cat.icon then
            if not Exists(cat.name) then
                table.insert(Logic.settings.customCategories, { name = cat.name, icon = cat.icon })
                count = count + 1
                changed = true
            end
        end
    end

    if changed then
        Logic.Save()
        print(Utils.ConsolePrefix .. " Merged " .. count .. " new custom categories.")
    end

    return count
end

--- Delete a custom category
function Logic.DeleteCategory(name)
    if not Logic.settings.customCategories then return end
    local initialSize = #Logic.settings.customCategories

    -- Remove by name (case insensitive)
    local newCats = {}
    for _, c in ipairs(Logic.settings.customCategories) do
        if string.lower(c.name) ~= string.lower(name) then
            table.insert(newCats, c)
        end
    end

    if #newCats < initialSize then
        Logic.settings.customCategories = newCats
        Logic.Save()

        -- Locations keep their category tag on purpose: they are not re-tagged. While the
        -- category is missing they fall back to the generic icon, and they re-link if the
        -- category is added back.
    end
end

--- Update a custom category (Rename and/or Change Icon)
function Logic.UpdateCategory(oldName, newName, newIcon)
    if not Logic.settings.customCategories then return false end

    -- Check if renaming to existing (duplicate check)
    if oldName ~= newName then
        local all = Logic.GetCategories()
        for _, c in ipairs(all) do
            if string.lower(c.name) == string.lower(newName) then return false end -- Exists
        end
    end

    for i, c in ipairs(Logic.settings.customCategories) do
        if c.name == oldName then
            c.name = newName
            c.icon = newIcon

            -- Update locations if name changed
            if oldName ~= newName then
                for _, loc in ipairs(Logic.locations) do
                    if loc.category == oldName then
                        loc.category = newName
                    end
                end
            end

            Logic.Save()
            return true
        end
    end
    return false
end

return Logic
