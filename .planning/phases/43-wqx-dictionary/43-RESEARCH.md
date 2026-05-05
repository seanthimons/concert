# Phase 43: WQX Dictionary - Research

**Researched:** 2026-05-05
**Domain:** R package reference cache, EPA WQX domain values, zip download + CSV parse
**Confidence:** HIGH

## Summary

Phase 43 delivers a local lookup dictionary built from two EPA WQX domain-value CSVs. The work is narrowly scoped: download two zip files, parse the CSVs, build a single combined tibble, save it as an RDS in `inst/extdata/reference_cache/`, and expose two functions — `load_wqx_dictionary()` (lazy loader) and `refresh_wqx_cache()` (explicit re-download). No matching logic, no Shiny integration.

All infrastructure already exists. The `load_or_fetch_reference()` generic handles the cache-or-build pattern identically for all 10 existing reference files. Both EPA URLs are live and return valid zips (verified). The CSV structures are confirmed from the local test copies already in the repo root. The only new work is the fetch function that downloads, unzips, reads, cleans, and joins the two CSVs.

**Primary recommendation:** Add `load_wqx_dictionary()` and `refresh_wqx_cache()` to `R/cleaning_reference.R` following the established pattern. Build the pre-bundled RDS from the local CSVs already in the repo and commit it to `inst/extdata/reference_cache/`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Single tibble with a `type` column (values: canonical, synonym, standardize, retired). Canonical rows have `name == canonical_name`. Aliases map `name` -> `canonical_name` with their alias type.
- **D-02:** Follow the existing `load_or_fetch_reference()` pattern (lazy, on first WQX function call). The RDS ships pre-built in `inst/extdata/reference_cache/`. No `.onLoad()` eager download.
- **D-03:** Hardcode EPA download URLs directly in the function. `refresh_wqx_cache()` re-downloads and rebuilds silently with no staleness warnings.
- **D-04:** Source URLs (zipped CSVs):
  - Characteristics: `https://cdx.epa.gov/wqx/download/DomainValues/Characteristic_CSV.zip`
  - Aliases: `https://cdx.epa.gov/wqx/download/DomainValues/CharacteristicAlias_CSV.zip`
- **D-05:** Moderate cleanup — retain columns useful for matching and future context:
  - From Characteristic.csv: `name` (trimmed), `cas_number`, `group_name`, `description`, `type = "canonical"`
  - From Characteristic Alias.csv: `name` (= Alias Name, trimmed), `canonical_name` (= Characteristic Name, trimmed), `description`, `type` (extracted from Alias Type Name: synonym/standardize/retired)
  - Drop administrative columns: Domain, Unique Identifier, SRS ID, Sample Fraction Required, Analytical Method Required, Method Speciation Required, Pick List, Domain Value Status, Last Change Date
- Do NOT add WQX loading to `.onLoad()` (per D-02)

### Claude's Discretion

- Column naming beyond the above (e.g., whether to keep `cas_number` as-is or rename)
- Zip extraction temp directory handling
- Whether to use `utils::download.file()` or `curl` for the download
- Error messaging when download fails (offline/EPA down)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DICT-01 | Package downloads WQX Characteristic.csv and Characteristic Alias.csv from EPA and caches as combined lookup RDS in `inst/extdata/reference_cache/` | `refresh_wqx_cache()` fetch function downloads both zips, parses CSVs, joins, saves RDS |
| DICT-02 | Package checks for dictionary RDS on first use and downloads/builds if missing | `load_wqx_dictionary()` wraps `load_or_fetch_reference()` — cache-miss triggers fetch automatically |
| DICT-03 | Exported `refresh_wqx_cache()` function re-downloads and rebuilds the lookup RDS | `refresh_wqx_cache()` deletes existing RDS then calls the fetch function, or calls fetch_fn directly with force-write |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| RDS cache storage | Package (inst/extdata) | — | Ships pre-built with package; lazy-downloaded on cache miss |
| Zip download + extraction | R package (fetch_fn) | — | utils::download.file + unzip entirely within R |
| CSV parsing + cleaning | R package (fetch_fn) | — | readr::read_csv, trimws, dplyr join; no external service |
| Lazy load on first call | R package (load_wqx_dictionary) | — | Wraps existing load_or_fetch_reference pattern |
| Explicit cache refresh | R package (refresh_wqx_cache) | — | Exported function; removes old RDS, re-runs fetch |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| readr | (in Imports) | Read CSVs from unzipped files | Auto-strips leading tabs from Name fields; already in DESCRIPTION Imports |
| dplyr | (in Imports) | Select, rename, mutate, bind_rows for tibble construction | Already in DESCRIPTION Imports |
| tibble | (in Imports) | Output tibble type | Already in DESCRIPTION Imports |
| utils | (base R) | `download.file()` for zip fetch; `unzip()` for extraction | No additional dependency |
| fs | (in Imports) | `dir_create()` for cache directory creation | Already used by `load_or_fetch_reference()` |

