-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Utility functions for district detection and math.
-- Mod Version: 1.7.0
-- Credits: psiberx (CET Kit), community
-------------------------------------------------------------------

local Utils = {}

Utils.ConsolePrefix = IconGlyphs.LocationEnter .. " [SimpleLocationManager]"

--- Displays an on-screen notification
---@param text string
function Utils.Notify(text)
    local msg = SimpleScreenMessage.new()
    msg.isShown = true
    msg.duration = 3.0
    msg.message = text

    local blackboardDefs = Game.GetAllBlackboardDefs()
    if blackboardDefs and blackboardDefs.UI_Notifications then
        local blackboard = Game.GetBlackboardSystem():Get(blackboardDefs.UI_Notifications)
        if blackboard then
            blackboard:SetVariant(blackboardDefs.UI_Notifications.OnscreenMessage, ToVariant(msg), true)
        end
    end
end

--- Displays an on-screen warning notification
---@param text string
function Utils.NotifyWarning(text)
    local msg = SimpleScreenMessage.new()
    msg.isShown = true
    msg.duration = 4.0
    msg.message = text

    local blackboardDefs = Game.GetAllBlackboardDefs()
    if blackboardDefs and blackboardDefs.UI_Notifications then
        local blackboard = Game.GetBlackboardSystem():Get(blackboardDefs.UI_Notifications)
        if blackboard then
            blackboard:SetVariant(blackboardDefs.UI_Notifications.WarningMessage, ToVariant(msg), true)
        end
    end
end

--- Plays a sound event
---@param eventName string
function Utils.PlaySound(eventName)
    pcall(function()
        local audio = Game.GetAudioSystem()
        if audio then
            audio:Play(CName.new(eventName), nil, nil)
        end
    end)
end

-- ==================================================================
--  DISTRICT IDENTITY
-- ==================================================================

-- A location STORES a district's enum name and DRAWS its localised name. The enum name reads
-- the same in every language; the localised name does not, so storing one puts French text in
-- an export that an English install then groups as a district of its own.
--
-- Both directions are read from the player's own game rather than from a table here. The names
-- therefore agree with the world map in all nineteen languages, and this mod ships none of them.
local districtLabels = nil -- enum name -> localised label
local districtEnums = nil  -- localised label -> enum name

--- How far a record sits below a root district. The walk ends at Night City, which parents the
--- roots and is not a district anyone stands in.
---@param record userdata gamedataDistrict_Record
---@return number depth 0 for a root district, 1 for its direct child
local function DistrictDepth(record)
    local depth, ptr, seen = 0, record, {}

    while ptr and depth < 8 do
        local name = ptr:EnumName()
        if not name or name == "" or seen[name] then break end
        seen[name] = true

        local parent = ptr:ParentDistrict()
        if not parent then break end

        local parentName = parent:EnumName()
        if not parentName or parentName == "" or parentName == "NightCity" then break end

        depth = depth + 1
        ptr = parent
    end

    return depth
end

--- A record's name, which is held as a LocKey rather than as text.
---@param record userdata gamedataDistrict_Record
---@return string|nil
local function DistrictText(record)
    local name = record:LocalizedName()
    if not name or name == "" then return nil end

    if string.find(name, "LocKey#") then
        local text = GetLocalizedText(name)
        return (text and text ~= "") and text or nil
    end

    return name
end

--- Read every district record once and build both directions.
local function BuildDistrictMaps()
    local labels, enums, depths = {}, {}, {}

    local ok = pcall(function()
        local records = TweakDB:GetRecords("gamedataDistrict_Record")
        if not records then return end

        for _, record in ipairs(records) do
            local enum = record:EnumName()
            local text = DistrictText(record)

            if enum and enum ~= "" and text then
                labels[enum] = text

                -- The reverse direction covers only the depths a location can hold - a root
                -- district and its direct children, which is what the ancestry walk below
                -- takes. Deeper records repeat a label (three cyberspace interiors are all
                -- called "Unknown"), and a repeat here would rewrite a stored name onto the
                -- wrong district.
                local depth = DistrictDepth(record)
                if depth <= 1 then
                    local held = depths[text]
                    if held == nil or depth < held then
                        enums[text], depths[text] = enum, depth
                    elseif depth == held then
                        -- Two records at one depth answer to one name, so neither is the
                        -- answer. The label maps to nothing and passes through untouched.
                        enums[text] = nil
                    end
                end
            end
        end
    end)

    if not ok then
        Utils.Warn("District records are not readable. District names stay as they were stored.")
    end

    -- An empty result is cached like any other. Reading the record store is not free, and
    -- Utils.DistrictLabel is called for every row on screen, so retrying inside the draw
    -- would pay that cost every frame. UI.OnOverlayOpen is what asks again.
    districtLabels, districtEnums = labels, enums
