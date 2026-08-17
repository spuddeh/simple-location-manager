## Implemented
- [x] Save and load V's position in the world with a single keybind.
- [x] Custom location names, descriptions, and auto-tagging.
- [x] Smart organisation: locations grouped by District or Category, or a flat A-Z list.
- [x] Manual coordinates: save or teleport to a shared X/Y/Z (with optional Yaw), with smart paste of CET/AMM/labeled formats.
- [x] Custom categories with unique icons, picked either as the category is typed or from the Category Manager.
- [x] Export a chosen set of locations as one string, picked from a filterable checklist.
- [x] Import/export locations as JSON for sharing, reachable from the Locations tab as well as Settings. An imported location's category is created from its name where the string did not define one.
- [x] Presets system: install location packs with auto-installing categories.
- [x] Preset cleanup: locations left behind by an uninstalled preset are found by comparing what the locations name against the preset files actually present, and removed per preset file. A location the user has edited is kept and re-tagged as their own manual entry unless they ask for it to go too.
- [x] Unused category cleanup: custom categories no location uses are listed and removed per category. Defaults are never listed, and no location is changed - a category comes off the list the user picks from, and a location still naming it re-links if it is added back.
- [x] AMM Support: import Appearance Menu Mod locations.
- [x] Map pins for saved locations, tagged with the mod's own identity so its pin is distinguishable from the player's waypoint or another mod's, removed on replace, on clear and on shutdown, and released from the tracked waypoint slot only while that slot holds this mod's pin.
- [x] Teleport to any saved location directly.
- [x] Time of day and weather stored per location, opt-in, applied by right-clicking a teleport button.
- [x] Custom weather states read from the loaded environment, so weather mods are picked up automatically and a missing state is skipped rather than failing the teleport.
- [x] Footer readout of the live game time and weather state, with a padlock when SLM is holding it (right-click to release) and a warning glyph when another mod has replaced it.
- [x] In-game UI via Cyber Engine Tweaks overlay.
- [x] District names come from the game's own district records, resolved at draw time, so they read in the player's language in all nineteen the game ships and match the world map. A location stores the district's identifier rather than its name, so an export is the same string whatever language wrote it, and a file written before that migrates on load.
- [x] The 23 default categories are interface strings and translate with the rest. A category the player made is their own words and is left alone.
- [x] Translations: interface strings live in `lang/<code>.json` and the language follows the game's own setting unless the player pins one in Settings. The folder is scanned at startup, so a language file added after release needs no change here. A partial translation falls back to English key by key, and a translation carrying a bad format specifier renders unformatted rather than throwing from the draw.
- [x] Console logging at a chosen level (Off, Error, Warn, Info, Debug), covering both the CET console and the mod's own log file. Output the user asked for by pressing a button is never suppressed.
- [x] Optional Window Utils integration: grid snapping, animation and window management when the library is installed.
- [x] Per-save persistence.

## Planned