[VERIFIED: DESCRIPTION Imports, codebase inspection]

### No New Dependencies Required

All packages needed are already in DESCRIPTION Imports. No new packages to add.

## Architecture Patterns

### System Architecture Diagram

```
refresh_wqx_cache() ─────────────────────────────────────────────────────┐
                                                                           │
load_wqx_dictionary(cache_dir) ──► load_or_fetch_reference() ──► [RDS exists?]
                                                                  │         │
                                                               YES│         │NO
                                                                  ▼         ▼
                                                             readRDS()   fetch_fn()
                                                                              │
                                          ┌───────────────────────────────────┤
                                          │                                   │
                                   Download Characteristic_CSV.zip   Download CharacteristicAlias_CSV.zip
                                          │                                   │
                                     unzip → tempdir                    unzip → tempdir
                                          │                                   │
                                   readr::read_csv("Characteristic.csv")  readr::read_csv("Characteristic Alias.csv")
                                          │                                   │
                                   select + rename + mutate            filter(type %in% kept) + select + rename + mutate
                                   type = "canonical"                  type = parse_alias_type(Alias Type Name)
                                          │                                   │
                                          └───────────► dplyr::bind_rows ────┘
                                                               │
                                                        saveRDS() → inst/extdata/reference_cache/wqx_dictionary.rds
                                                               │
                                                        return tibble
```

### Recommended Project Structure

No new directories needed. New code goes in `R/cleaning_reference.R` (or a new `R/wqx_dictionary.R` file — either is valid; `cleaning_reference.R` is consistent with the existing pattern).

```
R/
├── cleaning_reference.R   # Add load_wqx_dictionary() + refresh_wqx_cache() here
inst/extdata/reference_cache/
└── wqx_dictionary.rds     # Pre-built; committed to package
```

### Pattern 1: Lazy Loader (established pattern)

**What:** `load_wqx_dictionary()` follows the identical structure of every other loader in `cleaning_reference.R`.

**When to use:** Phase 44 matching engine calls this to get the combined tibble.

```r
# Source: R/cleaning_reference.R (existing pattern)
load_wqx_dictionary <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "wqx_dictionary.rds")
  load_or_fetch_reference(cache_path, .build_wqx_dictionary, "WQX dictionary")
}
```

### Pattern 2: fetch_fn as named internal function

**What:** The fetch closure is defined as a named internal function (`.build_wqx_dictionary`) rather than an anonymous closure. This lets `refresh_wqx_cache()` call the same build logic without duplicating it.

