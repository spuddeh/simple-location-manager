# Simple Location Manager — Nexus Changelogs

### [Unreleased - v1.7.0]
- New: Translations. The mod follows your game's language, or one you pick in Settings. Anything not yet translated shows in English. Adding a language takes a single file in the mod's lang folder - see the Translating article.
- New: District names come from the game, so they appear in your own language and match the world map, in every language the game ships. Nothing needs translating for this - the names are the game's own.
- New: The categories the mod comes with are translated too. Categories you made yourself stay as you named them.
- New: Remove Preset Locations, in Settings. Uninstall a preset and its locations stay behind; this lists the presets whose file is gone and clears them out, one preset at a time. Tick a preset on the left and the right side names every location it would remove, so nothing goes without you seeing it first. A location you had edited yourself is listed separately and kept, becoming your own, unless you tick the box to delete those too.
- New: Remove unused, in the Category Manager. Lists the custom categories no location uses and clears the ones you tick. Default categories are never listed, and no location changes - the category just comes off the list you pick from. Handy right after clearing out a preset, since a preset brings its own categories with it.
- New: Export Selected gains a **Preset** dropdown. Pick a preset file and every location it brought in is ticked, ready to re-export as an update. Locations you have changed since installing it are included and counted for you, because the export replaces the preset file whole - anything left out would be dropped from it.
- New: Picking a category and naming a new one are two separate controls now, in both the Edit and Manual Coordinates windows. Pick from the dropdown, or type in the box below it to create one - typing greys the dropdown out, so which of the two you are about to save is always on screen.
- Removed: Lazy Mode. The teleport button is now on every location without turning anything on first. The Safety Protocol notice is still in Settings.
- Fix: Playing in a language other than English wrote that language's district names into your saved locations and into every export string. An export was then far longer than it needed to be, and a preset written in English showed up as a second group beside your own locations for the same district. Your existing locations are updated the first time you load this version.
- Fix: A category whose name differed from one you already had only by capitals - "bar" where you have "Bar" - could be created as a second category, and deleting either one then removed both. Typing a name that already exists now uses the category you have, and says which.
- Note: Cyrillic, Polish, Czech, Turkish, Chinese, Japanese and Korean need CET's own font language setting changed, in its config.json. CET draws this window and loads one alphabet at a time, which is not something a mod can set.
- Minor code improvements

### 1.6.0
- New: Time & Weather - a location can remember a time of day and a weather state. Turn it on per location in the Edit window; "Use current" copies what the game is doing now. The two are separately optional, so a location can set one and leave the other alone.
- New: Right-click a teleport button to teleport and apply that location's saved time and weather. Left-click teleports as always, and releases any weather SLM was holding.
- New: Custom weather states are supported - anything a weather mod adds appears in the picker. Remove that mod later and the location still works: the time applies, the sky is set to sunny, and your saved weather comes back if you reinstall.
- New: Teleporting to a location with no time or weather saved unlocks the weather cycle, if SLM had locked it. Whatever weather is playing carries on.
- New: If another weather mod is holding its own weather state, SLM stops competing and tells you - clear that mod's lock first.
- New: The footer shows the current game time and weather state. A padlock appears while SLM is holding the weather - right-click it to unlock the weather cycle. Amber while held, red once something else has replaced it.
- New: Settings gains a "Restore natural weather" button, which unlocks the cycle, and a slider for how long a weather change takes.
- New: Export Selected - a button in Settings opens a tick-box list of every location. Pick any set, filter to narrow it down, and copy one export string for the lot. Paste it into a .txt to share as a preset.
- New: A "Console Logging" setting. SLM wrote a console line per location loaded - dozens on every load with presets installed. It is now quiet by default and reports only problems. Info shows what it is doing, Debug restores every line. Dumps and export confirmations always print.
- New: An import button on the Locations tab, so importing no longer means a trip to Settings.
- New: Pick an icon for a category as you create it - type a new name in the Edit or Manual Coordinates window and click the symbol beside the box. Existing categories keep the icon set in the Category Manager.
- New: Setting a map pin over a waypoint you already had now tells you it replaced it, and clearing the pin hands the route back to that waypoint.
- New: Map Waypoint Bug Fixes is now required. It clears the HUD and minimap marker a map pin leaves behind when replaced or cleared.
- New: Codeware is now required. It is what makes setting the weather possible.
- New: Optional Window Utils support. With it installed the SLM window snaps to that mod's grid, animates as it opens and closes, and can be arranged alongside your other mod windows.
- Fix: Importing locations that use a category you do not have now creates it. The name reached the locations but never your Custom Categories list, and was lost again on re-export.
- Fix: Exporting several locations sharing a custom category repeated that category once per location in the string.
- Fix: Deleting a location could collapse its group when the default group state is Collapsed. Groups now stay as you left them.
- Fix: Reloading CET left a map pin behind that nothing could remove for the rest of the session.
- Fix: The Cancel button was cut off the edge of the Manual Coordinates window.
- Minor code improvements

