-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Utility functions for district detection and math.
-- Mod Version: 1.5.0
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

--- Gets the district data at the given position
---@param currPos Vector4
---@return table { district="Name", subDistrict="Name" }
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
                    -- Stop if parent is invalid or is "Night City" (we want the children of Night City as roots)
                    if not parent or parent:EnumName() == "NightCity" then
                        break
                    end
                    ptr = parent
                end

                -- Determine Levels
                -- ancestry[#ancestry] is the Root (e.g. Watson)
                -- ancestry[#ancestry-1] is the Child (e.g. Little China)
                -- ancestry[1] is the Leaf (e.g. V's Apartment)

                if #ancestry > 0 then
                    local root = ancestry[#ancestry]
                    if root then
                        data.district = root:LocalizedName()
                    end

                    if #ancestry >= 2 then
                        local sub = ancestry[#ancestry - 1]
                        if sub then
                            data.subDistrict = sub:LocalizedName()
                        end
                    else
                        -- Only Root exists (Length 1)
                        if ancestry[1] then
                            data.subDistrict = ancestry[1]:LocalizedName()
                        end
                    end
                end
            end
        end
    end)


    -- 2. Sub-District Refinement (Blackboard)
    -- If we have a valid structure, we might check if blackboard gives a more specific name for the LEAF
    -- But our recursive logic already handles the structure well.
    -- We'll keep this as a supplementary check if subDistrict is "Unknown" or same as District
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
                            -- Only use BB text if we don't have a good subDistrict, OR if it matches our recursive logic
                            if data.subDistrict == "Unknown" or data.subDistrict == nil then
                                data.subDistrict = bbText
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Cleanup: Handle LocKey entries
    if data.district and string.find(data.district, "LocKey#") then
        local loc = GetLocalizedText(data.district)
        if loc and loc ~= "" then data.district = loc end
    end
    if data.subDistrict and string.find(data.subDistrict, "LocKey#") then
        local loc = GetLocalizedText(data.subDistrict)
        if loc and loc ~= "" then data.subDistrict = loc end
    end

    -- Special Case: Dogtown
    if data.district == "Dogtown" or data.subDistrict == "Dogtown" then
        -- Force Dogtown to be the District if it appears anywhere
        if data.subDistrict == "Dogtown" and data.district == "Pacificia" then
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

--- Log to both Console and File (spdlog) through Utils
---@param msg string
function Utils.Log(msg)
    -- Normalize message
    local str = tostring(msg)

    -- Print to CET Console Overlay (requires explicit prefix if desired, but we usually want cleaner output here if it's a dump)
    -- User wanted ConsolePrefix for console logs.
    -- The print() goes to CET Console AND CET Log.
    -- spdlog goes to mod-specific log.

    -- Let's just print exactly what we want.
    print(str)

    -- Log to spdlog (mod log)
    spdlog.info(str)
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
    Utils.Log(" ====== District Debug Dump ======")
    Utils.Log(_buildDistrictBody())
    Utils.Log(" ====== End Dump ======")
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

return Utils
