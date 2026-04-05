### [2026-02-22] Initial
- Repository created from workspace restructure.

---

## Historical Changelog (Pre-Restructure)

### v1.0.0
- Initial Upload

### v1.0.0apartments
- Initial upload of the Vanilla/DLC apartments preset

### v1.0.0kp
- Initial upload of the Konpeki Plaza SLM preset

### v1.1.0
- Feature: Categories - Locations can now be assigned a Category (Icon + Name) for better organisation
- Feature: Custom Category Portability - Exports and Imports now automatically include custom category definitions
- Feature: AMM Support - Full support for importing Appearance Menu Mod locations (Bulk Import &amp; String Import)
- Feature: Preset Support (For Authors) - Distribute full location packs with custom categories/icons that auto-install seamlessly for players
- Feature: Category Manager - Create, Edit, and Delete custom categories
- Feature: Lazy Mode - The "enable Lazy Mode" (Teleport Buttons) setting is now persistent and saves to your config
- UI Improvement: Category View - Added dedicated filtering tab to view locations by Category
- UI Improvement: Readability - Ensured consistent icon use and added UI colour improvements
- UI Improvement: Sorting - The Locations list is now sorted alphabetically
- UI Improvement: Modals - Standardised all modal window styling and behaviour
- UI Improvement: Polish - Various other fixes and tweaks to the UI
- UI Improvement: Lazy Mode - "Toned down" the Lazy Mode teleport warning.

### v1.2.1
- Added "V2" Export Compression (70% smaller strings). Old SLM strings will still import without issue.

### v1.3.0
- QOL: Export Filtered - Added a copy button next to the search bar to export only the locations matching your current search.
- QOL: Improved Footer - Now displays filtered counts when searching (e.g., "Locations: 5 / 20").
- QOL: Better Descriptions - Increased input height to 3.5 lines and character limit to 500. Added a character counter.
- Bug Fix: Clicking the New Location button no longer auto-saves. Locations are created only when you explicitly click "Save". Should reduce any accidental location creations.
- Bug Fix: Resolved layout glitches in "Duplicate Warning" and "Edit Location" modals.

### v1.3.1
- Bug Fix: Resolved issue where Preset Updates were failing due to incorrect duplicate detection.
- Bug Fix: Self-Healing IDs - Preset updates now automatically repair broken ID links caused by re-exports or fresh installs.
- Feature: User Edit Protection - Manual edits to Preset locations now prevent future preset updates from overwriting your changes.
- Feature: Smart Conflict Resolution - "Conflict" skips now respect Manual Input locations, preventing accidental overwrites by the Self-Healing logic.

### v1.4.0

- QOL: Group State Persistence - Manually expanded/collapsed groups now maintain their state across searches. Groups auto-expand when search results appear in them, and return to their previous state when search is cleared.