### 1.5.0
- Feature: Manual Coordinates - a new button next to "Add current location" lets you save or teleport to a shared X/Y/Z (with optional Yaw) without typing a CET console command. Choose Save, Save & Teleport, or Teleport.
- Feature: SmartPaste™ - the Manual Coordinates box understands labeled values (x= y= z= yaw=, including AMM JSON), full CET Vector4.new(...) / EulerAngles.new(...) teleport commands, and plain "x, y, z" number lists. It drives the fields and has a clear button. Always double-check the auto-filled values before saving or teleporting.
- Feature: A-Z View - a third sort mode that lists every location in one flat alphabetical list, with no district or category grouping.
- Fix: Renamed the mod's window titles from "[SLM]" to "SLM - " to prevent a conflict with other CET mods.

### 1.4.0
- QOL: Group State Persistence - Manually expanded/collapsed groups now maintain their state across searches. Groups auto-expand when search results appear in them, and return to their previous state when search is cleared.
- QOL: Dump Coordinates Auto-Copy - The Dump Coordinates button in the settings tab now automatically copies to clipboard for easy pasting.
- QOL: Dump District Info Preview - District info now displays as a live preview in the Debugging panel (light blue text).
- QOL: Middle-Click Copy on Previews - Both coordinate and district info previews can be middle-clicked to copy to clipboard with a tooltip hint.

### 1.0.0joker
- Initial upload of the Balatro / Jim B Joker SLM preset

### 1.0.0kp
- Initial upload of the Konpeki Plaza SLM preset

### 1.0.0apartments
- Initial upload of the Vanilla/DLC apartments preset

### 1.3.1
- Bug Fix: Resolved issue where Preset Updates were failing due to incorrect duplicate detection.
- Bug Fix: Self-Healing IDs - Preset updates now automatically repair broken ID links caused by re-exports or fresh installs.
- Feature: User Edit Protection - Manual edits to Preset locations now prevent future preset updates from overwriting your changes.
- Feature: Smart Conflict Resolution - "Conflict" skips now respect Manual Input locations, preventing accidental overwrites by the Self-Healing logic.

### 1.3.0
- QOL: Export Filtered - Added a copy button next to the search bar to export only the locations matching your current search.
- QOL: Improved Footer - Now displays filtered counts when searching (e.g., "Locations: 5 / 20").
- QOL: Better Descriptions - Increased input height to 3.5 lines and character limit to 500. Added a character counter.
- Bug Fix: Clicking the New Location button no longer auto-saves. Locations are created only when you explicitly click "Save". Should reduce any accidental location creations.
- Bug Fix: Resolved layout glitches in "Duplicate Warning" and "Edit Location" modals.

### 1.2.1
- Added "V2" Export Compression (70% smaller strings). Old SLM strings will still import without issue.

### 1.1.0
- Feature: Categories - Locations can now be assigned a Category (Icon + Name) for better organisation
- Feature: Custom Category Portability - Exports and Imports now automatically include custom category definitions
- Feature: AMM Support - Full support for importing Appearance Menu Mod locations (Bulk Import & String Import)
- Feature: Preset Support (For Authors) - Distribute full location packs with custom categories/icons that auto-install for players
- Feature: Category Manager - Create, Edit, and Delete custom categories
- Feature: Lazy Mode - The "enable Lazy Mode" (Teleport Buttons) setting is now persistent and saves to your config
- UI Improvement: Category View - Added dedicated filtering tab to view locations by Category
- UI Improvement: Readability - Ensured consistent icon use and added UI colour improvements
- UI Improvement: Sorting - The Locations list is now sorted alphabetically
- UI Improvement: Modals - Standardised all modal window styling and behaviour
- UI Improvement: Polish - Various other fixes and tweaks to the UI
- UI Improvement: Lazy Mode - "Toned down" the Lazy Mode teleport warning.

### 1.0.0
- Initial Upload

---
## Notes

