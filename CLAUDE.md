# SimpleLocationManager (SLM)

**Family:** Standalone (Location/Utility)
**Status:** Published
**Version:** 1.3.1
**Summary:** Save locations with custom names and descriptions. SLM automatically organises them by District, so you never lose a spot again. Features custom categories, map pins, search features, and instant teleport. Simple, powerful, and clean.
**Nexus:** [Simple Location Manager](https://www.nexusmods.com/cyberpunk2077/mods/26454)

## Key Files

- Entry: `source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/SimpleLocationManager/init.lua`
- Modules: `source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/SimpleLocationManager/modules/`
- Config: `config.json` (runtime persistence)

## Preset File Versioning

SLM preset files use **per-file versioning with a suffix** rather than a single mod version number. Each preset file tracks its own change history independently — e.g., `1.0.0apartments` and `1.0.0kp` in the changelog are per-preset release tags, not standard version bumps for the whole mod.

This means individual presets can be updated and released without bumping the core SLM version. **Do not normalise these suffixed tags to semver.** They are intentional.

## Mod-Specific Constraints

- SLM String format is versioned: V2 is 70-75% smaller than V1 (Base64 compressed).
- Import types: SLM String, SLM Preset (text files), AMM String (JSON), AMM Bulk (directory scan).
- User-edited presets are protected from auto-sync overwrite (smart conflict resolution).
- Deduplication threshold: 0.5m.
- Related preset mods: `JNVE_SLM_AOI_Preset`, `KonpekiPlaza_SLM_Preset`, `SLM_Appartment_Preset`.

## Active Development Notes

- Preset author workflow and auto-sync mechanism are the most complex parts.
- AMM import compatibility must be maintained.
