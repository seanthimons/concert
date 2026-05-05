# Phase 43: WQX Dictionary - Context

**Gathered:** 2026-05-05
**Status:** Ready for planning

<domain>
## Phase Boundary

The WQX lookup dictionary is available locally and stays current. This phase delivers the data layer only — no matching logic, no pipeline integration. Those belong to Phases 44 and 45.

</domain>

<decisions>
## Implementation Decisions

### RDS Structure
- **D-01:** Single tibble with a `type` column (values: canonical, synonym, standardize, retired). Canonical rows have `name == canonical_name`. Aliases map `name` → `canonical_name` with their alias type.

### Auto-Download Behavior
- **D-02:** Follow the existing `load_or_fetch_reference()` pattern (lazy, on first WQX function call). The RDS ships pre-built in `inst/extdata/reference_cache/`. No `.onLoad()` eager download.

### Source URL & Freshness
- **D-03:** Hardcode EPA download URLs directly in the function. `refresh_wqx_cache()` re-downloads and rebuilds silently with no staleness warnings.
- **D-04:** Source URLs (zipped CSVs):
  - Characteristics: `https://cdx.epa.gov/wqx/download/DomainValues/Characteristic_CSV.zip`
  - Aliases: `https://cdx.epa.gov/wqx/download/DomainValues/CharacteristicAlias_CSV.zip`

### Data Cleaning at Build Time
- **D-05:** Moderate cleanup — retain columns useful for matching and future context:
  - From Characteristic.csv: `name` (trimmed), `cas_number`, `group_name`, `description`, `type = "canonical"`
  - From Characteristic Alias.csv: `name` (= Alias Name, trimmed), `canonical_name` (= Characteristic Name, trimmed), `description`, `type` (extracted from Alias Type Name: synonym/standardize/retired)
  - Drop administrative columns: Domain, Unique Identifier, SRS ID, Sample Fraction Required, Analytical Method Required, Method Speciation Required, Pick List, Domain Value Status, Last Change Date

### Claude's Discretion
- Column naming beyond the above (e.g., whether to keep `cas_number` as-is or rename)
- Zip extraction temp directory handling
- Whether to use `utils::download.file()` or `curl` for the download
- Error messaging when download fails (offline/EPA down)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Cache Pattern
- `R/cleaning_reference.R` — `load_or_fetch_reference()` generic cache function (line 21); all `load_*()` loaders follow this pattern
- `R/curate_headless.R` lines 110-111 — How headless pipeline resolves cache_dir via `system.file()`

### Requirements
- `.planning/REQUIREMENTS.md` §Dictionary — DICT-01, DICT-02, DICT-03 requirements

### Package Infrastructure
- `R/zzz.R` — `.onLoad()` hook (currently only registers units; do NOT add WQX loading here per D-02)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `load_or_fetch_reference(cache_path, fetch_fn, name)`: Generic cache-or-build function — use directly for the WQX loader
- `inst/extdata/reference_cache/`: Established directory for all RDS reference data (10 files already)
- `load_all_reference_lists(cache_dir)`: Central loader — WQX dictionary may be added here or kept separate (Phase 45 decision)

### Established Patterns
- All reference loaders accept `cache_dir` param and construct `cache_path` internally
- `fetch_fn` is a closure that generates data when cache is missing
- `system.file("extdata", "reference_cache", package = "chemreg")` resolves the installed path
- Pre-built RDS files ship with the package in `inst/extdata/reference_cache/`

### Integration Points
- New `load_wqx_dictionary(cache_dir)` function in `R/cleaning_reference.R` (or new `R/wqx_dictionary.R`)
- New `refresh_wqx_cache()` exported function (downloads zips, parses CSVs, builds and saves RDS)
- Phase 44 will call `load_wqx_dictionary()` to get the combined tibble for matching

</code_context>

<specifics>
## Specific Ideas

- EPA CSVs have leading tabs on Name fields — must `trimws()` during build
- Characteristic.csv has ~13,800 canonical names (23K lines with header)
- Characteristic Alias.csv has ~145K lines covering synonym/standardize/retired mappings
- Alias Type Name values need parsing: "WQX SYNONYM REGISTRY (validation)" → "synonym", "STANDARDIZE NAME (Normalized)" → "standardize", "RETIRED NAME" → "retired"
- Both source CSVs are already in the repo root for local testing (not committed to package)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 43-wqx-dictionary*
*Context gathered: 2026-05-05*
