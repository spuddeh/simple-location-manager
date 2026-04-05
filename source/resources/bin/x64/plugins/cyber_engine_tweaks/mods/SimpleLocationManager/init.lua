-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Entry point for the Simple Location Manager mod.
-- Mod Version: 1.4.0
-------------------------------------------------------------------

local Logic = require("modules/logic")
local UI = require("modules/ui")
local Utils = require("modules/utils")
local Impex = require("modules/impex")

-- Register the 'onInit' event to load our data
registerForEvent("onInit", function()
    print(Utils.ConsolePrefix .. " Initializing...")

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

-- Register 'onDraw' event to draw our UI every frame
registerForEvent("onDraw", function()
    UI.Draw()
end)

-- Register Keybind for Quick Save
registerHotkey("SimpleLocationManager_QuickSave", "Quick Save Location", function()
    Logic.QuickSaveLocation()
end)