**`slm-v1.6.0-internal` is a rollback marker, not a release.** It sits at `6f5fb67` and was tagged
so the 1.6.0 work could be returned to if what followed went wrong. Nothing was uploaded under it,
and the public history runs 1.5.0 to 1.6.0 with no gap.

So 1.6.0 ships as one release and one section. An earlier draft split the same work across 1.6.0 and
1.7.0 and had both going up together, which cost several corrections on its own: entries written for
a reader who had supposedly seen 1.6.0 already, when nobody had.

**Both blocks below are generated. Do not hand-edit them.** Run
`python scripts/build-nexus-blocks.py` after any change to an entry above.

---
## Release body

Paste this whole block into the GitHub Release body. Everything above the marker becomes the Nexus **file description**; everything below is appended to the page **changelog**, which splits on newlines - so the lines stay unwrapped and carry no `- ` prefix.

```
Adds translations and a cleanup for locations left behind by an uninstalled preset. Lazy Mode is gone - teleport is always available. Requires Codeware and Map Waypoint Bug Fixes; Window Utils is optional.
<!-- nexus-description-end -->
New: Translations. The mod follows your game's language, or one you pick in Settings. Anything not yet translated shows in English. Adding a language takes a single file in the mod's lang folder - see the Translating article.
New: District names come from the game, so they appear in your own language and match the world map, in every language the game ships. Nothing needs translating for this - the names are the game's own.
New: The categories the mod comes with are translated too. Categories you made yourself stay as you named them.
New: Remove Preset Locations, in Settings. Uninstall a preset and its locations stay behind; this lists the presets whose file is gone and clears them out, one preset at a time. Tick a preset on the left and the right side names every location it would remove, so nothing goes without you seeing it first. A location you had edited yourself is listed separately and kept, becoming your own, unless you tick the box to delete those too.
New: Remove unused, in the Category Manager. Lists the custom categories no location uses and clears the ones you tick. Default categories are never listed, and no location changes - the category just comes off the list you pick from. Handy right after clearing out a preset, since a preset brings its own categories with it.
New: Export Selected gains a **Preset** dropdown. Pick a preset file and every location it brought in is ticked, ready to re-export as an update. Locations you have changed since installing it are included and counted for you, because the export replaces the preset file whole - anything left out would be dropped from it.
New: Picking a category and naming a new one are two separate controls now, in both the Edit and Manual Coordinates windows. Pick from the dropdown, or type in the box below it to create one - typing greys the dropdown out, so which of the two you are about to save is always on screen.
Removed: Lazy Mode. The teleport button is now on every location without turning anything on first. The Safety Protocol notice is still in Settings.
Fix: Playing in a language other than English wrote that language's district names into your saved locations and into every export string. An export was then far longer than it needed to be, and a preset written in English showed up as a second group beside your own locations for the same district. Your existing locations are updated the first time you load this version.
Fix: A category whose name differed from one you already had only by capitals - "bar" where you have "Bar" - could be created as a second category, and deleting either one then removed both. Typing a name that already exists now uses the category you have, and says which.
Note: Cyrillic, Polish, Czech, Turkish, Chinese, Japanese and Korean need CET's own font language setting changed, in its config.json. CET draws this window and loads one alphabet at a time, which is not something a mod can set.
Minor code improvements
```

---
## Stickied Comment BBCode

The history no longer fits one Nexus comment (5000 char limit), so it is 3 posts. Post the last one first and work back, so the newest sits at the top of the thread.

### Comment 1 - current

