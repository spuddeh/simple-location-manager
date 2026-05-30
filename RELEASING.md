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

1. **API key (secret).** Create a Nexus personal API key at
   <https://www.nexusmods.com/settings/api-keys> and add it as the repository secret
   **`NEXUSMODS_API_KEY`** (Settings > Secrets and variables > Actions).
2. **File group IDs (manifest).** On each mod page, open the **Files** tab > **API Info**
   (or the Manage Files edit menu) to get the file group ID, then replace the
   `REPLACE_WITH_*` placeholders in `release-manifest.json`:
   - `26454`'s group id -> `slm`, `apartments`, `konpeki`, `balatro` (they share the page).
   - `26743`'s group id -> `jnve`.
   File group IDs are not secret, so they live in the manifest.
3. **Backfill history (optional, one-time).** After the repo is pushed, create GitHub Releases
   for the already-published historical versions from the local zips:
   ```pwsh
   pwsh ./scripts/backfill-releases.ps1 -DryRun   # preview
   pwsh ./scripts/backfill-releases.ps1           # create
   ```
   These are GitHub-only (each carries an invisible `<!-- skip-nexus -->` marker so the workflow
   does not re-upload them to Nexus) and are marked non-latest. The zips come from the gitignored
   `_release_archive/` folder.

## Cutting a new release

1. Make and commit your changes; bump the version in the mod (and `@changelog.md` / Nexus files).
2. Create a GitHub Release whose **tag** follows `<artifact>-v<version>`:
   ```pwsh
   gh release create slm-v1.6.0 --title "Simple Location Manager v1.6.0" --notes "..."
   # a preset:
   gh release create konpeki-v1.1.0 --title "Konpeki Plaza Preset v1.1.0" --notes "..."
   ```
   The **release body becomes the Nexus file description**, so write the changelog there.
3. On publish, the workflow:
   - parses the tag -> looks up the artifact in the manifest,
   - stages `contentDir` -> `installDir` and zips it as `<fileBaseName>_v<version>.zip` (e.g. `SimpleLocationManager_v1.6.0.zip`),
   - attaches the zip to the GitHub Release,
   - uploads to Nexus (`file_category`, `display_name`, `archive_existing_file: true`, etc.).
4. **Manually on the Nexus mod page** (the API does NOT do these): bump the **Mod Version**
   field, add the changelog entry, and update the description if needed. The upload-action only
   sets the *file* version (`POST /mod-file-update-groups/{id}/versions`); it never touches the
   mod's headline version, changelog, or description. (The "update available" trigger is most
   likely the new main file / the mod's updated file list rather than the headline version
   string, but bump the version + changelog regardless so the page reads correctly.)
   Recommended order: do these page edits *before* cutting the release.

You can also run it manually from the **Actions** tab (workflow_dispatch) with `artifact` +
`version` inputs (and an optional existing `tag` to attach the zip to).

## Notes

- The Nexus upload uses [`Nexus-Mods/upload-action`](https://github.com/Nexus-Mods/upload-action),
  pinned to `v1.0.0-beta.6`. Nexus currently labels this upload API **evaluation only**, so it may
  change; bump the pin when a stable release appears.
- `archive_existing_file: true` archives the previous file when a new version is uploaded.
- WolvenKit is no longer needed for these CET-only artifacts. A future ArchiveXL/Redscript mod that
  *does* need WolvenKit packing would add a different build path (the manifest can carry a packing
  mode); this tooling is structured so that extension is straightforward.