end

--- Both maps, built on the first call.
---@return table labels, table enums
local function DistrictMaps()
    if not districtLabels then BuildDistrictMaps() end
    return districtLabels or {}, districtEnums or {}
end

--- Drop the maps so the next lookup rebuilds them.
--- District names come from the GAME's language, so a change there is what invalidates these -
--- not a change to the language this mod's own interface is pinned to.
function Utils.InvalidateDistrictMaps()
    districtLabels, districtEnums = nil, nil
end

--- True once the district records have actually been read.
--- The record store is not up at init on every load, and a district saved as a name cannot be
--- turned into an identifier until it is.
---@return boolean
function Utils.DistrictsReady()
    local labels = DistrictMaps()
    return next(labels) ~= nil
end

--- The name to DRAW for a stored district, in the language the game is running in.
--- A string that is no district enum - a point of interest the blackboard named, a district
--- stored before identifiers were kept - is returned unchanged.
---@param stored string|nil
---@return string|nil
function Utils.DistrictLabel(stored)
    if not stored or stored == "" then return stored end

    local labels = DistrictMaps()
    return labels[stored] or stored
end

--- The enum name behind a district LABEL, or nil where the game has no district by that name.
---@param label string|nil
---@return string|nil
function Utils.DistrictEnum(label)
    if type(label) ~= "string" or label == "" then return nil end

    local _, enums = DistrictMaps()
    return enums[label]
end

