-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Loads the interface strings for the player's language.
-- Mod Version: 1.7.0
-- Credits: community translators
-------------------------------------------------------------------

-- Requires nothing but Utils, and Utils requires nothing at all. Every other module
-- draws text, so anything heavier here would close a require loop.
local Utils = require("modules/utils")

local Loc = {}

Loc.LANG_PATH = "lang"
Loc.FALLBACK = "en-us"

-- English is held separately from the active language so a partial translation falls
-- back key by key. A translator only has to carry the strings they translated.
local english = {}
local active = {}
local activeCode = Loc.FALLBACK

-- The code last asked for, which is NOT activeCode: asking for a language with no file
-- leaves English active. Comparing a re-check against activeCode would therefore see a
-- difference every time and re-resolve, once per call, forever.
local requestedCode = nil

-- Codes already reported as having no file. A language stays missing for the whole
-- session, so saying so more than once is noise rather than news.
local warnedMissing = {}

-- The game's own language at the last check, which is NOT the language in use: district
-- names come from the game's string tables whatever this mod is pinned to, so the two
-- move independently and each needs its own comparison.
local lastGameCode = nil

-- Every language file found on disk, code -> display name from its own "@name" entry.
-- Built by scanning the directory rather than from a list in this file, so a language
-- nobody here has heard of works the moment its file is dropped in.
local available = {}

--- Read one language file. Returns the decoded table, or nil with a reason.
---@param code string
---@return table|nil strings, string|nil reason
local function ReadLanguageFile(code)
    local path = Loc.LANG_PATH .. "/" .. code .. ".json"
    local file = io.open(path, "r")
    if not file then return nil, "not found" end

    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil, "empty" end

    -- A translation is a file from someone else. Decoding it behind pcall keeps a broken
    -- one to a missing language rather than an error thrown on the render path.
    local ok, decoded = pcall(json.decode, content)
    if not ok or type(decoded) ~= "table" then return nil, "not valid JSON" end

    return decoded, nil
end

--- The language code the game's interface is set to, lowercased, or nil.
--- Read from the game's own setting rather than from Codeware, so this works on an
--- install without it - the same reason weather is the only thing Codeware is asked for.
---@return string|nil code
local function DetectGameLanguage()
    local ok, code = pcall(function()
        local settings = Game.GetSettingsSystem()
        if not settings then return nil end

        local var = settings:GetVar("/language", "OnScreen")
        if not var then return nil end

        -- GetValue returns a CName, and tostring on one of those gives a debug dump
        -- ("tocname{ hash_lo = ... }") rather than the name. The .value field is the
        -- string, with NameToString as the fallback for a build that lacks it.
        local name = var:GetValue()
        if type(name) == "string" then return name end
        if type(name) == "userdata" and name.value then return name.value end
        return NameToString(name)
    end)

    if ok and type(code) == "string" and code ~= "" then
        return string.lower(code)
    end
    return nil
end

--- Scan the lang directory and record every language file present.
local function ScanAvailable()
    available = {}

    local files = dir(Loc.LANG_PATH)
    if not files then return end

    for _, fileInfo in ipairs(files) do
        local code = string.match(fileInfo.name, "^(.+)%.json$")
        if code then
            code = string.lower(code)
            local strings = ReadLanguageFile(code)
            -- "@name" is the language's name written in that language, which is what a
            -- picker has to show: a Russian speaker is looking for Русский, not "Russian".
            available[code] = (strings and strings["@name"]) or code
        end
    end
end

--- Load the strings for a language code, English underneath it.
---@param code string
---@return boolean loaded True when the requested language had a file of its own
local function Activate(code)
    code = string.lower(code or Loc.FALLBACK)

    if code == Loc.FALLBACK then
        active = english
        activeCode = Loc.FALLBACK
        return true
    end

    local strings, reason = ReadLanguageFile(code)
    if not strings then
        if not warnedMissing[code] then
            warnedMissing[code] = true
            Utils.Warn("No " .. code .. " translation (" .. (reason or "unknown") .. "), using English.")
        end
        active = english
        activeCode = Loc.FALLBACK
        return false
    end

    active = strings
    activeCode = code

    local translated = 0
    for _ in pairs(strings) do translated = translated + 1 end
    Utils.Info("Language " .. code .. ": " .. translated .. " of " ..
        Loc.CountKeys(english) .. " strings translated.")
    return true
