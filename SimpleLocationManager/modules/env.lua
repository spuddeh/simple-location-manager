-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Reads and applies the game's time of day and weather state.
-- Mod Version: 1.5.0
-- Credits: psiberx (CET Kit), psiberx (Codeware), community
-------------------------------------------------------------------

-- SetWeather, ResetWeather, GetWeatherState and GetEnvironmentDefinition are added to
-- WeatherSystem by Codeware at runtime. The IDE's CET type stubs describe vanilla CET,
-- so they read as undefined fields there and the check is switched off for this file.
---@diagnostic disable: undefined-field
---@diagnostic disable: undefined-global

local Utils = require("modules/utils")

local Env = {}

-- Every weather call is behind an availability check, so an install without Codeware
-- gets time of day and nothing else rather than an error.
local WEATHER_PRIORITY = 9
local DEFAULT_BLEND = 5.0
local TIME_REASON = "SimpleLocationManager"

-- The state list only changes when the environment definition swaps, which happens
-- on a load rather than per frame, so it is built once and dropped on session end.
-- The map beside it exists because the location list asks "does this state exist?"
-- once per row per frame, and a linear scan of forty states is not free at that rate.
local stateCache = nil
local stateById = nil

--- Turn a raw state id into something readable.
--- "24h_weather_fog_heavy" becomes "Fog Heavy".
---@param id string
---@return string label
local function PrettyLabel(id)
    local body = id:gsub("^24h_weather_", "")
    body = body:gsub("_", " ")
    return (body:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest
    end))
end

--- The weather system, or nil before the player is attached.
local function GetWeatherSystem()
    if not Game or not Game.GetWeatherSystem then return nil end
    return Game.GetWeatherSystem()
end

--- True when Codeware's WeatherSystem methods are present.
--- Checked through the system rather than through Codeware itself, because the
--- methods are what this module needs and a Codeware old enough to lack them would
--- still answer a version query.
---@return boolean
function Env.IsWeatherAvailable()
    local sys = GetWeatherSystem()
    return sys ~= nil and sys.SetWeather ~= nil and sys.GetWeatherState ~= nil
end

--- The installed Codeware version, or nil when it is absent.
--- Usable before the player attaches, which Env.IsWeatherAvailable is not.
---@return string|nil
function Env.GetCodewareVersion()
    local ok, version = pcall(function() return Codeware.Version() end)
    if ok and type(version) == "string" and version ~= "" then
        return version
    end
    return nil
end

--- Drop the cached state list. Called when a session ends, because a different
--- save can load a different environment definition.
function Env.InvalidateCache()
    stateCache = nil
    stateById = nil
end

--- Every weather state the loaded environment actually has.
--- This is read from the environment definition rather than from a bundled list, so
--- states added by another mod (Nova City 2 and the like) appear here without SLM
--- knowing anything about that mod.
---@return table states Array of { id = string, label = string }
function Env.GetWeatherStates()
    if stateCache then return stateCache end

    local list = {}
    local sys = GetWeatherSystem()

    if sys and sys.GetEnvironmentDefinition then
        local def = sys:GetEnvironmentDefinition()
        if def and def.weatherStates then
            for _, state in ipairs(def.weatherStates) do
                local name = state and state.name
                local id = name and name.value
                if id and id ~= "" then
                    table.insert(list, { id = id, label = PrettyLabel(id) })
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    -- An empty list is not cached: the environment definition is not ready until the
    -- player attaches, and caching {} there would leave the picker permanently blank.
    if #list > 0 then
        stateCache = list
        stateById = {}
        for _, state in ipairs(list) do
            stateById[state.id] = state.label
        end
    end

    return list
end

--- Whether a saved state id still exists in this playthrough.
--- The check is what lets a location saved with a modded weather load on a machine
--- that no longer has that mod.
---@param id string|nil
---@return boolean
function Env.HasWeatherState(id)
    if not id or id == "" then return false end
    Env.GetWeatherStates()
    return stateById ~= nil and stateById[id] ~= nil
end