--- Gets the district data at the given position
---@param currPos Vector4
---@return table { district="EnumName", subDistrict="EnumName" }
function Utils.GetLocationData(currPos)
    local data = { district = "Unknown", subDistrict = "Unknown" }

    -- 1. Main District Recursive Logic
    pcall(function()
        local sys = Game.GetScriptableSystemsContainer():Get("PreventionSystem")
        if sys and sys.districtManager then
            local districtObj = sys.districtManager:GetCurrentDistrict()
            local currentRecord = nil

            if districtObj and districtObj.GetDistrictID then
                currentRecord = TweakDBInterface.GetDistrictRecord(districtObj:GetDistrictID())
            end

            if currentRecord then
                -- Build Ancestry: [Leaf, Parent, GrandParent, ... Root]
                local ancestry = {}
                local ptr = currentRecord
                while ptr do
                    table.insert(ancestry, ptr)
                    local parent = ptr:ParentDistrict()
                    -- The children of Night City are the roots, so an invalid parent or
                    -- "Night City" itself ends the walk.
                    if not parent or parent:EnumName() == "NightCity" then
                        break
                    end
                    ptr = parent
                end

                -- Determine Levels
                -- ancestry[#ancestry] is the Root (e.g. Watson)
                -- ancestry[#ancestry-1] is the Child (e.g. Little China)
                -- ancestry[1] is the Leaf (e.g. V's Apartment)

                -- EnumName rather than LocalizedName: what is stored has to read the same in
                -- every language. Utils.DistrictLabel turns it back into a name at draw time.
                if #ancestry > 0 then
                    local root = ancestry[#ancestry]
                    if root then
                        data.district = root:EnumName()
                    end

                    if #ancestry >= 2 then
                        local sub = ancestry[#ancestry - 1]
                        if sub then
                            data.subDistrict = sub:EnumName()
                        end
                    else
                        -- Only Root exists (Length 1)
                        if ancestry[1] then
                            data.subDistrict = ancestry[1]:EnumName()
                        end
                    end
                end
            end
        end
    end)


    -- 2. Sub-District Refinement (Blackboard)
    -- The recursive walk above already resolves the structure. This is a supplementary
    -- pass, and it only fills in a sub-district the walk could not name.
    --
    -- What it fills in is a NAME and not an identifier: the blackboard reports the point of
    -- interest the player is standing in, which is often no district at all and so has no
    -- enum to store. Utils.DistrictLabel passes a string it does not recognise straight
    -- through, so this reads back exactly as it was written.
    pcall(function()
        local blackboardDefs = GetAllBlackboardDefs()
        if blackboardDefs and blackboardDefs.UI_Map then
            local system = Game.GetBlackboardSystem()
            if system then
                local uiBlackboard = system:Get(blackboardDefs.UI_Map)
                if uiBlackboard then
                    local locStr = uiBlackboard:GetString(blackboardDefs.UI_Map.currentLocation)
                    if locStr and locStr ~= "" then
                        local localized = GetLocalizedText(locStr)
                        local bbText = (localized and localized ~= "") and localized or locStr

                        if bbText ~= "" and bbText ~= "Unknown" then
                            -- The blackboard text is a fallback: it applies only where the
                            -- recursive walk produced no sub-district.
                            if data.subDistrict == "Unknown" or data.subDistrict == nil then
                                data.subDistrict = bbText
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Cleanup: a LocKey the blackboard pass could not resolve. Only the sub-district can hold
    -- one - the district is an enum name and never was text.
    if data.subDistrict and string.find(data.subDistrict, "LocKey#") then
        local loc = GetLocalizedText(data.subDistrict)
        if loc and loc ~= "" then data.subDistrict = loc end
    end

    -- Special Case: Dogtown. These are enum names, so they are the same comparison in
    -- every language.
    if data.district == "Dogtown" or data.subDistrict == "Dogtown" then
        -- Force Dogtown to be the District if it appears anywhere
        if data.subDistrict == "Dogtown" and data.district == "Pacifica" then
            data.district = "Dogtown"
            data.subDistrict = nil
        elseif data.district == "Dogtown" then
            data.subDistrict = nil
        end
    end

    -- If subDistrict matches district, clear subDistrict
    if data.subDistrict == data.district then
        data.subDistrict = nil
    end

    -- Fallback
    if (data.district == "Unknown" or data.district == "") and data.subDistrict ~= "Unknown" then
        data.district = data.subDistrict
        data.subDistrict = nil
    end

    return data
end

-- Log levels, quietest first. A message is emitted when its own level is at or below the
-- setting, so "Warn" shows errors and warnings and nothing else.
Utils.LOG_LEVELS = { "Off", "Error", "Warn", "Info", "Debug" }

local LEVEL_VALUE = { Off = 0, Error = 1, Warn = 2, Info = 3, Debug = 4 }

-- What a fresh install gets. A normal load is silent at this level.
Utils.DEFAULT_LOG_LEVEL = "Warn"

local currentLevel = LEVEL_VALUE[Utils.DEFAULT_LOG_LEVEL]

--- Set the level by name. An unknown name falls back to the default rather than silencing
--- the mod, because a typo in a config file must not be the thing that hides an error.
---@param name string
function Utils.SetLogLevel(name)
    currentLevel = LEVEL_VALUE[name] or LEVEL_VALUE[Utils.DEFAULT_LOG_LEVEL]
end

--- The level currently in force, by name.
---@return string
function Utils.GetLogLevel()
    for name, value in pairs(LEVEL_VALUE) do
        if value == currentLevel then return name end
    end
    return Utils.DEFAULT_LOG_LEVEL
end

-- print() reaches the CET console and the CET log; spdlog reaches the mod's own log. Both
-- follow the level, so one setting governs everything this mod writes.
local function Emit(tag, msg)
    local line = Utils.ConsolePrefix .. " " .. tag .. tostring(msg)
    print(line)
    spdlog.info(line)
end

---@param msg string
function Utils.Error(msg)
    if currentLevel >= LEVEL_VALUE.Error then Emit("[ERROR] ", msg) end
end

---@param msg string
function Utils.Warn(msg)
    if currentLevel >= LEVEL_VALUE.Warn then Emit("[WARN] ", msg) end
end

---@param msg string
function Utils.Info(msg)
    if currentLevel >= LEVEL_VALUE.Info then Emit("", msg) end
end

---@param msg string
function Utils.Debug(msg)
    if currentLevel >= LEVEL_VALUE.Debug then Emit("[DEBUG] ", msg) end
end

--- Output the user asked for by pressing a button - a coordinate dump, a district dump, the
--- confirmation that an export reached the clipboard.
---
--- **Never gated by the level.** A dump that prints nothing reads as a broken button, not as a
--- quiet one, and the person who pressed it is already looking at the console.
---@param msg string
function Utils.Print(msg)
    local line = Utils.ConsolePrefix .. " " .. tostring(msg)
    print(line)
    spdlog.info(line)
end

--- Builds district info body (without markers) for both logging and preview display
local function _buildDistrictBody()
    local lines = {}

    local player = Game.GetPlayer()
    if player then
        local pos = player:GetWorldPosition()
        table.insert(lines, string.format("Player Pos: %.2f, %.2f, %.2f", pos.x, pos.y, pos.z))
    end

    -- Prevention System
    pcall(function()
        local sys = Game.GetScriptableSystemsContainer():Get("PreventionSystem")
        if sys and sys.districtManager then
            local d = sys.districtManager:GetCurrentDistrict()
            if d then
                table.insert(lines, "PreventionSystem District ID: " .. tostring(d:GetDistrictID().value))
                local rec = TweakDBInterface.GetDistrictRecord(d:GetDistrictID())
                if rec then
                    table.insert(lines, "  Record ID: " .. tostring(rec:GetID().value))
                    table.insert(lines, "  LocalizedName: " .. rec:LocalizedName())
                    table.insert(lines, "  EnumName: " .. rec:EnumName())
                    local parent = rec:ParentDistrict()
                    if parent then
                        table.insert(lines, "  Parent District:")
                        table.insert(lines, "    Record ID: " .. tostring(parent:GetID().value))
                        table.insert(lines, "    LocalizedName: " .. parent:LocalizedName())
                        table.insert(lines, "    EnumName: " .. parent:EnumName())
                    else
                        table.insert(lines, "  Parent: None")
                    end
                end
            else
                table.insert(lines, "PreventionSystem: No Current District Object")
            end
        else
            table.insert(lines, "PreventionSystem: Not found")
        end
    end)

    -- Blackboard
    pcall(function()
        local blackboardDefs = GetAllBlackboardDefs()
        if blackboardDefs and blackboardDefs.UI_Map then
            local sys = Game.GetBlackboardSystem()
            local bb = sys:Get(blackboardDefs.UI_Map)
            if bb then
                local loc = bb:GetString(blackboardDefs.UI_Map.currentLocation)
                table.insert(lines, "Blackboard UI_Map currentLocation: " .. tostring(loc))
                table.insert(lines, "  Localized: " .. GetLocalizedText(tostring(loc)))
            else
                table.insert(lines, "Blackboard UI_Map: Not found")
            end
        end
    end)

    return table.concat(lines, "\n")
end

--- Dumps full district info to the log for debugging
function Utils.DumpDistrictInfo()
    Utils.Print(" ====== District Debug Dump ======")
    Utils.Print(_buildDistrictBody())
    Utils.Print(" ====== End Dump ======")
end

--- Returns formatted district info string for preview display
function Utils.GetDistrictInfoString()
    local player = Game.GetPlayer()
    if not player then
        return "District info unavailable."
    end
    return _buildDistrictBody()
end

--- Formatting helper for numbers
function Utils.Round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

--- Formatting helper for debug info
function Utils.GetDebugInfoString()
    local player = Game.GetPlayer()
    if not player then return "Player not found" end

    local pos = player:GetWorldPosition()
    local rot = player:GetWorldOrientation():ToEulerAngles()

    return string.format("{x = %.4f, y = %.4f, z = %.4f, yaw = %.4f}",
        pos.x, pos.y, pos.z,
        rot.yaw)
end

--- Parse coordinates out of an arbitrary pasted string. In priority order it handles:
---   1. Labeled values - x= y= z= yaw= (also "x": for JSON, with '=' or ':'). Covers SLM's
---      Dump format, AMM JSON exports, and ToVector4{x=..} tables.
---   2. Positional CET command - Vector4.new(x, y, z[, w]) plus EulerAngles.new(roll, pitch, yaw).
---   3. A plain ordered number list ("x, y, z [yaw]") as a last resort.
---@param str string
---@return number|nil x
---@return number|nil y
---@return number|nil z
---@return number|nil yaw
function Utils.ParseCoordinates(str)
    if not str or str == "" then return nil end

    -- Prepend a space so a label at position 1 still has a non-letter boundary before it.
    -- The [^%a] guard stops "max"/"box" etc. from matching a bare x/y/z label.
    local s = " " .. string.lower(str)
    local NUM = "%-?%d+%.?%d*"

    -- Labeled grab: matches `x = ..`, `x: ..`, and JSON `"x": ..` (optional quote after label).
    local function grab(label)
        local v = string.match(s, "[^%a]" .. label .. '"?%s*[=:]%s*(' .. NUM .. ")")
        return v and tonumber(v) or nil
    end

    -- Yaw: prefer an explicit label, else the 3rd arg of EulerAngles.new(roll, pitch, yaw).
    local function grabYaw()
        local y = grab("yaw")
        if y then return y end
        local _, _, ey = string.match(s,
            "eulerangles%s*%.%s*new%s*%(%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")")
        return ey and tonumber(ey) or nil
    end

    -- 1. Labeled x / y / z
    local x, y, z = grab("x"), grab("y"), grab("z")
    if x and y and z then
        return x, y, z, grabYaw()
    end

    -- 2. Positional Vector4.new(x, y, z[, w]) - ignore the w component
    local vx, vy, vz = string.match(s,
        "vector4%s*%.%s*new%s*%(%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")%s*,%s*(" .. NUM .. ")")
    if vx and vy and vz then
        return tonumber(vx), tonumber(vy), tonumber(vz), grabYaw()
    end

    -- 3. Bare ordered number list ("x, y, z [yaw]")
    local nums = {}
    for n in string.gmatch(str, NUM) do
        table.insert(nums, tonumber(n))
    end
    if #nums >= 3 then
        return nums[1], nums[2], nums[3], nums[4]
    end

    return nil
end

return Utils
