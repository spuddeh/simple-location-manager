-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Core logic handling state, persistence, and game actions.
-- Mod Version: 1.7.0
-- Credits: psiberx (CET Kit), community
-------------------------------------------------------------------

local Utils = require("modules/utils")
local Env = require("modules/env")
local L = require("modules/loc").L

local Logic = {}

-- The weather hold is checked on onDraw frames rather than on a Cron timer. Cron ticks
-- from onUpdate, and onUpdate stops while the CET overlay is open - which is exactly
-- when a teleport happens. onDraw is on the render path and runs either way.
local WEATHER_CHECK_FRAMES = 10

-- Written into every pin this mod registers, and read back with IMappin.GetDisplayName().
-- debugCaption is the only identity channel a mappin has.
local MAPPIN_TAG = "SLM|"

-- Consecutive corrections before giving up. The count resets the moment the state
-- holds, so this only trips against something re-forcing every frame - a fight this
-- mod cannot win, and continuing it would leave two mods thrashing the sky.
local WEATHER_MAX_CORRECTIONS = 3

local weatherFrames = 0
local weatherCorrections = 0

-- State
Logic.locations = {}

-- Persistent Settings Defaults (Source of Truth)
Logic.defaultSettings = {
    defaultName = "New Location",
    defaultDesc = "Timestamp",
    warningDistance = 25.0,
    showCoords = false,
    showDistrict = false,
    language = "Auto",              -- "Auto" follows the game, or a language code
    defaultGroupState = "Expanded", -- "Expanded" or "Collapsed"
    groupBy = "District",           -- "District" or "Category"
    showSourceInfo = true,          -- Show source/conflict info
    envBlendTime = 5.0,             -- Weather transition length in seconds
    logLevel = Utils.DEFAULT_LOG_LEVEL, -- Off / Error / Warn / Info / Debug
    customCategories = {}           -- List of {name="X", icon="Y"}
}

-- Re-exported so the UI reaches time and weather through one module.
Logic.Env = Env

-- Default Categories (Hardcoded)
--
-- `name` is the stored value - it is written into every location, compared in code, and sent
-- in an export - so it is never translated. `key` is what the player reads, and it hangs off
-- the record beside the id rather than being derived from the name, so renaming a default
-- moves no translator's work.
--
-- `id` is the export code and MUST NOT CHANGE once released.
Logic.defaultCategories = {
    { name = "Apartment",   icon = "Home",                 id = 1,  key = "category.apartment" },
    { name = "Bar",         icon = "GlassWine",            id = 2,  key = "category.bar" },
    { name = "Cityscape",   icon = "City",                 id = 3,  key = "category.cityscape" },
    { name = "Clothing",    icon = "TshirtCrew",           id = 4,  key = "category.clothing" },
    { name = "Coffee",      icon = "Coffee",               id = 5,  key = "category.coffee" },
    { name = "Destination", icon = "MapMarkerStar",        id = 6,  key = "category.destination" },
    { name = "Enemy",       icon = "Skull",                id = 7,  key = "category.enemy" },
    { name = "Food",        icon = "FoodTakeoutBox",       id = 8,  key = "category.food" },
    { name = "Imported",    icon = "InboxArrowDown",       id = 9,  key = "category.imported" },
    { name = "Hidden Gem",  icon = "DiamondStone",         id = 10, key = "category.hiddenGem" },
    { name = "Loot",        icon = "TreasureChest",        id = 11, key = "category.loot" },
    { name = "Misc",        icon = "Help",                 id = 12, key = "category.misc" },
    { name = "NPC",         icon = "Human",                id = 13, key = "category.npc" },
    { name = "Photo Spot",  icon = "Camera",               id = 14, key = "category.photoSpot" },
    { name = "Quest",       icon = "ExclamationThick",     id = 15, key = "category.quest" },
    { name = "Restaurant",  icon = "SilverwareForkKnife",  id = 16, key = "category.restaurant" },
    { name = "Saved",       icon = "ContentSave",          id = 17, key = "category.saved" },
    { name = "Vehicle",     icon = "CarSide",              id = 18, key = "category.vehicle" },
    { name = "Vendor",      icon = "CurrencyUsd",          id = 19, key = "category.vendor" },
    { name = "Vista",       icon = "ImageFilterHdr",       id = 20, key = "category.vista" },
    { name = "Weapon",      icon = "Pistol",               id = 21, key = "category.weapon" },
    { name = "POI",         icon = "MapMarkerStarOutline", id = 22, key = "category.poi" },
    { name = "Garage",      icon = "GarageVariant",        id = 23, key = "category.garage" }
}

