# Simple Location Manager - Changelog

## v1.3.1 (Hotfix)

- **Fix**: Resolved issue where Preset Updates were failing due to incorrect duplicate detection.
- **Fix**: **Self-Healing IDs**: Preset updates now automatically repair broken ID links caused by re-exports or fresh installs.
- **Feature**: **User Edit Protection**: Manual edits to Preset locations now prevent future preset updates from overwriting your changes.
- **Feature**: **Smart Conflict Resolution**: "Conflict" skips now intelligently respect Manual Input locations, preventing accidental overwrites by the Self-Healing logic.
- **Documentation**: Added `IMPORT_EXPORT_LOGIC.md` detailing the full logic flow.

## v1.3.0 (QOL Update)

### Quality of Life

- **Export Filtered**: Added a copy button next to the search bar to export only the locations matching your current search.
- **Improved Footer**: Now displays filtered counts when searching (e.g., "Locations: 5 / 20").
- **Better Descriptions**: Increased input height to 3.5 lines and character limit to 500. Added character counter.

### Bug Fixes

- **New Location Logic**: Clicking specific buttons no longer auto-saves. Locations are created only when you explicitly click "Save".
- **Modal Fixes**: Resolved layout glitches in "Duplicate Warning" and "Edit Location" modals.
- **UI Fixes**: Fixed search bar width preventing the export button from appearing.

## v1.2.1

- **Fix**: Fixed missing IDs in V2 Export strings (Critical for Preset updates).

## v1.2.0

- **Feature**: Export Compression (V2) - Export strings are now ~70-75% smaller.
- **Feature**: Added "Hidden Gem" category.

## v1.1.0 (Integration Update)

### Features

- **Categories**: Locations can now be assigned a Category (Icon + Name) for better organization.
- **Custom Category Portability**: Exports and Imports now automatically include custom category definitions. Sharing locations with custom icons works seamlessly.
- **AMM Support**: Added full support for importing Appearance Menu Mod (AMM) locations.
  - **Bulk Import**: Scan your `User/Locations` folder to mass-import existing AMM locations.
  - **String Import**: Paste AMM JSON location strings directly into the Import box.
- **Preset Support (For Authors)**: Distribute full location packs with custom categories/icons that auto-install seamlessly for players.

### Features (v1.1.0 continued)

- **Category Manager**: New "Manage Categories" interface.
  - Create, Edit, and Delete custom categories.
  - Includes a safety modal for deletion.
- **Lazy Mode**: The "Lazy Mode" (Teleport Buttons) setting is now persistent and saves to your config.

### UI Improvements (v1.1.0)

- **Category View**: Added a dedicated filtering tab to view locations by Category.
- **Readability**: Replaced text buttons with clear, consistent Icons and added UI colour improvements.
- **Sorting**: The Locations list is now sorted alphabetically.
- **Modals**: Standardized all modal styling and behavior.
- **Polish**: Various other fixes and tweaks to the UI.

## v1.0.0 (Initial Release)

- **Core Release**: First public release of Simple Location Manager.
- **Features**:
  - Save/Edit/Delete Locations.
  - Automatic District & Sub-District detection.
  - Favorites system.
  - Grouping and Search functionality.
  - Navigation (Map Pin) integration.
  - Import/Export system (Base64).
  - Customizable settings (Dupes, UI density, Teleport).

## v0.9.5 (Beta)

- **Import/Export**: Added full Import/Export module with Base64 support.
- **UI**: Added "Default Group State" setting (Expanded/Collapsed).
- **UI**: Added Footer with Location Count and Version.
- **UI**: Converted text buttons to Icons for cleaner look.
- **Fix**: Resolved crash in `GetLocation`.
- **Fix**: Fixed "Clear Map Pin" icon availability.

## v0.9.0 (Beta)

- **Logic**: Implemented "Duplicate Location" warning system (Distance check).
- **Logic**: Refactored Settings to use a dynamic default system.
- **Logic**: Removed legacy `debugMode`.
- **UI**: Added "Show Coordinates" and "Show District" configuration toggles.
- **Feature**: Added "Timestamp" auto-naming if name field is empty.

## v0.8.0 (Alpha)

- **Core**: Initial implementation of "Smart Grouping" (District -> Sub-District).
- **Core**: Added Favorites system.
- **Core**: Added Search filtering.
- **UI**: Implemented confirmation modals for Delete/Reset actions.
