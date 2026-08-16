# Simple Location Manager - Changelog

Notable changes to Simple Location Manager. Versioning is semantic (MAJOR.MINOR.PATCH). Preset companion files carry their own suffixed tags and track their history independently.

## v1.7.0

- Feature: An import button on the Locations tab, beside Add and Manual Coordinates. It sets the same `showImportRed` flag the Settings button sets, and the modal is drawn from the root draw, so no second modal exists.
- Feature: A category typed into the Edit Location or Manual Coordinates box carries an icon of the user's choosing. The glyph beside the box becomes a button when the typed name matches no existing category, and opens `IconPicker` inline; an existing category keeps its glyph as text, because its icon belongs to the Category Manager. `DEFAULT_NEW_CATEGORY_ICON` replaces the `"Star"` that was passed at both `Logic.AddCategory` call sites.
- Fix: An imported location naming a category the package never defined left that category pointing at nothing - the name sat on the location while the Custom Categories list stayed empty. `Impex.SweepCategoryNames` collects the names off the locations and passes them to `Logic.MergeCustomCategories`, which already skips anything that exists as a default or a custom. It runs **after** the package's own definitions are merged, so a category that arrived with a real icon keeps it and only the undefined ones fall back to `IMPORTED_CATEGORY_ICON`. A category name that survived expansion as a number is not a name and is not swept.
- Fix: `Impex.LoadPresets` needed the sweep separately. It carries its own import loop - ID match, position conflict, self-healing resync - and never calls `ProcessImportDataArray`, so fixing only the string path would have left every preset untouched.
- Note: The export side needed no change. `GetUsedCustomCategories` has emitted definitions since 1.1.0, but it reads `Logic.settings.customCategories`, so a category that was never created there was dropped on every re-export. Creating it on import is what closes the round trip.
- Fix: The Manual Coordinates modal clipped its Cancel button. Four action buttons share one row inside a window pinned to 420 px with `NoResize`, so a row wider than that lost the last one with no way for the user to widen the window. The width is now measured from the button labels, and `MANUAL_ACTION_LABELS` is read by both the measurement and the buttons so the two cannot drift apart.
- Note: The same modal re-applies its auto-fit height every frame (`ImGuiCond.Always`, height 0) rather than once on appear, so it grows when the icon picker opens inside it. The pinned width is unaffected.
- Fix: A map pin outlived the mod's Lua state. Reloading CET rebuilt that state with no handle to the pin while the engine kept it registered, and `UnregisterMappin` takes an id and is the only removal call `MappinSystem` has - so a pin whose handle was lost could not be removed by anything for the rest of the session. `onShutdown` now clears it.
- Fix: A mappin id is per-session and does not survive a save/load, so the handle held across a load addressed nothing. `Logic.InvalidateMappin`, on an `Observe` of `PlayerPuppet.OnGameAttached`, drops it. Nothing is unregistered there, because by then the id could belong to a pin this mod does not own.
- Feature: Clearing a map pin releases the tracked waypoint slot, so the waypoint the player had before the pin resumes routing. Measured twice: the displaced waypoint stays registered and untracked while the pin holds the slot, and returns to `tracked=TRUE` the moment the pin is cleared, with no map cycle in between. **The untrack is guarded and has to be.** `UntrackMappin` takes no argument and clears whatever is in the slot, so it runs only while `GetManuallyTrackedMappinID` reports the slot holds this mod's pin - unguarded, the same call would take the player's own waypoint. No released version untracked at all: `ClearMappin` only ever unregistered, which left the slot pointing at a destroyed mappin.
- Feature: Every registered pin carries `debugCaption = "SLM|<name>"`. `IMappin.GetDisplayName()` reads it back, and it is the only identity channel a mappin has - without it this mod cannot tell its own pin from the player's or another mod's. The assignment is wrapped in `pcall` so a binding rejection cannot take the registration down with it.
- Feature: Setting a pin over an existing tracked waypoint says so. `CustomPositionVariant` means "this is the player's waypoint", so the game moves the tracked slot to the newest routable pin and the player's own route silently stops. Setting a pin is a deliberate action, so the slot is taken rather than refused - the notification is what removes the "silently".
- Note: `GetManuallyTrackedMappinID` and `UntrackMappin` are absent from `cet-lua-lib`'s stubs, which are pinned to CET v1.27.1, and the IDE marks them undefined. Both are callable. A `NewMappinID` is bound to a local before `.value` is read, because reading one inline off the call returns a heap pointer rather than the id.
- Feature: Export Selected - a modal listing every location with a checkbox, its own filter, and Select shown / Deselect shown / Clear all. `Impex.ExportList` already took an arbitrary list, so the modal is the whole of it. The count and the export are built from `Logic.locations` rather than from the filtered view, so narrowing the filter cannot silently shrink a selection. The bulk buttons deliberately act on what the filter is showing, which is what makes the filter useful for picking a set.
- Note: `SortLocationByName` moves above the export helpers. It is a file-local, and a file-local referenced before its definition is `nil` at call time rather than a load error.
- Feature: Log levels, with a `Console Logging` setting - Off, Error, Warn, Info, Debug - defaulting to `Warn`, which leaves a normal load silent. `Utils` gains `Error`, `Warn`, `Info` and `Debug`; all 35 bare `print` calls route through them, and both destinations follow the level, since `print` reaches the CET console and its log while `spdlog` reaches the mod's own log. The level is pushed into `Utils` from `Logic.Init` and from the setting rather than read back, because `logic` requires `utils` and the reverse would be a cycle. An unrecognised level name falls back to the default instead of silencing the mod.
- Feature: `Utils.Print` for output the user asked for by pressing a button - the coordinate dump, the district dump, the export confirmation. It is never gated: a dump that prints nothing reads as a broken button rather than a quiet one.
- Note: What moved where. The per-location import lines are `Debug` - `Synced Preset Location`, `Imported Location`, `[OK] Imported`, `[SKIP] Duplicate Position` - and they were the noise, one line per location on every load, 24 of them for the bundled presets alone. `Teleported to`, `Mappin set`, `Mappin cleared` and `Scanning presets` join them. Summaries stay at `Info`. A failed save is `Error`; a missing Codeware, an absent weather state, a malformed import entry and a weather hold given up are `Warn`.
- Fix: A group could come back collapsed after a location was deleted from it, with the default group state set to Collapsed. `groupOpenState` is now authoritative: `ApplyGroupOpenState` asserts every header's state with `SetNextItemOpen` on every frame, and `RecordGroupOpenState` writes the returned value back so a click by the user still lands. The five-branch chain that was duplicated across the four group kinds collapses into those two calls, and `groupPresentThisFrame`, `groupPresentLastFrame` and `lastSearchQuery` go with it - a group re-appearing and a search being cleared are both covered by asserting the remembered state unconditionally, and a searching frame is still not recorded. `headerFlags` goes too: `SetNextItemOpen` overrides `DefaultOpen`, so the default now lives in one branch of `ApplyGroupOpenState` rather than in four flag calculations.
- Note: **The cause of that collapse is not known.** Measured, over five captures: no `SetNextItemOpen` call fired on any collapse frame, the mouse was ~700 px away with no hover, no press and no release, there was no Lua error, and only the one group that was open ever flipped while a group drawn later stayed open - which rules out an ID-stack shift. Delete speed is not the trigger; the run that reproduced was slower than the run that did not. ImGui's stored state for a single header was being reset by something outside this mod's reach. Owning the state removes the mod's dependence on that storage, so the fault cannot reach the user, but it does not explain it.
- Note: `MapWaypointBugFixes` is a requirement. It hides the HUD and minimap marker stranded when a variant-21 pin stops being the tracked waypoint, so no phantom-cleanup code is carried here. Unregistering and untracking stay this mod's job: that mod hides strays, it does not unregister them.