```r
# Internal — not exported
.build_wqx_dictionary <- function() {
  char_url  <- "https://cdx.epa.gov/wqx/download/DomainValues/Characteristic_CSV.zip"
  alias_url <- "https://cdx.epa.gov/wqx/download/DomainValues/CharacteristicAlias_CSV.zip"
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # Download + extract both zips
  char_zip  <- file.path(tmp_dir, "char.zip")
  alias_zip <- file.path(tmp_dir, "alias.zip")
  utils::download.file(char_url,  destfile = char_zip,  mode = "wb", quiet = TRUE)
  utils::download.file(alias_url, destfile = alias_zip, mode = "wb", quiet = TRUE)
  utils::unzip(char_zip,  exdir = tmp_dir)
  utils::unzip(alias_zip, exdir = tmp_dir)

  # Parse Characteristic.csv → canonical rows
  char_tbl <- readr::read_csv(file.path(tmp_dir, "Characteristic.csv"),
                               show_col_types = FALSE) |>
    dplyr::select(
      name         = Name,
      cas_number   = `CAS Number`,
      group_name   = `Group Name`,
      description  = Description
    ) |>
    dplyr::mutate(
      name          = trimws(name),
      canonical_name = name,
      type          = "canonical"
    )

  # Parse Characteristic Alias.csv → alias rows (3 types only)
  kept_alias_types <- c(
    "WQX SYNONYM REGISTRY (validation)",
    "STANDARDIZE NAME (Normalized)",
    "RETIRED NAME"
  )
  type_map <- c(
    "WQX SYNONYM REGISTRY (validation)" = "synonym",
    "STANDARDIZE NAME (Normalized)"     = "standardize",
    "RETIRED NAME"                      = "retired"
  )
  alias_tbl <- readr::read_csv(file.path(tmp_dir, "Characteristic Alias.csv"),
                                show_col_types = FALSE) |>
    dplyr::filter(`Alias Type Name` %in% kept_alias_types) |>
    dplyr::select(
      name           = `Alias Name`,
      canonical_name = `Characteristic Name`,
      description    = Description,
      alias_type     = `Alias Type Name`
    ) |>
    dplyr::mutate(
      name           = trimws(name),
      canonical_name = trimws(canonical_name),
      type           = dplyr::recode(alias_type, !!!type_map),
      cas_number     = NA_character_,
      group_name     = NA_character_
    ) |>
    dplyr::select(-alias_type)

  dplyr::bind_rows(char_tbl, alias_tbl)
}
```

### Pattern 3: refresh_wqx_cache()

**What:** Exported function that forces a re-download regardless of cache state.

```r
#' @export
refresh_wqx_cache <- function(cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
  }
  cache_path <- file.path(cache_dir, "wqx_dictionary.rds")
  if (file.exists(cache_path)) unlink(cache_path)

  result <- .build_wqx_dictionary()
  fs::dir_create(dirname(cache_path), recurse = TRUE)
  saveRDS(result, cache_path, compress = FALSE)
  message(sprintf("WQX dictionary refreshed: %d rows written to %s", nrow(result), cache_path))
  invisible(result)
}
```

### Pattern 4: Pre-built RDS via script

**What:** The combined RDS must be built once and committed to `inst/extdata/reference_cache/wqx_dictionary.rds` so it ships with the package. Use the local CSVs already in the repo root rather than downloading from EPA during the build step.

```r
# One-time build script (run from package root, not exported)
char_local  <- readr::read_csv("Characteristic.csv", show_col_types = FALSE)
alias_local <- readr::read_csv("Characteristic Alias.csv", show_col_types = FALSE)
# ... same cleaning logic as .build_wqx_dictionary() ...
saveRDS(result, "inst/extdata/reference_cache/wqx_dictionary.rds", compress = FALSE)
```

### Anti-Patterns to Avoid

- **Putting the download in `.onLoad()`:** Explicitly forbidden by D-02. Eager download on package load blocks startup and breaks offline use.
- **Anonymous closure for fetch_fn:** Makes `refresh_wqx_cache()` duplicate the build logic. Use a named internal function instead.
- **Reading CSVs with `read.csv()` base R:** `readr::read_csv()` is already in Imports and automatically handles the leading-tab issue in Name fields. `read.csv()` leaves tabs in place and requires explicit `trimws()`.
- **Using `compress = TRUE` for the RDS:** All 10 existing RDS files use `compress = FALSE` (matching the established `saveRDS()` call in `load_or_fetch_reference()`). Deviate only if RDS size becomes a problem.
- **Including all 16 Alias Type Name values:** Only 3 are wanted (synonym/standardize/retired). Including NWIS_PARM_CODE, CAS_NUMBER, MOLECULAR_WEIGHT etc. inflates the tibble with non-name-string rows that will confuse the matching engine.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cache-or-fetch logic | Custom if/else + saveRDS | `load_or_fetch_reference()` | Already handles dir creation, messages, and the cache hit/miss path |
| CSV tab stripping | Manual `gsub("\t", "", x)` | `readr::read_csv()` | readr trims leading whitespace (including tabs) from quoted fields automatically — verified on both source CSVs |
| Temp directory cleanup | Manual `unlink()` calls | `on.exit(unlink(tmp_dir, recursive = TRUE))` | Guarantees cleanup even on error |

