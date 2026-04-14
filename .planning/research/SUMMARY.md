# Project Research Summary

**Project:** ChemReg v1.9 — Number and Unit Coercion Harmonization
**Domain:** R/Shiny regulatory/benchmark data curation — numeric parsing, unit harmonization, ToxVal schema output
**Researched:** 2026-04-14
**Confidence:** HIGH

## Executive Summary

ChemReg v1.9 extends a mature, well-modularized R package (8 Shiny modules, 953 passing tests, `curate_headless()` scripting API) from compound-identity curation to full regulatory/benchmark data curation. The new capability is a post-curation pipeline: parse messy numeric result strings, harmonize source units to a controlled vocabulary, map the cleaned data to ToxValDB's 56-column schema, and export as parquet/CSV for database integration. A complete, production-tested reference implementation already exists in `curation/epa/sswqs/sswqs_curation.R` — ChemReg v1.9 is the Shiny-wrapped, generalized, audit-trailed version of that script.

The recommended approach is pure-R-first, UI-second: build and test all four pipeline functions (`numeric_parser`, `unit_harmonizer`, `harmonize_pipeline`, `toxval_mapper`) with no Shiny dependencies before adding any UI. The existing pipeline is strictly read-only from v1.9's perspective — harmonization writes to a new `data_store$harmonize_results` store and never mutates existing data_store fields. This separation means the 953-test regression surface is untouched during development and the new code can be tested end-to-end in headless scripts before the Shiny module exists.

The key risks are invisible data loss and silent type corruption: Fortran-style exponent failures, range-splitting that destroys negative values, unit case-sensitivity collisions (M vs m vs mL vs ML), and bare `NA` producing logical-typed parquet columns that DuckDB rejects at load time. All six critical pitfalls have prevention patterns confirmed in production code from sswqs_curation.R and ecotox_build.R. The build plan accounts for each: full normalization before parsing, case-sensitive unit lookup with case-insensitive fallback, typed `NA_character_`/`NA_real_` throughout, and a round-trip schema-assertion test before any parquet export is considered complete.

---

## Key Findings

### Recommended Stack