-- Stored category name -> its key, read off the records above so the two cannot drift apart.
local DEFAULT_CATEGORY_KEYS = {}
for _, c in ipairs(Logic.defaultCategories) do DEFAULT_CATEGORY_KEYS[c.name] = c.key end

--- The name to DRAW for a stored category.
--- A category the player made is their own words and is drawn as they typed it; only the
--- defaults SLM ships are interface strings.
---@param name string|nil A stored category name
---@return string label
function Logic.CategoryLabel(name)
    if not name or name == "" then return L("category.misc") end

    local key = DEFAULT_CATEGORY_KEYS[name]
    return key and L(key) or name
end

-- Districts this mod stores itself, which the game therefore cannot name. Every other stored
-- district is an enum name the game names in all nineteen of its languages, so it needs no
-- key here. The stored word is never translated, only mapped to a label - it is compared in
-- code and written into saves, the same way GROUP_BY_KEYS and loc.favorite are.
local DISTRICT_KEYS = {
    ["Unknown"] = "district.unknown",
    ["Manual"] = "district.manual",
}

--- The name to DRAW for a stored district, in the game's language.
--- Nil and empty answer to the same label as "Unknown", because that is the district a
--- location with none has. A sub-district is optional and its callers check for empty before
--- asking, so nothing here has to tell the two apart.
---@param stored string|nil A stored district or sub-district
---@return string label
function Logic.DistrictLabel(stored)
    if not stored or stored == "" then return L("district.unknown") end

    local key = DISTRICT_KEYS[stored]
    if key then return L(key) end

    -- A point of interest the blackboard named, or a district saved before identifiers were
    -- kept, is drawn exactly as it stands.
    return Utils.DistrictLabel(stored) or stored
end

-- Districts stored as display text, from before identifiers were kept. Migrating one needs the
-- game's own district records, which are not readable at init on every load, so the pass runs
-- again from the overlay and stops asking once it has worked.
local districtsMigrated = false

--- Rewrite every district still stored as a name into the enum name behind it.
---
--- The reverse map is read from the player's own game, so a French install migrates its French
--- names and this mod ships no name to do it with. A string the game does not name is left as
--- it stands and still draws as itself.
---
--- Safe to call repeatedly: an enum name maps to itself.
---@return boolean done True once the district records have been read
function Logic.MigrateDistricts()
    if districtsMigrated then return true end
    if not Utils.DistrictsReady() then return false end

    local changed = 0
    for _, loc in ipairs(Logic.locations) do
        local district = Utils.DistrictEnum(loc.district)
        if district and district ~= loc.district then
            loc.district = district
            changed = changed + 1
        end

        local subDistrict = Utils.DistrictEnum(loc.subDistrict)
        if subDistrict and subDistrict ~= loc.subDistrict then
            loc.subDistrict = subDistrict
            changed = changed + 1
        end
    end

    districtsMigrated = true

    if changed > 0 then
        Utils.Info("Stored " .. changed .. " district names as identifiers.")
        Logic.Save()
    end

    return true
end

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

    -- Utils owns the level and cannot read it back from here: logic requires utils, so the
    -- reverse would be a cycle. The setting is pushed instead, here and wherever it changes.
    Utils.SetLogLevel(Logic.settings.logLevel)
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
                    Utils.Info("Migrating settings from locations.json to settings.json...")
                    local savedSettings = data.settings
                    for k, v in pairs(Logic.defaultSettings) do
                        if savedSettings[k] ~= nil then
                            Logic.settings[k] = savedSettings[k]
                        end
                    end
                    -- Trigger Save to write clean files (split locations and settings)
                    Logic.Save()
                end

                -- MIGRATION: districts stored as display text. This is the earliest it can be
                -- tried; UI.OnOverlayOpen tries again for the loads where the record store
                -- was not up yet.
                Logic.MigrateDistricts()
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
        Utils.Error("Failed to save settings.")
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
        Utils.Error("Failed to save locations.")
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

    -- 0 disables the warning, but the check still runs at 0.5m to prevent exactly overlapping pins.
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
    -- Both the name on screen and the identifier behind it: a player searches for what they
    -- can see, and an identifier read off an export should still find its location.
    local dist = string.lower(Logic.DistrictLabel(loc.district) .. " " .. (loc.district or ""))
    local sub = string.lower((loc.subDistrict and Logic.DistrictLabel(loc.subDistrict) or "") ..
        " " .. (loc.subDistrict or ""))
    local cat = string.lower(Logic.CategoryLabel(loc.category) .. " " .. (loc.category or ""))

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
                Utils.Info("[SKIP] Protected User-Edited Location: " .. existing.name)
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
            existing.env = data.env or existing.env

            -- Metadata Update
            existing.sourceType = sourceType
            existing.sourceDetail = sourceDetail

            Logic.Save()
            Utils.Debug("Synced Preset Location: " .. existing.name)
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
        env = data.env,
        favorite = false,
        sourceType = sourceType,
        sourceDetail = sourceDetail
    }
    table.insert(Logic.locations, loc)
    Logic.Save()
    Utils.Debug("Imported Location: " .. loc.name)
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
        Utils.Notify(L("quickSaveLocation.quickSavedCurrentLocation"))
        Utils.PlaySound("ui_hacking_access_granted")
        Utils.Info("Quick Saved current location.")
    end
