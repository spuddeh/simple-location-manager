# Simple Location Manager - Changelog

Notable changes to Simple Location Manager. Versioning is semantic (MAJOR.MINOR.PATCH). Preset companion files carry their own suffixed tags and track their history independently.

## v1.6.0

- Feature: Time & Weather - a location can store a time of day and a weather state. Opt-in per location via a "Save time and weather" section in the Edit modal, with a "Use current" button. Applied by **right-clicking** the teleport button; left click teleports without touching either. The gesture is the control, so there is no on/off setting - only a weather transition slider in Settings.
- Feature: Time is optional, matching weather. A checkbox beside the time sliders turns the time half off, so a location can carry a weather with no time of day - the counterpart of the weather picker's "Leave as is". `BuildEnvFromBuffers` returns nil when both halves are off rather than an empty `env`, which would have shown a padlock row that does nothing.
- Feature: Weather override detection and one re-apply - `Logic.VerifyWeatherHeld` re-reads the state 2s later via `Cron.After`. **Two different things take the weather away and one retry separates them:** a teleport that reloads the world resets the state *after* `SetWeather` has run, which is a race that re-applying wins; a weather mod holding its own locked state re-forces on every change, so re-applying loses again and the warning fires. Capped at two attempts - a third would be the start of a fight with a per-frame re-forcer. The lock lives in the other mod's Lua state, not the engine, so reporting is all that is possible - Weather Switcher's `init.lua` has no `return`, so `GetMod("WeatherSwitcher")` is nil and there is no API to clear it.
- Feature: Footer readout - live game time and current weather state, centred in the footer, with a padlock glyph when SLM is holding the state (`Lock`) or has been overridden (`LockAlert`). Right-click it to hand the weather back. Amber while held, red once something else has replaced it. **The engine's weather-cycle flag is a raw memory offset (`OffsetPtr<0x8C, bool>`) that Codeware writes and exposes no getter for, and it is not in RTTI**, so the readout reports only what SLM itself did - no padlock means SLM is not holding it, not that the cycle is running, and the tooltip says so.
- Fix: The footer readout is sampled in `UI.Draw`, not on a `Cron.Every`. **`onUpdate` does not tick while the CET overlay is open**, so the timer only fired once the overlay closed and the readout sat frozen at whatever it was on open. The same applies to `VerifyWeatherHeld`, which lands after the overlay closes by design - the footer is what covers the overlay-open case.
- New: `modules/Cron.lua` - psiberx's timer, copied from `_source/cp2077-cet-kit/`, ticked from a new `onUpdate` in `init.lua`. No game logic in the handler; the timers hold it.
- Feature: Custom weather states - the weather picker is built from `GetWeatherSystem():GetEnvironmentDefinition().weatherStates`, so states added by a weather mod (Nova City 2 and the like) appear without SLM carrying a list. A saved state the current game does not have is detected and skipped, leaving the time and the teleport intact; the id is kept so it works again if the mod returns. `Env.SetWeather` returning false is a second guard on the same case.
- Feature: Restore natural weather - forcing a state stops the game's weather cycle, so Settings carries a button calling `ResetWeather` to hand it back.
- Note: The weather transition is real (Codeware's raw `SetWeatherByName` takes `float aBlendTime` as its fourth argument) but **a teleport that reloads the world arrives at full strength regardless**. The blend is only visible over a short hop. The Settings caption says so rather than leaving it looking broken.
- Feature: Window Utils support - `wu` resolves to `GetMod("WindowUtils") or ImGui`, so the library is optional. When present the main window gains grid snapping, animation and an entry in the Window Utils manager; `SetConstraints` replaces `SetNextWindowSizeConstraints` because it grid-aligns the bounds.
- New: `modules/env.lua` - time and weather reads, writes, state discovery and the pretty-label mapping. Weather calls route through Codeware's `WeatherSystem` additions and are all behind an availability check.
- Format: The V2 export gains two optional keys, `t` (time array) and `w` (weather id). Absent on a location with no snapshot, so existing strings and presets are unaffected and the version was not bumped.
- Note: `UI.Draw` names both of `ImGui.Begin`'s returns. CET's binding is `std::make_tuple(open, open && shouldDraw)` - the close button FIRST, visibility second - and Window Utils' `modules/begin.lua` names them the other way round. Content is now skipped while the window is collapsed rather than submitted and clipped.
- Fix: `ui.lua` assigned `updateConfirmId`, `forceExpand` and `forceCollapse` without `local`, leaking three globals into the CET Lua state every installed mod shares.
- Fix: `Logic.UpdateLocationPosition` assigned `loc.rot` twice; `GetPlayerState` returns four fields and all four were already assigned, so nothing was missing.
- Fix: The AMM bulk-import duplicate branch claimed in a comment to tag the existing location with conflict info and never did, leaving `checkDist` and `pos1` computed and discarded. Skip-and-log remains the behaviour - an AMM file carries no ID to link the two records by - and `Impex.IsExactDuplicate` now returns the matched location so both import paths name it in the report.
- Fix: A custom category was written into an export string once per location using it, not once. `GetUsedCustomCategories` declared a `used` dedup table, tested it, and never wrote to it, so the guard could not fire. Found in a three-location export that carried the same category three times.
- Refactor: `Logic.MarkPresetEdited` extracted from two inline copies of the user-edit protection check, now used by three callers.
- Cleanup: removed an empty `package.categories` if-block in `impex.lua`, an unused `remaining` local in the description character counter, and the write-only `shouldOpenDuplicateModal` flag that duplicated `showDuplicateModal`.

## v1.5.0

- Feature: Manual Coordinates - a new button (next to "Add current location") opens a modal to save or teleport to a shared X/Y/Z (with optional Yaw) without typing a CET console command first. Choose Save, Save & Teleport, or Teleport.
- Feature: SmartPaste™ - the Manual Coordinates modal parses labeled strings (x= y= z= yaw=, including quoted JSON keys), full CET `Vector4.new(...)` / `EulerAngles.new(...)` teleport commands, and plain ordered number lists. The paste box drives the fields and has a clear button. Always double-check the auto-filled values before saving or teleporting.
- Feature: A-Z View - a third "A-Z" sort mode that lists every location in one flat alphabetical list, with no district or category grouping. The Expand/Collapse All buttons are disabled in this view.
- Fix: Renamed the modal window prefix from "[SLM]" to "SLM - " to avoid a window-title conflict with other CET mods caused by the "]" character.

## v1.4.0

- QOL: Group State Persistence - manually expanded/collapsed groups now keep their state across searches. Groups auto-expand when search results appear in them, then return to their previous state when search is cleared.
- QOL: Dump Coordinates Auto-Copy - the Dump Coordinates button now copies to the clipboard automatically.
- QOL: Dump District Info Preview - district info displays as a live preview in the Debugging panel (light blue text).
- QOL: Middle-Click Copy on Previews - both the coordinate and district info previews can be middle-clicked to copy to the clipboard, with a tooltip hint.

## v1.3.1

- Fix: Resolved an issue where Preset Updates failed due to incorrect duplicate detection.
- Fix: Self-Healing IDs - preset updates now automatically repair broken ID links caused by re-exports or fresh installs.
- Feature: User Edit Protection - manual edits to Preset locations now prevent future preset updates from overwriting your changes.
- Feature: Smart Conflict Resolution - "Conflict" skips now respect Manual Input locations, preventing accidental overwrites by the Self-Healing logic.

## v1.3.0

- QOL: Export Filtered - a copy button next to the search bar exports only the locations matching your current search.
- QOL: Improved Footer - now displays filtered counts when searching (e.g. "Locations: 5 / 20").
- QOL: Better Descriptions - increased input height to 3.5 lines and the character limit to 500, with a character counter.
- Fix: Clicking the New Location button no longer auto-saves. Locations are created only when you explicitly click "Save".
- Fix: Resolved layout glitches in the "Duplicate Warning" and "Edit Location" modals.
- Fix: Fixed the search bar width that prevented the export button from appearing.

## v1.2.1

- Fix: Fixed missing IDs in V2 Export strings (critical for Preset updates).

## v1.2.0

- Feature: Export Compression (V2) - export strings are now roughly 70-75% smaller. Old SLM strings still import without issue.
- Feature: Added the "Hidden Gem" category.

## v1.1.0

- Feature: Categories - locations can be assigned a Category (icon + name) for better organisation.
- Feature: Custom Category Portability - exports and imports automatically include custom category definitions.
- Feature: AMM Support - full support for importing Appearance Menu Mod locations (Bulk Import and String Import).
- Feature: Preset Support (for authors) - distribute full location packs with custom categories/icons that auto-install for players.
- Feature: Category Manager - create, edit, and delete custom categories, with a deletion safety modal.
- Feature: Lazy Mode - the Lazy Mode (teleport buttons) setting is now persistent and saves to your config.
- UI: Category View - a dedicated filtering tab to view locations by Category.
- UI: Readability - consistent icon use and UI colour improvements.
- UI: Sorting - the Locations list is sorted alphabetically.
- UI: Modals - standardised all modal styling and behaviour.

## v1.0.0

- Core: First public release of Simple Location Manager.
- Save, edit, and delete locations; automatic District and Sub-District detection.
- Favorites system, grouping, and search.
- Map pin integration and Import/Export (Base64).
- Customizable settings (duplicate distance, UI density, teleport).

## Preset companion files

- v1.0.0apartments - Initial upload of the Vanilla/DLC apartments preset.
- v1.0.0kp - Initial upload of the Konpeki Plaza SLM preset.
- v1.0.0joker - Initial upload of the Balatro / Jim B Joker SLM preset.

## Pre-release betas

- v0.9.5 - Import/Export module with Base64 support; Default Group State setting; footer with location count and version; icon buttons; crash fix in `GetLocation`.
- v0.9.0 - Duplicate Location warning (distance check); dynamic settings defaults; removed legacy `debugMode`; Show Coordinates / Show District toggles; timestamp auto-naming.
- v0.8.0 - Initial Smart Grouping (District -> Sub-District); Favorites; search filtering; confirmation modals for Delete/Reset.
