# Simple Location Manager — Nexus Changelogs

### [Unreleased - v1.6.0]
- New: Time & Weather - a location can remember a time of day and a weather state. Turn it on per location in the Edit window; "Use current" copies whatever the game is doing right now.
- New: Left-click a teleport button to teleport as always. Right-click it to teleport AND set that location's saved time and weather, so you choose per teleport.
- New: Custom weather states are supported. Anything a weather mod adds shows up in the picker automatically. If you save a location using a modded weather and later remove that mod, the location still works - the time is applied and the weather is skipped, and it comes back if you reinstall the mod.
- New: Saving the time is now optional, the same way the weather already was. A location can set the weather and leave the time of day alone, or the other way round.
- New: "Restore natural weather" button in Settings. Setting a weather state stops the game's weather cycle; this hands it back.
- New: The footer shows the current game time and weather state, so you can see what SLM is doing to them without opening another mod. A padlock appears when SLM is holding the weather - right-click it to hand the weather back to the game. Amber while held, red if something else has replaced it.
- New: A setting for how long the weather takes to change.
- New: If a teleport knocks the weather off the one you saved, SLM puts it back once. If it gets taken again - which means another weather mod is holding a locked state - it tells you instead of silently doing nothing. Clear that mod's lock first.
- New: Optional Window Utils support. With it installed, the SLM window snaps to the grid, animates, and can be managed from the Window Utils panel. Without it, nothing changes.
- New: Codeware is now required. It is what makes setting the weather possible.
- Fix: Exporting several locations that share a custom category repeated that category once per location in the export string.
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
- Feature: Preset Support (For Authors) - Distribute full location packs with custom categories/icons that auto-install seamlessly for players
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

**1.6.0 is an internal checkpoint and was never uploaded to Nexus.** It is tested and tagged
(`slm-v1.6.0-internal`) but deliberately unpublished, so its section stays under
`[Unreleased - v1.6.0]`.

The next batch becomes `[Unreleased - v1.7.0]`, added **above** it rather than merged into it.
When that ships, **both sections go up together**: the GitHub Release body must carry 1.7.0 and
1.6.0, because `release.yml` appends only the body to the Nexus page changelog, and a reader who
skipped straight from 1.5.0 to 1.7.0 never saw the 1.6.0 entries.

The stickied-comment BBCode needs the same treatment - two version blocks in the newest post, not one.

---
## Stickied Comment BBCode

The history no longer fits one Nexus comment (5000 char limit), so it is two posts. Post the second one first, then the first, so the newest sits at the top of the thread.

### Comment 1 - current

```
[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]

[b][size=3]Version 1.6.0[/size][/b]
[list][*]New: Time & Weather - a location can remember a time of day and a weather state. Turn it on per location in the Edit window; "Use current" copies whatever the game is doing right now.
[*]New: Left-click a teleport button to teleport as always. Right-click it to teleport AND set that location's saved time and weather, so you choose per teleport.
[*]New: Custom weather states are supported. Anything a weather mod adds shows up in the picker automatically. If you save a location using a modded weather and later remove that mod, the location still works - the time is applied and the weather is skipped, and it comes back if you reinstall the mod.
[*]New: Saving the time is now optional, the same way the weather already was. A location can set the weather and leave the time of day alone, or the other way round.
[*]New: "Restore natural weather" button in Settings. Setting a weather state stops the game's weather cycle; this hands it back.
[*]New: The footer shows the current game time and weather state, so you can see what SLM is doing to them without opening another mod. A padlock appears when SLM is holding the weather - right-click it to hand the weather back to the game. Amber while held, red if something else has replaced it.
[*]New: A setting for how long the weather takes to change.
[*]New: If a teleport knocks the weather off the one you saved, SLM puts it back once. If it gets taken again - which means another weather mod is holding a locked state - it tells you instead of silently doing nothing. Clear that mod's lock first.
[*]New: Optional Window Utils support. With it installed, the SLM window snaps to the grid, animates, and can be managed from the Window Utils panel. Without it, nothing changes.
[*]New: Codeware is now required. It is what makes setting the weather possible.
[*]Fix: Exporting several locations that share a custom category repeated that category once per location in the export string.
[*]Minor code improvements
[/list]
[b][size=3]Version 1.5.0[/size][/b]
[spoiler][list][*]Feature: Manual Coordinates - a new button next to "Add current location" lets you save or teleport to a shared X/Y/Z (with optional Yaw) without typing a CET console command. Choose Save, Save & Teleport, or Teleport.
[*]Feature: SmartPaste™ - the Manual Coordinates box understands labelled values (x= y= z= yaw=, including AMM JSON), full CET Vector4.new(...) / EulerAngles.new(...) teleport commands, and plain "x, y, z" number lists. Always double-check the auto-filled values before saving or teleporting.
[*]Feature: A-Z View - a third sort mode that lists every location in one flat alphabetical list, with no district or category grouping.
[*]Fix: Renamed the mod's window titles to the "SLM - " prefix to prevent a conflict with other CET mods.
[/list][/spoiler]
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
```

> Character count: 4875 / 5000

### Comment 2 - older versions

```
[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]

[i](Continued - older versions)[/i]

[b][size=3]Version 1.2.1[/size][/b]
[spoiler][list][*]Added "V2" Export Compression (70% smaller strings). Old SLM strings will still import without issue.
[/list][/spoiler]
[b][size=3]Version 1.1.0[/size][/b]
[spoiler][list][*]Feature: Categories - Locations can now be assigned a Category (Icon + Name) for better organisation
[*]Feature: Custom Category Portability - Exports and Imports now automatically include custom category definitions
[*]Feature: AMM Support - Full support for importing Appearance Menu Mod locations (Bulk Import & String Import)
[*]Feature: Preset Support (For Authors) - Distribute full location packs with custom categories/icons that auto-install seamlessly for players
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
[b][size=3]Version 1.0.0apartments[/size][/b]
[spoiler][list][*]Initial upload of the Vanilla/DLC apartments preset
[/list][/spoiler]
[b][size=3]Version 1.0.0kp[/size][/b]
[spoiler][list][*]Initial upload of the Konpeki Plaza SLM preset
[/list][/spoiler]
[b][size=3]Version 1.0.0joker[/size][/b]
[spoiler][list][*]Initial upload of the Balatro / Jim B Joker SLM preset
[/list][/spoiler]
```

> Character count: 1970 / 5000
