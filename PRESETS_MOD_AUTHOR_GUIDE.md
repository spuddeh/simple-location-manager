# Presets: Mod Author Guide

A preset distributes locations as a plain text file. Users drop it in a folder and SLM handles
loading, updating and conflict checks.

> The same guide is published as a [Nexus article](https://www.nexusmods.com/cyberpunk2077/articles/1960).
> Change one and change the other.

## How it works

- **Drop and load**: users drop your `.txt` in the folder, and it appears in-game.
- **Auto-updates**: change your location later and SLM updates it for the user.
- **Conflict checks**: SLM checks for existing locations, so your preset never spams the list or
  overwrites a location the user made themselves.

---

## 1. Creating your Preset

1. **Go there**: stand in your spot in-game.
2. **Save it**: add it to SLM with a name, category and description.
3. **Export it**:
    - **Single location**: the copy button on the location row.
    - **Whole category**: right-click a Category header, then **Export Category**.
    - **Whole district**: right-click a District header, then **Export District**.
    - **A set you pick**: **Settings** tab, then **Export Selected** - tick the locations you want.
    - **Everything**: **Settings** tab, then **Export All Data**.
4. **Save to file**:
    - Create a text file, for example `MyCustomLocation.txt`.
    - Paste the exported code string into it.
    - Keep it to **one preset per file**. Five spots to share means five `.txt` files, so users can
      install only the ones they want.

## 2. Packaging it up

Pack your mod so your files land in:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/SimpleLocationManager/presets/
```

Name the file something unique, like `AuthorName_LocationName.txt`, so it cannot clash with another
author's preset.

## 3. Updating a preset later

SLM remembers the **ID** inside your export string.

To move a location, update your `.txt` with the new export string. When the user installs your
update, SLM matches the ID and **updates the location in place** - no duplicate markers in their
list.

**One exception, and it is deliberate:** if the user has edited that location themselves, SLM marks
it as theirs and your update skips it. Their changes win.

## 4. Conflict detection

SLM checks for existing locations before importing anything new.

- If the user, or another mod, already has a location within **0.5 metres** of yours, your import is
  **skipped**.
- That prevents duplicate waypoints stacking up, and means a preset can never overwrite a location
  the user created by hand.

## 5. Uninstalling a preset

Removing your mod takes the `.txt` away, but the locations it already imported stay in the user's
list.

**Settings** tab, then **Remove Preset Locations**, lists every preset whose file is gone and clears
out what it left behind - one preset at a time, so other presets are untouched. Any location the
user edited themselves is kept and becomes their own.

Worth mentioning on your own mod page, so users know the tidy-up exists.

## 6. Verification

The import lines are off by default. To see them: **Settings** tab, then **Console Logging**, set to
**Debug**.

Open the CET console and reload. You are looking for:

- `Imported Location: The Afterlife Roof` - it is in.
- `Synced Preset Location: ...` - an existing location was updated.
- `[SKIP] Conflict: Position match...` - skipped because something was already there, which is the
  system working as intended.
- `[FIX] Resyncing ID for location: ...` - a broken ID link was repaired.

Set **Console Logging** back to **Warn** when you are done, or the console fills with one line per
location on every load.
