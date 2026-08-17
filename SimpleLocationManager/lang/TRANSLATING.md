# Translating Simple Location Manager

SLM reads its interface strings from the JSON files in this folder.

A translation is one file. Nothing has to be registered and no slot has to exist beforehand:
SLM scans this folder at startup and picks up whatever is in it.

## Making one

1. Copy `en-us.json` to `<code>.json`, where `<code>` is the game's own language code:
   `de-de`, `fr-fr`, `es-es`, `it-it`, `pl-pl`, `pt-br`, `ru-ru`, `zh-cn`, `ja-jp`, `ko-kr`,
   and so on.
2. Set `"@name"` to the language's name written in that language - `Deutsch`, not `German`.
   The language picker in Settings shows this value.
3. Translate the values. Leave the keys alone.
4. Save the file here and restart the game.

Pick the language under **Settings > Language**, or leave it on *Follow the game* and set the
game to that language.

## Rules

**Translate values, never keys.** `"edit.save": "Speichern"` is right; renaming the key to
`"bearbeiten.speichern"` leaves a string nothing looks up.

**Keep every `%s` and `%d`.** They are slots SLM fills at runtime with a name, a count or a
district. `%s` takes text, `%d` takes a number.

```json
"locationRow.districtLine": "District: %s",
"exportSelect.selectedCount": "%d selected"
```

**The slots may move.** Word order belongs to the translation:

```json
"locations.exportCategoryTitle": "Export Category: %s (%d)"
```

Where the count reads better first, number the slots: `%1$` is the first value SLM passes,
`%2$` the second, whatever order they appear in.

```json
"locations.exportCategoryTitle": "Kategorie exportieren: (%2$d) %1$s"
```

Number every slot in a string or none of them. Mixing `%s` and `%2$s` in one string is
ambiguous and the line will show unformatted.

**Do not add or remove slots.** A slot SLM has no value for renders as a literal `%s`.

**Keep `\n` where it appears.** It is a line break inside a tooltip.

**A partial translation works.** Delete the keys that are not done and each one falls back to
English on its own. A file holding twenty keys is a valid translation.

## What this file does not reach

**Icon names** in the icon picker come from the icon library.

**Log levels** (Off, Error, Warn, Info, Debug) are diagnostic terms and stay English.

**Category and district names** are saved player data rather than interface strings.

## Non-Latin alphabets need a CET setting

CET draws SLM's window, and CET loads one extra alphabet, chosen in its own config rather
than by SLM or by the game's language.

Latin-alphabet languages such as German, French, Spanish, Italian and Portuguese need
nothing. Cyrillic, Polish, Czech, Turkish, Vietnamese, Thai, Chinese, Japanese and Korean
need `font` then `language` set in `bin/x64/plugins/cyber_engine_tweaks/config.json` to one
of:

`ChineseFull`, `ChineseSimplifiedCommon`, `Japanese`, `Korean`, `Cyrillic`, `Thai`,
`Vietnamese`

Without it those characters draw as blank boxes. CET takes its default from the Windows
system language, so it is often already right.

## Checking a translation before sharing it

- The file is valid JSON. A trailing comma or a missing quote makes SLM log a warning and
  fall back to English for the whole file.
- The file is saved as UTF-8.
- Every `%s` and `%d` in a value also appears in the English value for that key.
- Open the mod and walk the tabs. A string left in English is a key not yet translated; a
  string showing as `edit.save` is a key that got renamed.