## v1.6.0

- Feature: Time & Weather - a location can store a time of day and a weather state. Opt-in per location via a "Save time and weather" section in the Edit modal, with a "Use current" button. Applied by **right-clicking** the teleport button; left click teleports without touching either. The gesture is the control, so there is no on/off setting - only a weather transition slider in Settings.
- Feature: Time is optional, matching weather. A checkbox beside the time sliders turns the time half off, so a location can carry a weather with no time of day - the counterpart of the weather picker's "Leave as is". `BuildEnvFromBuffers` returns nil when both halves are off rather than an empty `env`, which would have shown a padlock row that does nothing.
- Feature: The weather hold is a hold. `Logic.Tick`, called every rendered frame from `onDraw`, puts the forced state back whenever the game moves off it - a teleport alone is enough to knock it to another state, so a single `SetWeather` was never the hold the footer padlock claims. Corrections are consecutive and the count resets the moment the state holds, so only something re-forcing every frame exhausts it; at that point the hold is released rather than thrashing the sky between two mods. **`onDraw` is on the render path (`D3D12::PrepareUpdate`) and runs whether or not the overlay is open, which `onUpdate` does not** - and the overlay being open is exactly when a teleport happens.
- Feature: Footer readout - live game time and current weather state, centred in the footer, with a padlock glyph when SLM is holding the state (`Lock`) or has been overridden (`LockAlert`). Right-click it to unlock the weather cycle. Amber while held, red once something else has replaced it. **The engine's weather-cycle flag is a raw memory offset (`OffsetPtr<0x8C, bool>`) that Codeware writes and exposes no getter for, and it is not in RTTI**, so the readout reports only what SLM itself did - no padlock means SLM is not holding it, not that the cycle is running, and the tooltip says so.
- Fix: The footer readout is sampled in `UI.Draw`, not on a `Cron.Every`. **`onUpdate` does not tick while the CET overlay is open**, so the timer only fired once the overlay closed and the readout sat frozen at whatever it was on open. The same applies to `VerifyWeatherHeld`, which lands after the overlay closes by design - the footer is what covers the overlay-open case.
- Feature: Custom weather states - the weather picker is built from `GetWeatherSystem():GetEnvironmentDefinition().weatherStates`, so states added by a weather mod (Nova City 2 and the like) appear without SLM carrying a list. A saved state the current game does not have is detected and skipped, leaving the time and the teleport intact; the id is kept so it works again if the mod returns. `Env.SetWeather` returning false is a second guard on the same case.
- Feature: A left-click teleport releases a held weather too. Left click is a request for this mod to stay out of the time and the weather, so leaving an earlier hold in place carried one location's sky to every location reached without asking for it. Right click is now the only gesture that sets anything, and the only one that leaves a hold behind.
- Feature: A teleport that does not name a usable weather releases the hold, unlocking the weather cycle so the game is free to move the weather again. `Logic.ReleaseWeatherHold` only releases a hold this mod owns - another mod's forced weather is not this mod's to undo - and it is called for all three cases: no `env` at all, no weather on the `env`, and a weather that is not installed.
- Note: **The three cases do not look the same to the player, and that is deliberate.** With no time or weather saved, only the lock goes and the weather playing at the time carries on. With a saved weather that is not installed, the time applies and the sky is set to sunny - a location that named a weather lands in a defined one, rather than in whatever happened to be overhead.
- Fix: The footer no longer flashes red while a correction is in flight. "Overridden" is now `Env.MarkHoldLost`, set only where the hold is given up, rather than "the state differs this instant" - which was true for the few frames between drift and correction. `WEATHER_CHECK_FRAMES` also drops from 60 to 10, so the sky itself barely moves.
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