## Common Pitfalls

### Pitfall 1: Leading Tabs in Name Fields

**What goes wrong:** Reading CSVs with `utils::read.csv()` leaves a `\t` prefix on some Name values. The context notes mention "EPA CSVs have leading tabs on Name fields."
**Why it happens:** The EPA CSV export includes a literal tab character before some Name values (2 rows in Characteristic.csv, 152 rows in Alias Name column).
**How to avoid:** Use `readr::read_csv()` — verified to strip all leading tabs in both files. If base `read.csv()` is used, apply `trimws()` to name and canonical_name columns.
**Warning signs:** Canonical name lookups fail for rows where the stored name starts with `\t`.

[VERIFIED: codebase inspection of actual CSVs using R]

### Pitfall 2: Wrong CSV Filename Inside the Alias Zip

**What goes wrong:** Code assumes `"CharacteristicAlias.csv"` but the zip contains `"Characteristic Alias.csv"` (with a space).
**Why it happens:** The zip filename is `CharacteristicAlias_CSV.zip` but the CSV inside has a space: `Characteristic Alias.csv`.
**How to avoid:** Use `unzip(zip_path, list = TRUE)$Name[1]` to discover the actual filename rather than hardcoding it, or hardcode `"Characteristic Alias.csv"` (verified from zip listing).
**Warning signs:** `file.path(tmp_dir, "CharacteristicAlias.csv")` -> `No such file or directory`.

[VERIFIED: actual zip downloaded and listed]

### Pitfall 3: Including All 16 Alias Types

**What goes wrong:** All 145,376 alias rows are included, adding NWIS parameter codes, CAS numbers as "aliases", taxon serial numbers, etc.
**Why it happens:** Forgetting to filter to the 3 wanted types before building the tibble.
**How to avoid:** Filter `Alias Type Name %in% c("WQX SYNONYM REGISTRY (validation)", "STANDARDIZE NAME (Normalized)", "RETIRED NAME")` — reduces from 145,376 to 100,766 rows.
**Warning signs:** Combined tibble has ~168K rows instead of ~124K; type values contain "NWIS PARM CODE" etc.

[VERIFIED: row counts confirmed from actual data inspection]

### Pitfall 4: `refresh_wqx_cache()` Not Having a `cache_dir` Default

**What goes wrong:** User calls `refresh_wqx_cache()` with no arguments from an interactive session. Without a default for `cache_dir`, it errors.
**Why it happens:** The function needs to write to the installed package path.
**How to avoid:** Default `cache_dir = NULL` with fallback to `system.file("extdata", "reference_cache", package = "chemreg")`.

### Pitfall 5: canonical rows missing `canonical_name` column

**What goes wrong:** Canonical rows only have `name`, not `canonical_name`. Phase 44 matching code expects `canonical_name` to always be present.
**Why it happens:** D-01 says "Canonical rows have `name == canonical_name`" but it's easy to omit the column in the canonical tibble.
**How to avoid:** Always set `canonical_name = name` for canonical rows in the `mutate()` step.

## Code Examples

### Confirmed CSV Column Names (from actual files)

**Characteristic.csv** (23,304 data rows):
- `Domain`, `Unique Identifier`, `Name`, `CAS Number`, `SRS ID`, `Sample Fraction Required`, `Analytical Method Required`, `Method Speciation Required`, `Pick List`, `Group Name`, `Domain Value Status`, `Description`, `Comparable Name`, `Last Change Date `