--- Readable name for a state id, whether or not it is currently installed.
---@param id string|nil
---@return string
function Env.GetWeatherLabel(id)
    if not id or id == "" then return "None" end
    Env.GetWeatherStates()
    return (stateById and stateById[id]) or PrettyLabel(id)
end

--- The weather state the game is in right now.
---@return string|nil id
function Env.GetCurrentWeather()
    local sys = GetWeatherSystem()
    if not sys or not sys.GetWeatherState then return nil end

    local state = sys:GetWeatherState()
    if not state or not state.name then return nil end

    local id = state.name.value
    if not id or id == "" then return nil end
    return id
end

--- The current time of day.
---@return table|nil time { h, m, s }
function Env.GetCurrentTime()
    if not Game or not Game.GetTimeSystem then return nil end

    local ts = Game.GetTimeSystem()
    if not ts then return nil end

    local gt = ts:GetGameTime()
    if not gt then return nil end

    return {
        h = GameTime.Hours(gt),
        m = GameTime.Minutes(gt),
        s = GameTime.Seconds(gt)
    }
end

--- Set the time of day.
---@param time table { h, m, s }
---@return boolean applied
function Env.SetTime(time)
    if not time then return false end
    if not Game or not Game.GetTimeSystem then return false end

    local ts = Game.GetTimeSystem()
    if not ts then return false end

    ts:SetGameTimeByHMS(
        math.floor(time.h or 0),
        math.floor(time.m or 0),
        math.floor(time.s or 0),
        TIME_REASON
    )
    return true
end

--- Force a weather state.
--- Forcing stops the natural weather cycle until Env.ResetWeather is called.
---@param id string
---@param blendTime number|nil Seconds, defaults to 5
---@return boolean applied
function Env.SetWeather(id, blendTime)
    if not id or id == "" then return false end

    local sys = GetWeatherSystem()
    if not sys or not sys.SetWeather then return false end

    return sys:SetWeather(id, blendTime or DEFAULT_BLEND, WEATHER_PRIORITY) == true
end

--- Hand weather back to the natural cycle.
---@param blendTime number|nil
---@return boolean applied
function Env.ResetWeather(blendTime)
    local sys = GetWeatherSystem()
    if not sys or not sys.ResetWeather then return false end

    return sys:ResetWeather(false, blendTime or DEFAULT_BLEND) == true
end

--- Snapshot the current time and weather, in the shape a location stores.
---@return table|nil env { time = { h, m, s }, weather = string|nil }
function Env.Capture()
    local time = Env.GetCurrentTime()
    if not time then return nil end

    return {
        time = time,
        weather = Env.GetCurrentWeather()
    }
end

--- Apply a stored snapshot.
--- Time and weather are independent: a missing weather state skips only the weather.
---@param env table|nil The location's stored snapshot
---@param blendTime number|nil
---@return table report { timeApplied, weatherApplied, missingWeather }
function Env.Apply(env, blendTime)
    local report = { timeApplied = false, weatherApplied = false, missingWeather = nil }
    if not env then return report end

    if env.time then
        report.timeApplied = Env.SetTime(env.time)
    end

    if env.weather and env.weather ~= "" then
        if not Env.IsWeatherAvailable() then
            report.missingWeather = env.weather
        elseif not Env.HasWeatherState(env.weather) then
            -- The state was saved by a playthrough that had a weather mod this one
            -- does not. Skipping it leaves the rest of the teleport intact.
            report.missingWeather = env.weather
            print(Utils.ConsolePrefix .. " Weather state not present in this game: " .. env.weather)
        else
            report.weatherApplied = Env.SetWeather(env.weather, blendTime)
            if not report.weatherApplied then
                report.missingWeather = env.weather
            end
        end
    end

    return report
end

--- Format a snapshot for display in the location list and the edit modal.
---@param env table|nil
---@return string
function Env.Describe(env)
    if not env then return "" end

    local parts = {}
    if env.time then
        table.insert(parts, string.format("%02d:%02d", env.time.h or 0, env.time.m or 0))
    end
    if env.weather and env.weather ~= "" then
        table.insert(parts, Env.GetWeatherLabel(env.weather))
    end

    return table.concat(parts, " - ")
end

return Env