end

--- User Edit Protection: a preset location the user has changed is tagged so the
--- preset auto-sync leaves it alone.
---@param loc table
function Logic.MarkPresetEdited(loc)
    if not loc or not loc.sourceType then return end
    if not string.find(loc.sourceType, "SLM Preset") then return end
    if string.find(loc.sourceType, "%(Edited%)") then return end

    loc.sourceType = loc.sourceType .. " (Edited)"
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

            Logic.MarkPresetEdited(loc)

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

    Utils.SetLogLevel(Logic.settings.logLevel)
    Logic.Save()
    Utils.Info("Settings reset to defaults.")
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

            Logic.MarkPresetEdited(loc)

            Logic.Save()
            Utils.Info("Updated position for location: " .. loc.name)
            break
        end
    end
end

--- Get a formatted name string for new locations
function Logic.GetDefaultNewLocationName()
    return "New Location"
end

--- Teleport the player.
--- Time and weather are applied only when asked for, so the caller's gesture decides:
--- the location list teleports plainly on left click and with the saved time and
--- weather on right click.
---@param loc table
---@param applyEnv boolean|nil
function Logic.TeleportTo(loc, applyEnv)
    if not loc or not loc.pos then return end

    local player = Game.GetPlayer()
    local pos = Vector4.new(loc.pos.x, loc.pos.y, loc.pos.z, loc.pos.w)
    local rot = EulerAngles.new(loc.rot.roll, loc.rot.pitch, loc.rot.yaw)

    Game.GetTeleportationFacility():Teleport(player, pos, rot)
    Utils.Debug("Teleported to " .. loc.name)

    if applyEnv then
        Logic.ApplyLocationEnv(loc)
    else
        -- A plain teleport is a request for this mod to stay out of the time and the
        -- weather. Leaving an earlier hold in place would carry one location's sky to
        -- every location reached without asking for it.
        Logic.ReleaseWeatherHold()
    end
end

--- Apply a location's saved time and weather.
--- A weather state the current game does not have is skipped, and the time still lands.
---@param loc table
function Logic.ApplyLocationEnv(loc)
    if not loc or not loc.env then
        Logic.ReleaseWeatherHold()
        return
    end

    local report = Env.Apply(loc.env, Logic.settings.envBlendTime)

    if report.missingWeather then
        Utils.NotifyWarning(L("weather.notInstalled", Env.GetWeatherLabel(report.missingWeather)))
        Logic.ReleaseWeatherHold()
        return
    end

    -- No weather on this location, or the picker left it alone: the sky is not this
    -- location's business, so it goes back to the game rather than keeping the last
    -- location's state.
    if not report.weatherApplied then
        Logic.ReleaseWeatherHold()
    end
end

--- Hand the weather back to the game's cycle, but only where this mod is holding it.
--- Another mod's forced weather is not this mod's to undo.
function Logic.ReleaseWeatherHold()
    if not Env.GetForcedState() then return end

    if Env.ResetWeather(Logic.settings.envBlendTime) then
        Utils.Info("Weather returned to the game's cycle.")
    end
    weatherCorrections = 0
end

--- Keep the weather on the state this mod last forced.
---
--- Called every rendered frame, from onDraw, whether or not the CET overlay is open.
--- The game moves the weather off a forced state on its own - a teleport is enough to
--- do it, and the state it lands on is not the one that was asked for. A single set is
--- therefore not a hold, which is what the padlock in the footer claims it is, so the
--- state is put back whenever it drifts.
---
--- Corrections are consecutive, and the count resets as soon as the state holds. Only
--- something re-forcing every frame can exhaust it, and against that the hold is
--- released rather than thrashing the sky between two mods.
function Logic.Tick()
    local status, forced = Env.GetHoldStatus()
    if status ~= "held" or not forced then
        weatherFrames = 0
        weatherCorrections = 0
        return
    end

    weatherFrames = weatherFrames + 1
    if weatherFrames < WEATHER_CHECK_FRAMES then return end
    weatherFrames = 0

    if Env.GetCurrentWeather() == forced then
        weatherCorrections = 0
        return
    end

    if weatherCorrections < WEATHER_MAX_CORRECTIONS then
        weatherCorrections = weatherCorrections + 1
        Env.SetWeather(forced, Logic.settings.envBlendTime)
        return
    end

    local actual = Env.GetCurrentWeather()
    Utils.NotifyWarning(L("weather.overriddenByAnotherMod", Env.GetWeatherLabel(actual)))
    Utils.Warn("Gave up holding " .. forced ..
        ", game is in " .. tostring(actual) ..
        ". Another mod is re-forcing the weather every frame - clear its lock first.")

    Env.MarkHoldLost()
    weatherCorrections = 0
