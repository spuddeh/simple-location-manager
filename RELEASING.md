# Releasing

This repo publishes the main mod and its presets to **GitHub Releases** and **Nexus Mods**
automatically via [`.github/workflows/release.yml`](.github/workflows/release.yml), driven by
[`release-manifest.json`](release-manifest.json).

Each publishable artifact (the main mod and each preset) is one entry in the manifest. CET-only
mods are packaged by zipping straight from source - no WolvenKit step. The workflow stages an
artifact's `contentDir` into its `installDir` (the in-game path) and zips that, so `bin/...` lands
at the zip root exactly as the game expects.

## Artifacts

| Artifact id | What | Nexus mod | File on Nexus |
| --- | --- | --- | --- |
| `slm` | The main mod | 26454 | main |
| `apartments` | Vanilla & DLC apartments preset | 26454 | optional |
| `konpeki` | Konpeki Plaza preset | 26454 | optional |
| `balatro` | Balatro / Jim B Joker preset | 26454 | optional |
| `jnve` | JNVE preset (own page) | 26743 | main |

## One-time setup

1. **API key — a real secret.** Create a Nexus personal API key at
   <https://www.nexusmods.com/settings/api-keys> and add it as the repository secret
   **`NEXUSMODS_API_KEY`** (Settings > Secrets and variables > Actions > **Secrets**).

2. **File id — a repository VARIABLE, not a secret, and not in this repo.**

   | Artifact | Variable |
   | --- | --- |
   | `slm` | **`NEXUS_FILE_ID_SLM`** |
   | `apartments` | **`NEXUS_FILE_ID_APARTMENTS`** |
   | `konpeki` | **`NEXUS_FILE_ID_KONPEKI`** |
   | `balatro` | **`NEXUS_FILE_ID_BALATRO`** |
   | `jnve` | **`NEXUS_FILE_ID_JNVE`** |

   Set them under Settings > Secrets and variables > Actions > **Variables**.

   > **The first Nexus upload must be done BY HAND.** A `file_id` does not exist until a file has
   > been uploaded to the mod page once — so this pipeline can publish a mod's **updates**, never its
   > **first** file. That is also why the id is not committed: before the first upload there is nothing
   > to commit but a lie. Until the variable is set, the workflow hard-fails rather than uploading into
   > the void.
   >
   > **Where to get it:** the mod page's **Files** tab > **API Info** (or the Manage Files edit menu),
   > where Nexus still labels it **"Group ID"**. It is only visible to you, as the mod's author.
   >
   > **Do NOT take it from the public v1 API.** That endpoint has a field also called `file_id`, it is a
   > **different id space**, and the wrong value looks entirely plausible — it fails only at release time.
   >
   > **Why a variable and not a secret:** it is an identifier, not a credential. It authorizes nothing
   > without `NEXUSMODS_API_KEY`, and anyone holding that key could enumerate the ids anyway. Masking it
   > as a secret would buy no safety and would render it `***` in the logs — making a wrong id, the one
   > mistake that is actually easy to make here, much harder to diagnose.

## Cutting a new release

1. Make and commit your changes; bump the version in the mod (and `@changelog.md` / Nexus files).
2. Create a GitHub Release whose **tag** follows `<artifact>-v<version>`:
   ```pwsh
   gh release create slm-v1.6.0 --title "Simple Location Manager v1.6.0" --notes "..."
   # a preset:
   gh release create konpeki-v1.1.0 --title "Konpeki Plaza Preset v1.1.0" --notes "..."
   ```
   The release body feeds two Nexus fields, split by a `<!-- nexus-description-end -->` marker on its own line. Everything **before** the marker becomes the **file description** (capped at 255 chars — for example a new requirement, or "delete the old folder first"); everything **after** it is appended to the mod page's **changelog**. With no marker at all, the whole body becomes the changelog and no file description is sent.
3. On publish, the workflow:
   - parses the tag -> looks up the artifact in the manifest,
   - stages `contentDir` -> `installDir` and zips it as `<fileBaseName>_v<version>.zip` (e.g. `SimpleLocationManager_v1.6.0.zip`),
   - attaches the zip to the GitHub Release,
   - uploads to Nexus (`category`, `display_name`, `archive_existing_version: true`, etc.).
4. **On the Nexus mod page:** the workflow sets the **Mod Version** field and appends the
   **changelog** entry itself. Only the mod **description** is still manual.
   The changelog endpoint APPENDS rather than replaces, so publishing the same release twice
   leaves the entry on the page twice and nothing here can remove it. A `workflow_dispatch`
   re-run never posts a changelog.
   Presets are the exception: they carry `"update_mod_version": false`, so a preset release sets
   neither the page version nor the page changelog. Page 26454 belongs to `slm` and page 26743 to
   `jnve`; a preset's `1.0.0kp`-style version is a file version and nothing more.

5. **Both Nexus-bound blocks are generated, not hand-written.** Run this after **any** changelog
   wording change, not only at release:
   ```pwsh
   python scripts/build-nexus-blocks.py
   ```
   It rewrites two sections of `nexus_changelog.md` in place, and refuses to write if either
   overruns its limit:
   - **`## Release body`** - paste it whole into the GitHub Release. The changelog endpoint
     **splits on newlines**, one line to one bullet, so entries are emitted unwrapped and with
     no `- ` prefix; a dash would render inside the bullet. It carries the newest two versions,
     because 1.6.0 was never uploaded on its own.
   - **`## Stickied Comment BBCode`** - posted by hand as comments on the mod page, split across
     posts to stay under the 5000-character limit. Post the last one first and work back, so the
     newest sits at the top of the thread.

You can also run it manually from the **Actions** tab (workflow_dispatch) with `artifact` +
`version` inputs (and an optional existing `tag` to attach the zip to).

## Notes

- The Nexus upload uses [`Nexus-Mods/upload-action`](https://github.com/Nexus-Mods/upload-action),
  pinned to `v1.0.0-beta.10` (the Nexus v3 upload API). The `createModFileVersion` endpoint it
  uses replaces the old `createUpdateGroupVersion`, which Nexus **removes on 2026-09-09** — so a
  pin older than beta.8 stops uploading after that date. beta.9 added `update_mod_version`, beta.10
  the changelog endpoint; both are wired up here. The API is still labelled evaluation-only, so bump
  the pin when a stable release appears (watch for further input renames).
- `archive_existing_version: true` archives the previous file when a new version is uploaded.
- `show_requirements_pop_up: true` shows the requirements popup on download (SLM requires CET; the
  presets require SLM). Set an artifact's `show_requirements_pop_up` to `false` only if it has no
  mod requirements at all.
- WolvenKit is no longer needed for these CET-only artifacts. A future ArchiveXL/Redscript mod that
  *does* need WolvenKit packing would add a different build path - the manifest can carry a packing
  mode.
