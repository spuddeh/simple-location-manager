# Translating Simple Location Manager

SLM reads its interface strings from JSON files in
`bin/x64/plugins/cyber_engine_tweaks/mods/SimpleLocationManager/lang/`.

A translation is one file. Nothing has to be registered, and no slot has to exist
beforehand — SLM scans the folder at startup and picks up whatever is there.

## Making one

1. Copy `lang/en-us.json` to `lang/<code>.json`, where `<code>` is the game's own language
   code: `de-de`, `fr-fr`, `es-es`, `it-it`, `pl-pl`, `pt-br`, `ru-ru`, `zh-cn`, `ja-jp`,
   `ko-kr`, and so on.
2. Set `"@name"` to the language's name **written in that language** — `Deutsch`, not
   `German`. The picker in Settings shows this value.
3. Translate the values. Leave the keys alone.
4. Drop the file in `lang/` and restart the game.

Pick your language in **Settings → Language**, or leave it on *Follow the game* and set the
game to that language.

## Rules that matter

**Translate values, never keys.** `"edit.save": "Speichern"` is right;
`"bearbeiten.speichern"` is a string nobody looks up.

**Keep every `%s` and `%d`.** They are slots the mod fills in at runtime — a name, a count,
a district. `%s` takes text, `%d` takes a number.

```json
"locationRow.districtLine": "District: %s"
"exportSelect.selectedCount": "%d selected"
```

**You may move the slots.** Word order is yours to choose:

```json
"locations.exportCategoryTitle": "Export Category: %s (%d)"
```

If your language needs the count first, write `"(%2$d) %1$s"` — the `N$` form picks a slot
by position.

**Do not add or remove slots.** A slot the mod does not fill renders as a literal `%s`.

**Keep `\n` where it appears.** It is a line break inside a tooltip.

**A partial translation is fine.** Delete the keys you have not done and they fall back to
English, one key at a time. A file with twenty keys works.

## What you cannot translate from here

**Icon names** in the icon picker come from the icon library, not from SLM.

**Log levels** (Off, Error, Warn, Info, Debug) are diagnostic terms and stay English.

**Category and district names** are player data and saved text, not interface strings.

## Non-Latin alphabets need a CET setting

CET draws SLM's window, and CET loads **one** extra alphabet, chosen in its own config —
not by SLM, and not by the game's language.

Latin-alphabet languages (German, French, Spanish, Italian, Portuguese) work as they are.
Cyrillic, Polish, Czech, Turkish, Vietnamese, Thai, Chinese, Japanese and Korean need
`font` → `language` set in
`bin/x64/plugins/cyber_engine_tweaks/config.json`, to one of:

`ChineseFull`, `ChineseSimplifiedCommon`, `Japanese`, `Korean`, `Cyrillic`, `Thai`,
`Vietnamese`

Without it those characters draw as blank boxes. CET defaults this to your Windows system
language, so it is often already correct.

## Checking your work before you share it

- The file is valid JSON. A trailing comma or a missing quote means SLM logs a warning and
  falls back to English entirely.
- The file is saved as **UTF-8**.
- Every `%s` and `%d` in a value is also in the English value for that key.
- Open the mod and walk the tabs. A string you missed shows in English, which is fine; a
  string showing as `edit.save` means that key name got changed.