```
[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]

[b][size=3]Version 1.7.0[/size][/b]
[list][*]New: Translations. The mod follows your game's language, or one you pick in Settings. Anything not yet translated shows in English. Adding a language takes a single file in the mod's lang folder - see the Translating article.
[*]New: District names come from the game, so they appear in your own language and match the world map, in every language the game ships. Nothing needs translating for this - the names are the game's own.
[*]New: The categories the mod comes with are translated too. Categories you made yourself stay as you named them.
[*]New: Remove Preset Locations, in Settings. Uninstall a preset and its locations stay behind; this lists the presets whose file is gone and clears them out, one preset at a time. Tick a preset on the left and the right side names every location it would remove, so nothing goes without you seeing it first. A location you had edited yourself is listed separately and kept, becoming your own, unless you tick the box to delete those too.
[*]New: Remove unused, in the Category Manager. Lists the custom categories no location uses and clears the ones you tick. Default categories are never listed, and no location changes - the category just comes off the list you pick from. Handy right after clearing out a preset, since a preset brings its own categories with it.
[*]New: Export Selected gains a **Preset** dropdown. Pick a preset file and every location it brought in is ticked, ready to re-export as an update. Locations you have changed since installing it are included and counted for you, because the export replaces the preset file whole - anything left out would be dropped from it.
[*]New: Picking a category and naming a new one are two separate controls now, in both the Edit and Manual Coordinates windows. Pick from the dropdown, or type in the box below it to create one - typing greys the dropdown out, so which of the two you are about to save is always on screen.
[*]Removed: Lazy Mode. The teleport button is now on every location without turning anything on first. The Safety Protocol notice is still in Settings.
[*]Fix: Playing in a language other than English wrote that language's district names into your saved locations and into every export string. An export was then far longer than it needed to be, and a preset written in English showed up as a second group beside your own locations for the same district. Your existing locations are updated the first time you load this version.
[*]Fix: A category whose name differed from one you already had only by capitals - "bar" where you have "Bar" - could be created as a second category, and deleting either one then removed both. Typing a name that already exists now uses the category you have, and says which.
[*]Note: Cyrillic, Polish, Czech, Turkish, Chinese, Japanese and Korean need CET's own font language setting changed, in its config.json. CET draws this window and loads one alphabet at a time, which is not something a mod can set.
[*]Minor code improvements
[/list]
```

> Character count: 3105 / 5000

### Comment 2 - older versions

```
[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]

[i](Continued - older versions)[/i]

[b][size=3]Version 1.6.0[/size][/b]
[spoiler][list][*]New: Time & Weather - a location can remember a time of day and a weather state. Turn it on per location in the Edit window; "Use current" copies what the game is doing now. The two are separately optional, so a location can set one and leave the other alone.
[*]New: Right-click a teleport button to teleport and apply that location's saved time and weather. Left-click teleports as always, and releases any weather SLM was holding.
[*]New: Custom weather states are supported - anything a weather mod adds appears in the picker. Remove that mod later and the location still works: the time applies, the sky is set to sunny, and your saved weather comes back if you reinstall.
[*]New: Teleporting to a location with no time or weather saved unlocks the weather cycle, if SLM had locked it. Whatever weather is playing carries on.
[*]New: If another weather mod is holding its own weather state, SLM stops competing and tells you - clear that mod's lock first.
[*]New: The footer shows the current game time and weather state. A padlock appears while SLM is holding the weather - right-click it to unlock the weather cycle. Amber while held, red once something else has replaced it.
[*]New: Settings gains a "Restore natural weather" button, which unlocks the cycle, and a slider for how long a weather change takes.
[*]New: Export Selected - a button in Settings opens a tick-box list of every location. Pick any set, filter to narrow it down, and copy one export string for the lot. Paste it into a .txt to share as a preset.
[*]New: A "Console Logging" setting. SLM wrote a console line per location loaded - dozens on every load with presets installed. It is now quiet by default and reports only problems. Info shows what it is doing, Debug restores every line. Dumps and export confirmations always print.
[*]New: An import button on the Locations tab, so importing no longer means a trip to Settings.
[*]New: Pick an icon for a category as you create it - type a new name in the Edit or Manual Coordinates window and click the symbol beside the box. Existing categories keep the icon set in the Category Manager.
[*]New: Setting a map pin over a waypoint you already had now tells you it replaced it, and clearing the pin hands the route back to that waypoint.
[*]New: Map Waypoint Bug Fixes is now required. It clears the HUD and minimap marker a map pin leaves behind when replaced or cleared.
[*]New: Codeware is now required. It is what makes setting the weather possible.
[*]New: Optional Window Utils support. With it installed the SLM window snaps to that mod's grid, animates as it opens and closes, and can be arranged alongside your other mod windows.
[*]Fix: Importing locations that use a category you do not have now creates it. The name reached the locations but never your Custom Categories list, and was lost again on re-export.
[*]Fix: Exporting several locations sharing a custom category repeated that category once per location in the string.
[*]Fix: Deleting a location could collapse its group when the default group state is Collapsed. Groups now stay as you left them.
[*]Fix: Reloading CET left a map pin behind that nothing could remove for the rest of the session.
[*]Fix: The Cancel button was cut off the edge of the Manual Coordinates window.
[*]Minor code improvements
[/list][/spoiler]
[b][size=3]Version 1.5.0[/size][/b]
[spoiler][list][*]Feature: Manual Coordinates - a new button next to "Add current location" lets you save or teleport to a shared X/Y/Z (with optional Yaw) without typing a CET console command. Choose Save, Save & Teleport, or Teleport.
[*]Feature: SmartPaste™ - the Manual Coordinates box understands labeled values (x= y= z= yaw=, including AMM JSON), full CET Vector4.new(...) / EulerAngles.new(...) teleport commands, and plain "x, y, z" number lists. It drives the fields and has a clear button. Always double-check the auto-filled values before saving or teleporting.
[*]Feature: A-Z View - a third sort mode that lists every location in one flat alphabetical list, with no district or category grouping.
[*]Fix: Renamed the mod's window titles from "[SLM]" to "SLM - " to prevent a conflict with other CET mods.
[/list][/spoiler]
```