**Characteristic Alias.csv** (145,376 data rows):
- `Domain`, `Unique Identifier`, `Alias Name`, `Description`, `Characteristic Name`, `Alias Type Name`, `Last Change Date `

Note: `Last Change Date` has a trailing space in the actual column name. Not needed per D-05 anyway.

### Combined Tibble Column Layout (D-01 + D-05)

```r
# Final tibble columns — same shape for canonical and alias rows
tibble(
  name           = character(),   # trimmed; for canonical rows this equals canonical_name
  canonical_name = character(),   # trimmed; for canonical rows this equals name
  type           = character(),   # "canonical" | "synonym" | "standardize" | "retired"
  cas_number     = character(),   # from Characteristic.csv; NA for alias rows
  group_name     = character(),   # from Characteristic.csv; NA for alias rows
  description    = character()    # from both sources; may be NA
)
```

### Alias Type Name Mapping (verified from actual data)

```r
# All 16 Alias Type Name values found in file:
# [KEEP] "WQX SYNONYM REGISTRY (validation)"  → type = "synonym"   (75,268 rows)
# [KEEP] "STANDARDIZE NAME (Normalized)"       → type = "standardize" (23,485 rows)
# [KEEP] "RETIRED NAME"                        → type = "retired"  (2,013 rows)
# [drop] "SYSTEMATIC NAME"                     (6,927 rows)
# [drop] "CST.POLLUTANT"                       (491 rows)
# [drop] "STORET CHARACTERISTIC NAME"          (349 rows)
# [drop] "ATTAINS.PARAMETER"                   (1,178 rows)
# [drop] "NWIS PARM CODE"                      (18,875 rows)
# [drop] "STORET PARM CODE"                    (7,170 rows)
# [drop] "CST.STD.POLLUTANT"                   (488 rows)
# [drop] "ITIS TAXON SERIAL NUMBER"            (405 rows)
# [drop] "MOLECULAR WEIGHT"                    (185 rows)
# [drop] "CAS NUMBER"                          (3,399 rows)
# [drop] "EPA ID (SUBSTANCE REGISTRY #)"       (3,678 rows)
# [drop] "AQS PARM CODE"                       (1,460 rows)
# [drop] "TAXON COMMON NAME"                   (5 rows)
```

[VERIFIED: actual Characteristic Alias.csv inspection]

### Expected Combined Tibble Dimensions

- Canonical rows: 23,304
- Alias rows (3 types): 100,766
- Total: ~124,070 rows

[VERIFIED: actual CSV inspection]

### Self-Mapping Aliases Are Normal

46,847 alias rows have `name == canonical_name` after trimming. This is expected — "STANDARDIZE NAME" entries often map a name to itself to confirm it as the canonical spelling. These rows are harmless in the dictionary but Phase 44 should be aware.

[VERIFIED: actual data inspection]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Anonymous closure for fetch_fn | Named internal function `.build_wqx_dictionary` | Phase 43 decision | Lets refresh_wqx_cache() share logic without duplication |

**No deprecated items** — this is new functionality with no migration from old code.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Column names in the EPA CSVs match the local test copies — i.e., EPA has not renamed columns in the live zip | Code Examples | Column selects in fetch_fn would error on download |

**All other claims were verified against actual files or live URLs in this session.**

## Open Questions (RESOLVED)

1. **Where to place the new code: `cleaning_reference.R` vs new `wqx_dictionary.R`**
   - **RESOLVED:** Add to `R/cleaning_reference.R`. All 10 existing reference loaders live there. Plans 43-01 and 43-02 implement this choice. The file grows from ~515 to ~600 lines, which remains manageable.