end

--- Set or clear a location's saved time and weather.
---@param id string
---@param env table|nil nil clears it
---@return boolean applied
function Logic.SetLocationEnv(id, env)
    local loc = Logic.GetLocation(id)
    if not loc then return false end

    -- Nothing to record when the location had none and is still getting none.
    if loc.env == nil and env == nil then return true end

    loc.env = env
    Logic.MarkPresetEdited(loc)
    Logic.Save()
    return true
end

--- Reads the id sitting in the game's manually-tracked waypoint slot.
--- A NewMappinID read inline off the call returns a heap pointer rather than the id, so the
--- struct is bound to a local before the field is read.
---@return number|nil value nil when nothing is tracked or the system is unavailable
local function GetTrackedMappinValue()
    local sys = Game.GetMappinSystem()
    if not sys then return nil end

    local id = sys:GetManuallyTrackedMappinID()
    if not id then return nil end

    local value = id.value
    if not value or value == 0 then return nil end
    return value
end

--- True while the tracked waypoint slot holds this mod's own pin.
local function OwnsTrackedSlot()
    if not Logic.currentMappinID then return false end
    local tracked = GetTrackedMappinValue()
    return tracked ~= nil and tracked == Logic.currentMappinID.value
end

--- Set a custom Map Pin
function Logic.SetMappin(loc)
    Logic.ClearMappin() -- Clear existing first

    if not loc or not loc.pos then return end

    local mappinData = MappinData.new()
    mappinData.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
    mappinData.variant = gamedataMappinVariant.CustomPositionVariant
    mappinData.visibleThroughWalls = true

    -- Identity. IMappin.GetDisplayName() reads this back, which is the only way a mod can
    -- tell its own pin from the player's or another mod's. Guarded because a native field
    -- rejected by the binding throws and would take the whole registration with it.
    pcall(function()
        mappinData.debugCaption = MAPPIN_TAG .. (loc.name or "")
    end)

    -- CustomPositionVariant means "this is the player's waypoint", so the game adopts the
    -- newest routable one and the slot moves. Setting a pin is something the player asked
    -- for, so the slot is taken rather than refused - but a waypoint that was already there
    -- stops routing, and that is worth saying out loud. The check runs after ClearMappin,
    -- so anything still tracked belongs to someone else.
    local replacedTracked = GetTrackedMappinValue()

    local pos = Vector4.new(loc.pos.x, loc.pos.y, loc.pos.z, loc.pos.w)

    Logic.currentMappinID = Game.GetMappinSystem():RegisterMappin(mappinData, pos)
    Utils.Debug("Mappin set for " .. loc.name)

    if replacedTracked then
        Utils.Notify(L("mappin.waypointReplacedBy", loc.name))
    end
end

--- Clear the current Map Pin
function Logic.ClearMappin()
    if not Logic.currentMappinID then return end

    local sys = Game.GetMappinSystem()
    if not sys then
        Logic.currentMappinID = nil
        return
    end

    -- UntrackMappin takes no argument and clears whatever is in the slot, so it is only
    -- called once the slot is known to hold this mod's pin. Untracking anything else would
    -- take the player's own route away.
    if OwnsTrackedSlot() then
        sys:UntrackMappin()
    end

    sys:UnregisterMappin(Logic.currentMappinID)
    Logic.currentMappinID = nil
    Utils.Debug("Mappin cleared.")
end

--- Drops the handle to a pin that no longer exists.
--- A NewMappinID is per-session: it does not survive a save/load, so the pin registered in
--- the previous session is already gone and the stored handle addresses nothing. Nothing is
--- unregistered here, because the id could by then belong to a pin this mod does not own.
function Logic.InvalidateMappin()
    Logic.currentMappinID = nil
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

    -- A-Z by the name on screen. Sorting on the stored name would file the defaults in English
    -- order for a player reading them in their own language.
    local labels = {}
    for _, c in ipairs(cats) do labels[c.name] = Logic.CategoryLabel(c.name) end
    table.sort(cats, function(a, b) return labels[a.name] < labels[b.name] end)
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
        Utils.Info("Merged " .. count .. " new custom categories.")
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

