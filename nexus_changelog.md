# Simple Location Manager — Nexus Changelogs

### [Unreleased - v1.7.0]
- New: An import button on the Locations tab, so importing no longer means a trip to Settings.
- New: Pick an icon for a category as you create it - type a new name in the Edit or Manual Coordinates window and click the symbol beside the box. Existing categories keep the icon set in the Category Manager.
- New: Export Selected - a button in Settings opens a tick-box list of every location. Pick any set, filter to narrow it down, and copy one export string for the lot. Paste it into a .txt to share as a preset.
- New: A "Console Logging" setting. SLM wrote a console line per location loaded - dozens on every load with presets installed. It is now quiet by default and speaks up only about problems. Info shows what it is doing, Debug restores every line. Dumps and export confirmations always print.
- New: Map Waypoint Bug Fixes is now required. It clears the HUD and minimap marker a map pin leaves behind when replaced or cleared.
- New: Setting a map pin over an existing waypoint now says so. An SLM pin takes over the tracked waypoint, so the minimap route follows the pin.
- New: Clearing an SLM map pin hands the route back to the waypoint you had set before it, instead of leaving you with none.
- Fix: Importing locations that use a category you do not have now creates it. The name reached the locations but never your Custom Categories list, and was lost again on re-export.
- Fix: Map pins are cleared when the mod shuts down or CET reloads. One left behind that way could not be removed for the rest of the session.
- Fix: Deleting a location could collapse its group when the default group state is Collapsed. Groups now stay as you left them.
- Fix: The Cancel button was cut off the edge of the Manual Coordinates window.

### [Unreleased - v1.6.0]
- New: Time & Weather - a location can remember a time of day and a weather state. Turn it on per location in the Edit window; "Use current" copies what the game is doing now.
- New: Right-click a teleport button to teleport and apply that location's saved time and weather. Left-click teleports as always, and releases any weather SLM was holding.
- New: The time and the weather are separately optional. A location can set one and leave the other alone.
- New: Custom weather states are supported - anything a weather mod adds appears in the picker. Remove that mod later and the location still works: the time applies, the weather is skipped, and it returns if you reinstall.
- New: Teleporting to a location with no weather set hands the sky back to the game's cycle, so the last location's weather does not follow you. Only SLM's own hold is released.
- New: A weather state SLM sets is held. The game knocks the weather off a forced state on its own, and teleporting is enough to do it, so SLM puts it back. If something keeps taking it, SLM says so and lets go - clear that mod's lock first.
- New: The footer shows the current game time and weather state. A padlock appears while SLM is holding the weather - right-click it to hand the weather back. Amber while held, red once something else has replaced it.
- New: "Restore natural weather" button in Settings. Forcing a weather state stops the game's cycle; this hands it back.
- New: A setting for how long the weather takes to change.
- New: Optional Window Utils support. With it installed the SLM window snaps to the grid, animates, and appears in the Window Utils panel.
- New: Codeware is now required. It is what makes setting the weather possible.
- Fix: Exporting several locations sharing a custom category repeated that category once per location in the string.
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

**The newest post carries both, at 3824 of the 5000 allowed.** 1.7.0 is 1819 characters of BBCode and
1.6.0 is 1947. Entries are written a line at a time and kept to a line: the first draft of these two
sections came to 4980 together, which left twenty characters spare and no room to edit anything.

**Editing a 1.7.0 or 1.6.0 entry means regenerating the BBCode and re-checking the count.** If the
newest post ever stops fitting, tighten the wording first; moving 1.6.0 into the second post is the
fallback, and it costs a reader who skipped 1.5.0 to 1.7.0 the entries they never saw.

Older versions pack to a 4500 ceiling rather than 5000, so those posts absorb an edit without
forcing another re-split.

---
## Stickied Comment BBCode

The history no longer fits one Nexus comment (5000 char limit), so it is 2 posts. Post the last one first and work back, so the newest sits at the top of the thread.

### Comment 1 - current