> Character count: 4347 / 5000

### Comment 3 - older versions

```
[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]

[i](Continued - older versions)[/i]

[b][size=3]Version 1.4.0[/size][/b]
[spoiler][list][*]QOL: Group State Persistence - Manually expanded/collapsed groups now maintain their state across searches. Groups auto-expand when search results appear in them, and return to their previous state when search is cleared.
[*]QOL: Dump Coordinates Auto-Copy - The Dump Coordinates button in the settings tab now automatically copies to clipboard for easy pasting.
[*]QOL: Dump District Info Preview - District info now displays as a live preview in the Debugging panel (light blue text).
[*]QOL: Middle-Click Copy on Previews - Both coordinate and district info previews can be middle-clicked to copy to clipboard with a tooltip hint.
[/list][/spoiler]
[b][size=3]Version 1.3.1[/size][/b]
[spoiler][list][*]Bug Fix: Resolved issue where Preset Updates were failing due to incorrect duplicate detection.
[*]Bug Fix: Self-Healing IDs - Preset updates now automatically repair broken ID links caused by re-exports or fresh installs.
[*]Feature: User Edit Protection - Manual edits to Preset locations now prevent future preset updates from overwriting your changes.
[*]Feature: Smart Conflict Resolution - "Conflict" skips now respect Manual Input locations, preventing accidental overwrites by the Self-Healing logic.
[/list][/spoiler]
[b][size=3]Version 1.3.0[/size][/b]
[spoiler][list][*]QOL: Export Filtered - Added a copy button next to the search bar to export only the locations matching your current search.
[*]QOL: Improved Footer - Now displays filtered counts when searching (e.g., "Locations: 5 / 20").
[*]QOL: Better Descriptions - Increased input height to 3.5 lines and character limit to 500. Added a character counter.
[*]Bug Fix: Clicking the New Location button no longer auto-saves. Locations are created only when you explicitly click "Save". Should reduce any accidental location creations.
[*]Bug Fix: Resolved layout glitches in "Duplicate Warning" and "Edit Location" modals.
[/list][/spoiler]
[b][size=3]Version 1.2.1[/size][/b]
[spoiler][list][*]Added "V2" Export Compression (70% smaller strings). Old SLM strings will still import without issue.
[/list][/spoiler]
[b][size=3]Version 1.1.0[/size][/b]
[spoiler][list][*]Feature: Categories - Locations can now be assigned a Category (Icon + Name) for better organisation
[*]Feature: Custom Category Portability - Exports and Imports now automatically include custom category definitions
[*]Feature: AMM Support - Full support for importing Appearance Menu Mod locations (Bulk Import & String Import)
[*]Feature: Preset Support (For Authors) - Distribute full location packs with custom categories/icons that auto-install for players
[*]Feature: Category Manager - Create, Edit, and Delete custom categories
[*]Feature: Lazy Mode - The "enable Lazy Mode" (Teleport Buttons) setting is now persistent and saves to your config
[*]UI Improvement: Category View - Added dedicated filtering tab to view locations by Category
[*]UI Improvement: Readability - Ensured consistent icon use and added UI colour improvements
[*]UI Improvement: Sorting - The Locations list is now sorted alphabetically
[*]UI Improvement: Modals - Standardised all modal window styling and behaviour
[*]UI Improvement: Polish - Various other fixes and tweaks to the UI
[*]UI Improvement: Lazy Mode - "Toned down" the Lazy Mode teleport warning.
[/list][/spoiler]
[b][size=3]Version 1.0.0[/size][/b]
[spoiler][list][*]Initial Upload
[/list][/spoiler]
```

> Character count: 3542 / 5000
