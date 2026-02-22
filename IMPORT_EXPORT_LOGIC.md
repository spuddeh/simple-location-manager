# Simple Location Manager - Import/Export Logic Flow

**Version:** 1.3.1 (Logic v1.9.9 / Impex v1.2.7)

This document outlines the internal logic used for processing the four distinct types of location imports. Understanding this flow is critical for debugging ID mismatches and conflict resolution.

---

## 1. SLM String (Base64)

*Used for copying/sharing individual locations or small lists via clipboard.*

### Export

1. **Gathering**: Locations are selected based on the user's view (Single, Category, District, or Search Result).
2. **Minification**: `CreatePackage` converts objects to **V2 Minified Format**.
    * **Crucial**: The internal `id` is preserved in the minified data (`min.i`).
3. **Encoding**: JSON -> Base64.

### Import

1. **Decoding**: `ProcessImport` decodes Base64 -> JSON.
2. **Expansion**: V2 data is expanded back to full objects. The `id` is restored.
3. **Duplicate Check**: `ProcessImportDataArray` performs a **strict position check** (0.5m tolerance).
    * **If ID Matches**: It is treated as an **UPDATE** (Not a duplicate/conflict).
    * **If Position Matches (Different ID)**: Skipped as "Duplicate".
4. **Action**: Calls `Logic.ImportLocation(..., preserveId=true)`.
    * **Update**: If ID exists, updates the record.
    * **New**: If ID does not exist, creates a NEW record.
    * **ID Policy**: If `preserveId=true` and the input data has a valid `id`, that ID is used. Otherwise, a random ID is generated.

---

## 2. SLM Preset (File-based)

*Used for automated loading of location packs (e.g., `presets/JNVE_SLM_AOI_Preset.txt`). This runs automatically on session start.*

### Export

* Identical to SLM String Export (V2 Minified with IDs preserved).

### Import (`LoadPresets`)

1. **Scanning**: Iterates through all `.txt` files in `presets/`.
2. **Decoding**: Decodes Base64 -> JSON -> Expands Data.
3. **Matching Logic (Per Location)**:
    The system attempts to match each incoming preset location to an existing database record.

    * **Step A: Check ID Match**
        * Does `pLoc.id` exist in the database?
        * **YES**: `idMatch = true`.
    * **Step B: Check Position Match (Conflict)**
        * *Only runs if Step A failed (`idMatch == false`).*
        * Is there *any* existing location within 0.5m?
        * **YES**: `posMatch = true`, `conflictLoc = existing`.

4. **Decision Tree**:

    * **Condition: ID Match (A)**
        * **Check Protection**: Does `existing.sourceType` contain `(Edited)`?
            * **YES (Edited)**: SKIP. Log: `[SKIP] Protected User-Edited Location`.
            * **NO (Synced)**: UPDATE. Syncs name, description, category, and position. Log: `Synced Preset Location`.

    * **Condition: Position Match (B) - "Conflict"**
        * **Check Protection**: Does `conflictLoc.sourceType` contain `(Edited)`?
            * **YES (Edited)**: SKIP. Log: `[SKIP] Protected User-Edited Location (Conflict)`.
            * **NO (Broken Link)**: **SELF HEAL**.
                * **Condition**: Only if `conflictLoc.sourceType` is `nil` (Legacy) or contains `Preset`.
                * **Assumption**: The IDs differ, but the position is identical, not edited, and likely a broken link to this preset.
                * **Action**: Updates the *existing* location's ID to match the *Preset* ID.
                * **Log**: `[FIX] Resyncing ID for location...`
                * **Exception**: If `sourceType` is "Manual Input" or "AMM Import", it acts as **SKIP** (Log: `Conflict: Position match`).

    * **Condition: No Match (New)**
        * **Action**: `Logic.ImportLocation(..., preserveId=true)`.
        * **Result**: Creates a NEW location using the **Preset's ID**.
        * **Benefit**: This ensures that even on a fresh install, the database ID matches the preset file, allowing future updates to sync correctly via Step A.

---

## 3. AMM String (JSON)

*Used for pasting raw AMM JSON data from the clipboard.*

### Import

1. **Detection**: `ProcessImport` detects `{` prefix.
2. **Parsing**: Maps AMM JSON fields to SLM structure.
3. **Duplicate Check**: `ProcessImportDataArray` checks strict position.
    * AMM data has **NO IDs**.
    * **If Position Matches**: SKIP (Duplicate).
4. **Action**: Calls `Logic.ImportLocation(..., preserveId=true)`.
    * Since input data has no `id`, `Logic` generates a random NEW ID.

---

## 4. AMM Bulk (Directory)

*Used for scanning `AMM/User/Locations` to import saved AMM spots.*

### Import

1. **Scanning**: Scans directory for `.json` files.
2. **Parsing**: parses valid AMM files.
3. **Duplicate Check**: `Impex.IsExactDuplicate`.
    * If Position matches ANY existing location -> SKIP.
4. **Action**: Calls `Logic.ImportLocation(..., preserveId=false)`.
    * Generates a random NEW ID.
    * Sets Source to "AMM Bulk Import" + Filename.
