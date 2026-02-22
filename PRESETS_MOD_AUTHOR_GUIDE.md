# Presets: Mod Author Guide

So you've found a preem photo spot, a secret hideout, or built a custom location, and you want to share it with the world? The **Preset Import** feature makes it super easy.

It allows you to distribute your locations as simple text files. SLM handles the rest - loading, updating, and making sure nothing breaks.

## How it works

- **Drop & Load**: Users just drop your `.txt` file in the folder, and it appears in-game.
- **Auto-Updates**: If you tweak your location later, SLM updates it for the user automatically.
- **Safety First**: We check for existing locations so we don't spam the user's UI or overwrite their own saves.

---

## 1. Creating your Preset

1. **Go there**: Stand in your spot in-game.
2. **Save it**: Add it to SLM. Give it a nice name, category, and description.
3. **Export it**:
    - **Single Location**: Select it and click **Export to Clipboard**.
    - **Whole Category**: Right-click a Category header -> **Export Category**.
    - **Whole District**: Right-click a District header -> **Export District**.
    - **Everything**: Config Tab -> **Export All Data**.
4. **Save to File**:
    - Create a new text file (e.g., `MyCustomLocation.txt`).
    - Paste that code string right in there.
    - **Pro Tip**: Keep it to **one location string per file**. If you have 5 spots to share, just make 5 `.txt` files. It keeps things clean and easy to manage!

## 2. Packaging it up

Pack your mod so your files land in this folder:

```md
bin/x64/plugins/cyber_engine_tweaks/mods/SimpleLocationManager/presets/
```

**Tip**: Name your file something unique (like `AuthorName_LocationName.txt`) so you don't accidentally clash with other modders.

## 3. Updates (Calculated Magic)

SLM remembers the **ID** inside your export string.

If you decide later that your "Secret Base" needs to be moved 2 meters to the left, just update your `.txt` file with the new export string (from the updated location). When the user installs your update, SLM will see the matching ID and **update the location automatically**.

This means users always get your latest version without duplicate markers cluttering their list! ✨

## 4. Conflict Detection (No Drama)

We respect the user's game state. Before importing anything new, SLM checks for existing locations.

- If the user (or another mod) already has a location within **0.5 meters** of yours, we **SKIP** your import.
- **Why?**
  1. To prevent 10 duplicate waypoints stacking on top of each other.
  2. To ensure we **never overwrite a user's manually created location**. Their personal saves are sacred!

## 5. Verification

Want to check if it's working? Open the CET console and check the logs:

- `Imported Location: The Afterlife Roof` -> Success! It's in.
- `Synced Preset Location: ...` -> Updated an existing one.
- `[SKIP] Conflict: Position match...` -> Skipped because something was already there. (System working as intended!)

Happy modding! 🚀
