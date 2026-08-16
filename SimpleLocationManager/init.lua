-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Entry point for the Simple Location Manager mod.
-- Mod Version: 1.7.0
-------------------------------------------------------------------

local Logic = require("modules/logic")
local UI = require("modules/ui")
local Utils = require("modules/utils")
local Impex = require("modules/impex")
local Env = require("modules/env")

-- Load the saved locations and settings
registerForEvent("onInit", function()
    print(Utils.ConsolePrefix .. " Initializing...")

    -- Codeware is required: weather has no vanilla scripted setter. Everything else
    -- keeps working without it, so this reports rather than stops.
    local codewareVersion = Env.GetCodewareVersion()
    if codewareVersion then
        print(Utils.ConsolePrefix .. " Codeware " .. codewareVersion .. " found.")
    else
        print(Utils.ConsolePrefix ..
            " Codeware not found. Saved weather will be skipped; time of day still applies.")
    end

    -- Initialize Logic (Load Data)
    Logic.Init()

    -- Load Presets (Auto-Import)
    Impex.LoadPresets()

    -- Initialize UI
    UI.Init(Logic)

    -- A mappin id is per-session and does not survive a save/load, so the pin from the
    -- previous session is gone and the stored handle addresses nothing. Dropping it here
    -- stops a stale handle being used against whatever now holds that id.
    Observe("PlayerPuppet", "OnGameAttached", function()
        Logic.InvalidateMappin()
    end)

    print(Utils.ConsolePrefix .. " Ready.")
end)

-- A map pin outlives this mod's Lua state. Reloading CET rebuilds the state with no handle
-- to the pin, while the engine keeps it registered for the rest of the session - and
-- UnregisterMappin is the only way to remove one, so a pin with no handle cannot be removed
-- by anything at all. Clearing on shutdown is what stops that.
registerForEvent("onShutdown", function()
    Logic.ClearMappin()
end)

-- Register 'onOverlayOpen'
registerForEvent("onOverlayOpen", function()
    UI.OnOverlayOpen()
end)

-- Register 'onOverlayClose'
registerForEvent("onOverlayClose", function()
    UI.OnOverlayClose()
end)

-- onDraw is on the render path, so it runs whether or not the CET overlay is open.
-- That is why the weather hold ticks here and not from onUpdate, which stops while the
-- overlay is up - which is exactly when a teleport happens.
registerForEvent("onDraw", function()
    Logic.Tick()
    UI.Draw()
end)

-- Register Keybind for Quick Save
registerHotkey("SimpleLocationManager_QuickSave", "Quick Save Location", function()
    Logic.QuickSaveLocation()
end)