2. **Whether to add `wqx_dictionary` to `load_all_reference_lists()`**
   - **RESOLVED:** Do NOT add to `load_all_reference_lists()` in Phase 43. CONTEXT.md explicitly marks this as a "Phase 45 decision." Plan 43-01 Task 2 action includes a guard note: "Do NOT add to load_all_reference_lists()."

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| EPA CDX endpoint (Characteristic_CSV.zip) | DICT-01, refresh_wqx_cache | ✓ | 200 OK, 696KB | Use local CSV in repo root for pre-built RDS |
| EPA CDX endpoint (CharacteristicAlias_CSV.zip) | DICT-01, refresh_wqx_cache | ✓ | 200 OK, 2.96MB | Use local CSV in repo root for pre-built RDS |
| readr | CSV parsing | ✓ | In DESCRIPTION Imports | — |
| utils::download.file | Zip download | ✓ | base R | — |
| utils::unzip | Zip extraction | ✓ | base R | — |

[VERIFIED: curl HEAD requests to both URLs; R session inspection]

**Local CSVs for pre-built RDS:** `Characteristic.csv` and `Characteristic Alias.csv` are present in the repo root (not committed to package). Use these to build `wqx_dictionary.rds` without a live EPA download.

## Validation Architecture

**nyquist_validation:** Not set in config.json → treated as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat >= 3.0.0 |
| Config file | `tests/testthat.R` |
| Quick run command | `devtools::test(filter = "wqx")` |
| Full suite command | `devtools::test()` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DICT-01 | `refresh_wqx_cache()` downloads and writes RDS | integration (network) | `devtools::test(filter = "wqx")` | Wave 0 |
| DICT-01 | Combined RDS contains canonical + alias rows with correct columns | unit (mocked) | `devtools::test(filter = "wqx")` | Wave 0 |
| DICT-02 | `load_wqx_dictionary()` returns cached RDS when present | unit | `devtools::test(filter = "wqx")` | Wave 0 |
| DICT-02 | `load_wqx_dictionary()` builds RDS when cache is absent | unit (mocked fetch) | `devtools::test(filter = "wqx")` | Wave 0 |
| DICT-03 | `refresh_wqx_cache()` overwrites existing RDS | unit (mocked fetch) | `devtools::test(filter = "wqx")` | Wave 0 |

**Note on network tests:** Tests for DICT-01 that require live EPA downloads should be wrapped in `testthat::skip_on_ci()` or `skip_if_offline()`. Unit tests for the build logic should use `withr::with_tempdir()` and pre-parsed local data, following the pattern in `test-cleaning-reference.R`.

### Wave 0 Gaps

- [ ] `tests/testthat/test-wqx-dictionary.R` — covers all DICT-0x requirements

### Sampling Rate

- **Per task commit:** `devtools::test(filter = "wqx")`
- **Per wave merge:** `devtools::test()`
- **Phase gate:** Full suite green before `/gsd-verify-work`

## Security Domain

This phase downloads files from a US government endpoint (`cdx.epa.gov`) over HTTPS and writes RDS to package-bundled storage. No user input is processed, no authentication is involved, and no data leaves the machine. ASVS categories V2 (auth), V3 (session), V4 (access control) do not apply. V5 (input validation) applies minimally — the CSV column filter and type mapping are the only points where external data shapes internal state.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes (low risk) | Filter alias rows by known type set; trimws() on name fields |
| V6 Cryptography | no | HTTPS transport; no hand-rolled crypto |

## Sources

### Primary (HIGH confidence)
- `R/cleaning_reference.R` (codebase) — existing `load_or_fetch_reference()` pattern, all loader signatures
- `R/zzz.R` (codebase) — confirmed no WQX loading should be added here
- `Characteristic.csv` and `Characteristic Alias.csv` (repo root local files) — column names, row counts, Alias Type Name values, tab behavior
- Live EPA CDX endpoints — HTTP 200, content-length, zip contents listed

### Secondary (MEDIUM confidence)
- `tests/testthat/test-cleaning-reference.R` — test patterns for reference loader testing
- `DESCRIPTION` — confirmed no new dependencies needed

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already in DESCRIPTION Imports, verified
- Architecture: HIGH — existing pattern is identical; only the fetch_fn is new
- Pitfalls: HIGH — discovered from actual CSV inspection, not assumed
- CSV structure: HIGH — verified from local test copies and live zip listing

**Research date:** 2026-05-05
**Valid until:** 2026-06-05 (EPA CSV schema is stable; URLs confirmed live)