--- Bucket locations into ordered groups, the same way the Locations tab does.
--- Takes an already-filtered list and shapes it; it draws nothing and holds no state, so a
--- caller decides for itself how a group is headed and whether it can be collapsed.
---@param locations table Locations to group, already filtered
---@param groupBy string|nil "District", "Category" or "A-Z" (default "District")
---@return table groups Array of { key, name, icon, locations }, empty groups dropped
function Logic.GroupLocations(locations, groupBy)
    groupBy = groupBy or "District"

    if groupBy == "A-Z" then
        local flat = {}
        for _, loc in ipairs(locations) do table.insert(flat, loc) end
        table.sort(flat, function(a, b) return (a.name or "") < (b.name or "") end)
        return { { key = "az", name = "A-Z", icon = nil, locations = flat } }
    end

    if groupBy == "Category" then
        -- Walked in GetCategories order rather than by what the locations mention, so the
        -- groups come out in the same order as the Category Manager lists them.
        local groups = {}
        for _, cat in ipairs(Logic.GetCategories()) do
            local bucket = {}
            for _, loc in ipairs(locations) do
                if loc.category == cat.name then table.insert(bucket, loc) end
            end
            if #bucket > 0 then
                table.sort(bucket, function(a, b) return (a.name or "") < (b.name or "") end)
                table.insert(groups, {
                    key = "cat_" .. cat.name,
                    name = Logic.CategoryLabel(cat.name),
                    icon = cat.icon,
                    locations = bucket,
                })
            end
        end
        return groups
    end

    -- Bucketed on the STORED district and headed with its label. Keying on the label instead
    -- would give the group a different key in every language, and the collapsed state a
    -- player set is remembered against that key.
    local byDistrict = {}
    local order = {}
    for _, loc in ipairs(locations) do
        local dName = loc.district or "Unknown"
        if not byDistrict[dName] then
            byDistrict[dName] = {}
            table.insert(order, dName)
        end
        table.insert(byDistrict[dName], loc)
    end

    -- A-Z in the language on screen, which is not A-Z by identifier: "The Glen" files under T
    -- for an English player and under G for nobody.
    local labels = {}
    for _, dName in ipairs(order) do labels[dName] = Logic.DistrictLabel(dName) end
    table.sort(order, function(a, b) return labels[a] < labels[b] end)

    local groups = {}
    for _, dName in ipairs(order) do
        local bucket = byDistrict[dName]
        table.sort(bucket, function(a, b) return (a.name or "") < (b.name or "") end)
        table.insert(groups, {
            key = "dist_" .. dName,
            name = labels[dName],
            icon = "MapMarker",
            locations = bucket,
        })
    end
    return groups
end

--- Custom categories no location uses.
--- Only custom ones: the defaults are the fixed list every location falls back into, and an
--- empty default is the normal state rather than something to tidy away. Names are compared
--- without case, the same way DeleteCategory removes them.
---@return table unused Array of { name, icon }, sorted by name
function Logic.GetUnusedCustomCategories()
    if not Logic.settings.customCategories then return {} end

    local used = {}
    for _, loc in ipairs(Logic.locations) do
        if loc.category then used[string.lower(loc.category)] = true end
    end

    local unused = {}
    for _, c in ipairs(Logic.settings.customCategories) do
        if not used[string.lower(c.name)] then
            table.insert(unused, { name = c.name, icon = c.icon })
        end
    end

    table.sort(unused, function(a, b) return a.name < b.name end)
    return unused
end

--- Delete several custom categories at once.
--- One Save at the end rather than one per category, so a list of twenty is a single write.
---@param names table<string, boolean> Set of category names to remove, keyed by name
---@return number removed
function Logic.DeleteCategories(names)
    if not Logic.settings.customCategories then return 0 end

    local wanted = {}
    for name, on in pairs(names) do
        if on then wanted[string.lower(name)] = true end
    end

    local kept = {}
    for _, c in ipairs(Logic.settings.customCategories) do
        if not wanted[string.lower(c.name)] then
            table.insert(kept, c)
        end
    end

    local removed = #Logic.settings.customCategories - #kept
    if removed > 0 then
        Logic.settings.customCategories = kept
        Logic.Save()
        Utils.Info("Removed " .. removed .. " unused custom categor" ..
            (removed == 1 and "y." or "ies."))
    end
    return removed
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
