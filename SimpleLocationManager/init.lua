-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Entry point for the Simple Location Manager mod.
-- Mod Version: 1.6.0
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

    print(Utils.ConsolePrefix .. " Ready.")
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