end

--- Number of entries in a string table.
---@param tbl table
---@return number
function Loc.CountKeys(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

--- Load English, discover the other languages, and pick one.
--- The mod is unusable without English, so a missing en-us.json is an error rather than
--- a fallback to nothing: every label would render as its own key name.
---@param preference string|nil A language code, or "Auto" / nil to follow the game
function Loc.Init(preference)
    local strings, reason = ReadLanguageFile(Loc.FALLBACK)
    if not strings then
        Utils.Error("lang/en-us.json is " .. (reason or "unreadable") ..
            ". Every label will show as its own key name.")
        english = {}
    else
        english = strings
    end

    ScanAvailable()
    Loc.Apply(preference)
end

--- The code that should be loaded: a pinned preference, or the game's own setting.
--- Returns nil before the game is up, when the setting is not readable yet.
---@param preference string|nil
---@return string|nil
local function Resolve(preference)
    if preference and preference ~= "Auto" then
        return string.lower(preference)
    end
    return DetectGameLanguage()
end

--- Switch language. Called at init and again whenever the preference or the game's own
--- language setting may have changed.
---@param preference string|nil A language code, or "Auto" / nil to follow the game
function Loc.Apply(preference)
    local wanted = Resolve(preference)
    requestedCode = wanted

    if not wanted then
        -- The setting is not readable before the game is up. English until it is.
        active = english
        activeCode = Loc.FALLBACK
        return
    end

    Activate(wanted)
end

--- Re-follow the game's language if it has changed since the last check.
--- The player can change language mid-session, and nothing tells a CET mod when they do.
---@param preference string|nil
function Loc.Refresh(preference)
    -- Against what was last ASKED for, not what is loaded. A language with no file leaves
    -- English active, and comparing against that would re-resolve on every single call.
    local wanted = Resolve(preference)
    if wanted and wanted ~= requestedCode then
        Loc.Apply(preference)
    end

    -- District names are the game's own strings, so they follow the GAME's language even
    -- where this mod is pinned to another. A pinned mod would never reach the line above.
    local game = DetectGameLanguage()
    if game and game ~= lastGameCode then
        lastGameCode = game
        Utils.InvalidateDistrictMaps()
    end
end

--- Look up a string.
--- Falls through the active language, then English, then the key itself. The key is
--- returned rather than an empty string because an empty label draws an empty widget,
--- which reads as a layout bug and sends you to the wrong file entirely.
---@param key string
---@param ... any Values for the string's format specifiers
---@return string
function Loc.L(key, ...)
    local text = active[key] or english[key] or key

    if select("#", ...) == 0 then
        return text
    end

    local args = table.pack(...)

    -- "%2$s" means "the second value here", which is how a translation puts the values in
    -- the order its own grammar wants. Lua's string.format has no such thing - it reads
    -- them strictly left to right - so the values are reordered here and the positions are
    -- stripped before it ever sees them.
    if string.find(text, "%%%d+%$") then
        local ordered, count = {}, 0
        local rewritten = string.gsub(text, "%%(%d+)%$", function(position)
            count = count + 1
            ordered[count] = args[tonumber(position)]
            return "%"
        end)
        text, args = rewritten, table.pack(table.unpack(ordered, 1, count))
    end

    -- A translation carrying the wrong specifier - %s where English had %d, or a position
    -- with no value behind it - would otherwise throw once per frame from inside the draw.
    -- It shows unformatted instead.
    local ok, formatted = pcall(string.format, text, table.unpack(args, 1, args.n))
    if ok then return formatted end

    Utils.Warn("Bad format in '" .. key .. "' for language " .. activeCode)
    return text
end

--- The language in use right now.
---@return string code
function Loc.GetLanguage()
    return activeCode
end

--- What the GAME's language setting says, which is not what is in use when the player has
--- pinned one. The picker names both, so it has to be able to tell them apart.
---@return string code
function Loc.GetGameLanguage()
    return DetectGameLanguage() or Loc.FALLBACK
end

--- Every language with a file present, as code -> name written in that language.
---@return table<string, string>
function Loc.GetAvailable()
    return available
end

return Loc