No framework changes are required. Two packages need to be added to `DESCRIPTION`: `arrow` (parquet export with explicit schema control — DuckDB requires exact type matching that rio's arrow delegation cannot guarantee) and `lubridate` (date parsing for `effective_date` → `year` ToxVal columns). Both are already installed on this machine (arrow 21.0.0.1, lubridate 1.9.4). The `units` CRAN package was explicitly evaluated and rejected — it does not know regulatory units (`pCi/L`, `NTU`, `count/100mL`, `standard units` for pH). The ComptoxR ECOTOX tribble (~200-row unit lookup table, `ecotox_build.R` lines 271-467) is the correct seed, extended with regulatory-specific rows from sswqs_curation.R.

Two static data files must be created: `inst/extdata/unit_conversion.rds` (the ECOTOX unit tribble plus regulatory extensions) and `inst/extdata/toxval_schema.rds` (a zero-row typed tibble encoding the 56-column ToxVal schema for validation). Four new R source files are needed: `R/numeric_parser.R`, `R/unit_harmonizer.R`, `R/harmonize_pipeline.R`, `R/toxval_mapper.R`.

**Core technologies:**
- `arrow` 21.0.0.1: `write_parquet()` with explicit schema — required for DuckDB COPY INTO compatibility; move to `Suggests` with `requireNamespace()` fallback to CSV (50MB package with system library dep)
- `lubridate` 1.9.4: date parsing for effective_date / year fields in ToxVal schema
- `stringr` + `stringi` (existing): full normalization chain — unicode micro-symbol, Fortran exponents, space removal, x10^ notation; patterns confirmed in sswqs_curation.R lines 777-801
- `dplyr` (existing): `case_when()` dispatch, `left_join()` against unit lookup table
- `purrr::safely()` (existing): error isolation per-row in parser functions

### Expected Features

**Must have (table stakes) — pipeline cannot produce valid ToxVal output without these:**
- Narrative result filter — exclude non-parsable text before numeric pipeline; preserve `removed_reason` audit column, never silently drop rows
- Result string normalization — commas in numbers, Fortran exponents (`4.56+02`), x10^ notation, space-before-exponent (full sswqs_curation.R pattern at lines 779-784)
- Qualifier extraction (`<`, `>`, `<=`, `>=`, `~`) — must happen BEFORE range splitting; qualifier ambiguity over range endpoints is unresolvable if order is reversed
- Range splitting — `"5.6-7.8"` → two rows; requires stable `.id` column assigned before row expansion and a numeric pre-guard (`num_bool`) to protect negative values and exponents
- Unit string normalization — micro-symbol variants (`µ`, `u`), latin-ascii via `stri_trans_general`, case-sensitive-only where scientifically meaningful, spacing around "per" → "/"
- Unit harmonization lookup — case-sensitive match first, ComptoxR ECOTOX table extended with regulatory units from sswqs_curation.R; compound unit two-tier decomposition
- Unit conversion arithmetic — `parsed_value * multiplier`; store `conversion_factor` in audit trail
- Extended column tagging — add Result, Unit, Qualifier, Duration, DurationUnit, Species, ExposureRoute to selectInput; backward-compatible with existing Name/CASRN/Other tags
- ToxVal schema transmutation — 56-column output with `*_original` audit columns for all harmonized fields; typed NA for all unmappable columns
- Export to parquet/CSV — arrow with explicit schema assertion before write, CSV fallback when arrow unavailable

**Should have (differentiators for real curation workflow):**
- User-editable unit harmonization table — reference list pattern matching v1.3 stop word editors; re-run harmonization on save
- Narrative filter review UI — show excluded rows with reason, allow curator confirmation before advancing
- One-off corrections table — user-editable `(pattern, replacement)` tibble for source-specific malformed values like `6.90E+0.1 → 6.90E+01`
- Harmonization audit trail — `orig_result`, `cleaned_unit`, `harmonized_unit`, `conversion_factor` per row
- Pre-export QC dashboard — value boxes: rows with parsed numeric, rows with harmonized unit, rows with dtxsid, rows with NA toxval_numeric
- `curate_headless()` extension — `harmonize=TRUE` param (default FALSE for backward compat) for scripted batch processing
- Range midpoint toggle — user choice: low/high/mid vs low/high only vs midpoint only

**Defer to v2+:**
- Protection code / exposure classification decoder (generalizing sswqs 55-row code lookup to user-uploadable table) — high complexity, not blocking for initial ToxVal output
- Automatic unit inference from column names — anti-feature per research; produces untracked wrong conversions
- Bidirectional unit conversion — no downstream use case; introduces floating-point drift

### Architecture Approach

v1.9 is a clean post-curation extension. The new pipeline activates after `run_curation_pipeline()` completes and `resolution_state` is populated. `resolution_state` is read-only from v1.9's perspective — harmonization produces a separate `data_store$harmonize_results` tibble and never mutates existing fields. Three new `data_store` fields are added (`harmonize_results`, `harmonize_audit`, `toxval_output`) and the existing `reset_all_downstream()` function is extended to null them on re-upload, tag change, or re-run curation. No existing observers, modules, or pipeline functions are structurally modified.

**Major components:**
1. `R/numeric_parser.R` — normalization chain → qualifier extraction → `as.numeric()`; returns structured list with numeric_value, qualifier, range bounds, parse_flag
2. `R/unit_harmonizer.R` — case-sensitive lookup first, case-insensitive fallback, compound unit decomposition; returns canonical_unit, unit_class, unit_flag
3. `R/harmonize_pipeline.R` — dispatches parsers by column tag type; assembles harmonized_data + audit_trail + summary; never receives Name/CASRN/Other columns
4. `R/toxval_mapper.R` — `map_to_toxval_schema()` transmutes to 56-column schema with typed NA; `export_toxval()` writes parquet via arrow with schema assertion
5. `R/mod_harmonize.R` — new Shiny module; value boxes, Run Harmonization button, unmatched-units review; follows mod_run_curation.R pattern exactly
6. `R/mod_tag_columns.R` (modified) — adds 7 new tag choices to selectInput only; tag storage format unchanged
7. `inst/app/app.R` (modified) — 4 new data_store fields, cascade reset extension, Harmonize tab nav_panel registration, on_curation_complete callback extension

**Data flow (v1.9 extension only):**
```
resolution_state (read-only after curation)
  → run_harmonize_pipeline(df, column_tags, unit_map)
  → data_store$harmonize_results + data_store$harmonize_audit
  → map_to_toxval_schema(harmonize_results, column_tags, source_metadata)
  → data_store$toxval_output
  → export_toxval(toxval_output, path, format) → parquet or CSV
  → build_export_sheets() adds Sheet 8 (ToxVal Output) to existing Excel
```

### Critical Pitfalls

1. **Fortran exponents silently produce NA** — Apply the full normalization chain (whitespace removal, `x10^` → `e`, Fortran-exponent regex `(?<=[0-9])(?<!e)([+-])(?=0\d(?!\d))`) BEFORE `as.numeric()`. Surface parse-failure count in the UI before user can advance past parsing. Regression test vector: `"4.56+02"`, `"6.90E+0.1"`, `"5.0 e-9"`, `"5x10^-9"`.

2. **Range splitting destroys negative values and exponents** — The `num_bool` guard (split only if `as.numeric()` returned NA) is safe only AFTER Pitfall 1 normalization has run. Order is mandatory: normalize → numeric-guard → range-split. After splitting, re-validate each fragment with `as.numeric()`. Test: `"-0.5"`, `"4.56e-02"`, `"6.5-8.5"`.

3. **Unit case-sensitivity collision (M vs m vs mL vs ML)** — Global `tolower()` before unit lookup collapses M (molar, 1 mol/L) into m (meter), a potential 1e6 conversion error. Apply only micro-symbol normalization (`µ`/`\u03BC` → `u`) before lookup. Case-sensitive match first; case-insensitive fallback flagged LOW confidence. Test: `"M"`, `"mL"`, `"ML"`, `"m"`, `"MBq"`.

4. **ToxVal NA type mismatch causes DuckDB parquet load failure** — Arrow infers logical type for all-NA columns. DuckDB rejects logical for character schema columns. Use `NA_character_`, `NA_real_`, `NA_integer_` everywhere — never bare `NA`. After export, read the parquet back with `arrow::read_parquet()` and assert all 56 column types match the schema manifest. This must be a test, not a code-review check.

5. **`_original` audit columns contaminated if cleaning runs before capture** — Capture `result_original = result` as the absolute first mutation step, before any transformation. Only BOM stripping and invisible-whitespace normalization may precede the capture; these are encoding artifacts, not content. All substantive transforms (qualifier extraction, comma removal, range splitting) operate on a working-copy column only.

6. **Chemical name cleaning pipeline must not touch numeric columns** — The existing `cleaning_pipeline.R` runs parenthetical stripping and unicode cleaning on Name-tagged columns. These would destroy `"(95% CI: 1.2-3.4)"` and subscript digits in result values. Pipeline dispatch must be by column tag type only — never "all columns". New Result/Unit/Duration tags must be explicitly excluded from the cleaning pipeline dispatch.

---

## Implications for Roadmap

The dependency chain in FEATURES.md and the explicit build-order specification in ARCHITECTURE.md (Phases A and B) yield 7 natural phases: 4 pure-R phases followed by 3 UI/integration/export phases.

### Phase 1: Static Data Foundations
**Rationale:** All downstream components depend on the unit lookup table and ToxVal schema manifest existing before any code is written. Building these first means every subsequent phase has real, typed data to test against — not a placeholder that changes later.
**Delivers:** `inst/extdata/unit_conversion.rds` (ECOTOX tribble + regulatory extensions), `inst/extdata/toxval_schema.rds` (56-column typed zero-row manifest), `load_unit_map()` loader in `cleaning_reference.R`
**Addresses:** Unit harmonization lookup (table stakes prerequisite); ToxVal schema type manifest (prevents Pitfall 4)
**Avoids:** Building parsers against a placeholder that drifts during development

### Phase 2: Numeric Result Parser
**Rationale:** The numeric parser is the critical-path dependency — range splitting, qualifier handling, and the full harmonization pipeline all depend on it. Building and testing it as a pure-R function with no Shiny dependency ensures correctness before any UI is added.
**Delivers:** `R/numeric_parser.R` with `parse_numeric_result()`, `extract_qualifier()`, `normalize_numeric_string()` + full testthat suite
**Addresses:** Narrative result filter, result string normalization, qualifier extraction, range splitting (all table stakes)
**Avoids:** Pitfalls 1, 2, 5, 6, 7, 8 — all numeric parsing pitfalls are addressed here or by the order constraint this phase establishes

### Phase 3: Unit Harmonization Engine
**Rationale:** Depends on Phase 1 (unit table). Purely functional, independently testable. Must be correct and case-safe before being composed into the orchestrator.
**Delivers:** `R/unit_harmonizer.R` with `harmonize_unit()`, `normalize_unit_string()` + testthat suite covering case-sensitive, case-insensitive, and compound unit cases
**Addresses:** Unit string normalization, unit harmonization lookup, unit conversion arithmetic (all table stakes)
**Avoids:** Pitfalls 3, 4 — case-sensitivity collision, compound unit lookup miss

### Phase 4: Harmonization Pipeline Orchestrator and ToxVal Mapper
**Rationale:** Composes Phases 2 and 3. The three-stage unit pipeline (raw → intermediate → ToxVal) must be tested end-to-end in a single phase to prevent double-conversion (Pitfall 10). Integration tests using sswqs data as ground truth validate the full chain before UI work begins.
**Delivers:** `R/harmonize_pipeline.R` (orchestrator), `R/toxval_mapper.R` (schema mapper + parquet export with schema assertion), integration tests
**Addresses:** ToxVal schema transmutation, export to parquet/CSV (table stakes); harmonization audit trail (differentiator)
**Avoids:** Pitfalls 4 (schema type mismatch), 10 (double-conversion), 13 (arrow version type drift)

### Phase 5: Extended Column Tagging
**Rationale:** The first UI phase. Column tagging is the prerequisite for all harmonization UI — users must be able to tag Result/Unit/Duration columns before the Harmonize tab can function. The modification to mod_tag_columns.R is minimal (selectInput choices only), but the cascade reset extension must be implemented here so harmonized output is correctly invalidated when tags change.
**Delivers:** Extended tag type vocabulary in `mod_tag_columns.R`, cascade reset extension in `app.R` (null harmonize_results + harmonize_audit + toxval_output on tag change), smoke test confirming new dropdowns appear
**Addresses:** Extended column tagging (table stakes)
**Avoids:** Pitfall 9 (cascade reset not extended for new tag types), INT-2 (`curate_headless()` tag validation must be updated)

### Phase 6: Harmonize Tab Module and app.R Wiring
**Rationale:** With pure-R functions proven (Phases 2-4) and tagging working (Phase 5), the Harmonize tab is straightforward UI wiring. The module follows mod_run_curation.R exactly: button-triggered pipeline, `withProgress()` wrapper, write to data_store, call on_complete callback to reveal next tab.
**Delivers:** `R/mod_harmonize.R` (UI + server), `app.R` wiring (new data_store fields, tab registration, on_curation_complete extension), working end-to-end Shiny pipeline from upload to harmonized output, narrative filter review UI, pre-export QC dashboard
**Addresses:** Harmonization audit trail, narrative filter review, pre-export QC (differentiators)
**Avoids:** Pitfall INT-1 (cleaning pipeline touching numeric columns — enforced at module dispatch boundary)

### Phase 7: Export Extension and headless
**Rationale:** Terminal step. Implementing export last means it operates on a proven, schema-validated `toxval_output` tibble. The headless extension is additive with `harmonize=FALSE` default preserving the existing contract for all current callers.
**Delivers:** Sheet 8 "ToxVal Output" in existing Excel export, parquet/CSV download handler in `mod_review_results.R` with format radio buttons, `curate_headless()` extension with `harmonize`/`export_toxval`/`source_metadata` params, `DESCRIPTION` updated with `arrow` (Suggests) and `lubridate` (Imports)
**Addresses:** Parquet/CSV export (table stakes), headless harmonization support (differentiator)
**Avoids:** Pitfall INT-3 (ToxVal 56-column output on separate sheet, not merged with existing data sheet), Pitfall 13 (parquet read-back type assertion test)

### Phase Ordering Rationale

- Phases 1-4 are pure-R with no Shiny dependencies. This enables full TDD before any UI work begins and means the 953-test regression surface cannot be disturbed by v1.9 development (INT-4).
- Phase 2 must precede Phase 3 because the `num_bool` output of numeric parsing is the guard condition for range splitting, which is also the input column state that unit harmonization receives.
- Phases 2 and 3 are independent of each other and could run in parallel, but Phase 4 depends on both.
- Phase 5 before Phase 6 because mod_harmonize reads column_tags to dispatch parsers; tags must carry the new vocabulary before the module can be wired.
- Phase 7 last because it is the validation gate for the entire pipeline — a broken export is a diagnostic signal, not a blocker for earlier phases.

### Research Flags

Phases likely needing `/gsd:research-phase` during planning:
- **Phase 4 (ToxVal Mapper):** The exact 56-column schema order for the live `toxval.duckdb` instance should be verified against the actual database before the schema manifest (`toxval_schema.rds`) is built. The sswqs_curation.R transmute block is HIGH-confidence but was written for that specific dataset.
- **Phase 6 (Harmonize Tab — unmatched-unit review):** The UI pattern for allowing curators to add unit mappings inline and re-run harmonization is novel in this codebase. A quick research scan of editable DT + reactive rerun patterns may prevent a Pitfall 2-style cascade explosion.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Static Data):** Direct file-lift from two sources with exact line numbers. No uncertainty.
- **Phase 2 (Numeric Parser):** Complete implementation spec in STACK.md; all regex patterns confirmed in sswqs_curation.R. Pure stringr/base R.
- **Phase 3 (Unit Harmonizer):** ECOTOX tribble is the direct seed; pattern is `left_join()` against static RDS. No uncertainty.
- **Phase 5 (Extended Tagging):** One `selectInput` choices vector change. Established pattern.
- **Phase 7 (Export + headless):** `arrow::write_parquet()` is documented; `curate_headless()` extension is additive with defaults preserving backward compat.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Both new packages confirmed installed and version-checked at runtime. All implementation patterns confirmed at specific line numbers in production code. The `units` package rejection is well-reasoned from domain evidence. |
| Features | HIGH | Primary reference is a complete, production EPA curation script that implements the full feature set end-to-end. Feature boundaries and anti-features are clearly drawn from a working implementation, not speculation. |
| Architecture | HIGH | Based on direct inspection of 9,700+ LOC existing codebase. Module boundaries, data_store fields, cascade reset logic, and integration points are fully documented with specific file and line references. |
| Pitfalls | HIGH (v1.9 section) | All six critical pitfalls have code evidence from production scripts (specific line numbers cited). The v1.9 pitfall section is research-quality; the legacy v1.3 pitfall section is lower confidence but those risks are already mitigated by the existing codebase. |