```
[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]

[b][size=3]Version 1.7.0[/size][/b]
[list][*]New: An import button on the Locations tab, so importing no longer means a trip to Settings.
[*]New: Pick an icon for a category as you create it - type a new name in the Edit or Manual Coordinates window and click the symbol beside the box. Existing categories keep the icon set in the Category Manager.
[*]New: Export Selected - a button in Settings opens a tick-box list of every location. Pick any set, filter to narrow it down, and copy one export string for the lot. Paste it into a .txt to share as a preset.
[*]New: A "Console Logging" setting. SLM wrote a console line per location loaded - dozens on every load with presets installed. It is now quiet by default and speaks up only about problems. Info shows what it is doing, Debug restores every line. Dumps and export confirmations always print.
[*]New: Map Waypoint Bug Fixes is now required. It clears the HUD and minimap marker a map pin leaves behind when replaced or cleared.
[*]New: Setting a map pin over an existing waypoint now says so. An SLM pin takes over the tracked waypoint, so the minimap route follows the pin.
[*]New: Clearing an SLM map pin hands the route back to the waypoint you had set before it, instead of leaving you with none.
[*]Fix: Importing locations that use a category you do not have now creates it. The name reached the locations but never your Custom Categories list, and was lost again on re-export.
[*]Fix: Map pins are cleared when the mod shuts down or CET reloads. One left behind that way could not be removed for the rest of the session.
[*]Fix: Deleting a location could collapse its group when the default group state is Collapsed. Groups now stay as you left them.
[*]Fix: The Cancel button was cut off the edge of the Manual Coordinates window.
[/list]
[b][size=3]Version 1.6.0[/size][/b]
[spoiler][list][*]New: Time & Weather - a location can remember a time of day and a weather state. Turn it on per location in the Edit window; "Use current" copies what the game is doing now.
[*]New: Right-click a teleport button to teleport and apply that location's saved time and weather. Left-click teleports as always, and releases any weather SLM was holding.
[*]New: The time and the weather are separately optional. A location can set one and leave the other alone.
[*]New: Custom weather states are supported - anything a weather mod adds appears in the picker. Remove that mod later and the location still works: the time applies, the weather is skipped, and it returns if you reinstall.
[*]New: Teleporting to a location with no weather set hands the sky back to the game's cycle, so the last location's weather does not follow you. Only SLM's own hold is released.
[*]New: A weather state SLM sets is held. The game knocks the weather off a forced state on its own, and teleporting is enough to do it, so SLM puts it back. If something keeps taking it, SLM says so and lets go - clear that mod's lock first.
[*]New: The footer shows the current game time and weather state. A padlock appears while SLM is holding the weather - right-click it to hand the weather back. Amber while held, red once something else has replaced it.
[*]New: "Restore natural weather" button in Settings. Forcing a weather state stops the game's cycle; this hands it back.
[*]New: A setting for how long the weather takes to change.
[*]New: Optional Window Utils support. With it installed the SLM window snaps to the grid, animates, and appears in the Window Utils panel.
[*]New: Codeware is now required. It is what makes setting the weather possible.
[*]Fix: Exporting several locations sharing a custom category repeated that category once per location in the string.
[*]Minor code improvements
[/list][/spoiler]
```

> Character count: 3806 / 5000

### Comment 2 - older versions

```
[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]

[i](Continued - older versions)[/i]

[b][size=3]Version 1.5.0[/size][/b]
[spoiler][list][*]Feature: Manual Coordinates - a new button next to "Add current location" lets you save or teleport to a shared X/Y/Z (with optional Yaw) without typing a CET console command. Choose Save, Save & Teleport, or Teleport.
[*]Feature: SmartPaste™ - the Manual Coordinates box understands labeled values (x= y= z= yaw=, including AMM JSON), full CET Vector4.new(...) / EulerAngles.new(...) teleport commands, and plain "x, y, z" number lists. It drives the fields and has a clear button. Always double-check the auto-filled values before saving or teleporting.
[*]Feature: A-Z View - a third sort mode that lists every location in one flat alphabetical list, with no district or category grouping.
[*]Fix: Renamed the mod's window titles from "[SLM]" to "SLM - " to prevent a conflict with other CET mods.
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
```

> Character count: 4426 / 5000