**Overall confidence:** HIGH

### Gaps to Address

- **Live toxval.duckdb schema verification:** The 56-column schema manifest should be validated against the actual database before Phase 4 begins. The sswqs_curation.R transmute block (lines 1057-1138) is a strong proxy but was written for that dataset. If the live schema differs in column count, order, or types, `toxval_schema.rds` must be rebuilt from the database.

- **Unit table coverage beyond SSWQS:** The ECOTOX tribble covers ecotoxicology units; the sswqs_curation.R extensions cover EPA SSWQS-specific units. Other benchmark datasets (IRIS, PPRTV, OPP, screening levels) likely have additional unit variants. Plan for iterative extension as new datasets are onboarded — the user-editable unit table differentiator exists exactly to handle this.

- **Duration classification lookup source:** Duration appears in three formats (numeric+unit, code, free text). The code-to-canonical mapping (`"A"` → `"acute"`) needs a source table. It does not exist as a static asset yet and must be seeded from target datasets during Phase 2/3.

- **arrow in Suggests vs Imports:** Research recommends `Suggests` with `requireNamespace()` fallback to CSV. If the primary deployment environment always has arrow available, `Imports` is simpler and avoids defensive code. Confirm deployment context before Phase 7.

---

## Sources

### Primary (HIGH confidence)
- `curation/epa/sswqs/sswqs_curation.R` lines 713-1142 — complete production numeric parsing + unit harmonization + ToxVal mapping pipeline (direct code read)
- `ComptoxR/inst/ecotox/ecotox_build.R` lines 271-467 — unit_result tribble; complete unit lookup table seed (direct code read)
- `chemreg/DESCRIPTION` — current Imports baseline (direct file read)
- `chemreg/.planning/PROJECT.md` — architecture constraints and key decisions log (authoritative project document)
- Runtime package verification: `arrow` 21.0.0.1, `lubridate` 1.9.4, `stringi` 1.8.7 confirmed installed

### Secondary (MEDIUM confidence)
- [ToxValDB v9.7.0 schema documentation, EPA FigShare](https://epa.figshare.com/articles/dataset/ToxValDB_v9_1/20394501) — 56-column schema reference
- [Wall et al. 2025, Computational Toxicology](https://www.sciencedirect.com/science/article/abs/pii/S2468111325000258) — ToxValDB design rationale, two-phase curation + standardization model
- [USEPA/toxvaldbstage GitHub](https://github.com/USEPA/toxvaldbstage) — Schema transparency reference
- [baytrends: Processing Censored Water Quality Data (CRAN)](https://cran.r-project.org/web/packages/baytrends/vignettes/Processing_Censored_Data.html) — Censored data conventions for qualifier handling

### Tertiary (LOW confidence)
- Shiny reactivity / progress bar patterns (Mastering Shiny, Engineering Production-Grade Shiny Apps) — relevant for Phase 6 UI pitfalls; well-established patterns, no validation needed for standard cases

---
*Research completed: 2026-04-14*
*Ready for roadmap: yes*
