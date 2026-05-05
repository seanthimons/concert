---
phase: 43-wqx-dictionary
verified: 2026-05-05T17:05:55Z
status: passed
score: 7/7
overrides_applied: 0
re_verification: false
---

# Phase 43: WQX Dictionary Verification Report

**Phase Goal:** The WQX lookup dictionary is available locally and stays current
**Verified:** 2026-05-05T17:05:55Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `refresh_wqx_cache()` downloads Characteristic.csv and Characteristic Alias.csv from EPA and writes a combined RDS to `inst/extdata/reference_cache/` | VERIFIED | `refresh_wqx_cache` in `R/cleaning_reference.R` lines 614-628: deletes existing RDS, calls `.build_wqx_dictionary()` (which downloads both zips from `cdx.epa.gov`), saves with `compress = FALSE` to `cache_path`. |
| 2 | Calling a WQX function for the first time automatically downloads and builds the RDS if it is absent | VERIFIED | `load_wqx_dictionary` delegates to `load_or_fetch_reference(cache_path, .build_wqx_dictionary, "WQX dictionary")`. On cache-miss, `load_or_fetch_reference` calls the fetch function and saves the result. Pre-built RDS ships in `inst/extdata/reference_cache/wqx_dictionary.rds` (20 MB) so network is only needed when rebuilding. |
| 3 | The combined RDS contains both canonical characteristic names and alias-to-canonical mappings ready for lookup | VERIFIED | RDS confirmed via Rscript: 124,070 rows, 6 columns (`name, canonical_name, type, cas_number, group_name, description`), types = `canonical, retired, standardize, synonym`. Canonical rows: 23,304 with `name == canonical_name`. Alias rows: 100,766 with `cas_number = NA`. |
| 4 | `load_wqx_dictionary()` returns cached tibble when RDS exists (no network call) | VERIFIED | `load_or_fetch_reference` short-circuits via `file.exists(cache_path)` returning `readRDS(cache_path)`. Confirmed by cache-hit unit test with `local_mocked_bindings` asserting `.build_wqx_dictionary` was NOT called. |
| 5 | `load_wqx_dictionary()` triggers `.build_wqx_dictionary` when RDS is absent and caches result | VERIFIED | Cache-miss unit test passes: tempdir with no RDS, mocked `.build_wqx_dictionary`, call to `load_wqx_dictionary` produces `wqx_dictionary.rds` on disk. |
| 6 | `refresh_wqx_cache()` deletes existing RDS and rebuilds from EPA download | VERIFIED | Overwrite unit test passes: old RDS pre-created, mock `.build_wqx_dictionary` returns new tibble, `refresh_wqx_cache` writes new content; old data confirmed gone. |
| 7 | `.build_wqx_dictionary()` returns tibble with correct 6-column schema | VERIFIED | Pre-built RDS structure test passes without skip (RDS found at `inst/extdata/reference_cache/`). Schema confirmed: `expect_named` with all 6 columns, type invariants, canonical `name == canonical_name`, alias `cas_number = NA`. |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tests/testthat/test-wqx-dictionary.R` | Unit tests for all DICT requirements, min 80 lines | VERIFIED | 122 lines, 4 `test_that` blocks covering cache-hit, cache-miss, refresh overwrite, and pre-built RDS structure. Contains `library(withr)` on line 4. |
| `R/cleaning_reference.R` | `load_wqx_dictionary`, `.build_wqx_dictionary`, `refresh_wqx_cache` functions | VERIFIED | All three functions present at lines 519-628. `.build_wqx_dictionary` is internal (no `@export`). Both public functions have `#' @export` tags. `"Characteristic Alias.csv"` with space on line 567. `compress = FALSE` on line 625. |
| `inst/extdata/reference_cache/wqx_dictionary.rds` | Pre-built WQX dictionary tibble shipped with package | VERIFIED | File exists, 20 MB (20,480,000+ bytes). Contains 124,070-row tibble with correct 6-column schema. |
| `scripts/build_wqx_dictionary.R` | Reproducible build script from local CSVs, min 40 lines | VERIFIED | 86 lines. Uses `here::here()`, reads `Characteristic.csv` and `"Characteristic Alias.csv"` from repo root, applies identical cleaning logic to `.build_wqx_dictionary()`, enforces D-01 column order, includes `stopifnot()` sanity checks, writes with `compress = FALSE`. |
| `NAMESPACE` | Exports `load_wqx_dictionary` and `refresh_wqx_cache`; does NOT export `.build_wqx_dictionary` | VERIFIED | Line 49: `export(load_wqx_dictionary)`. Line 81: `export(refresh_wqx_cache)`. No `export(.build_wqx_dictionary)` entry present. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `R/cleaning_reference.R` | `load_or_fetch_reference` | `load_wqx_dictionary` calls `load_or_fetch_reference(cache_path, .build_wqx_dictionary, "WQX dictionary")` | VERIFIED | Exact call confirmed at line 602. Pattern match: `load_or_fetch_reference(cache_path, .build_wqx_dictionary`. |
| `R/cleaning_reference.R` | `inst/extdata/reference_cache/wqx_dictionary.rds` | `refresh_wqx_cache` writes to `cache_dir/wqx_dictionary.rds` | VERIFIED | `wqx_dictionary.rds` string found at lines 601 and 618 in path assembly. `saveRDS` call at line 625 writes to `cache_path`. Pre-built artifact confirmed at `inst/extdata/reference_cache/wqx_dictionary.rds`. |
| `scripts/build_wqx_dictionary.R` | `inst/extdata/reference_cache/wqx_dictionary.rds` | Script reads local CSVs and writes RDS via `cache_path` variable | VERIFIED | `cache_path <- file.path(CHEMREG_ROOT, "inst", "extdata", "reference_cache", "wqx_dictionary.rds")` at line 83; `saveRDS(result, cache_path, compress = FALSE)` at line 85. |
| `NAMESPACE` | `R/cleaning_reference.R` | roxygen2 generates exports from `@export` tags | VERIFIED | `export(load_wqx_dictionary)` at NAMESPACE line 49; `export(refresh_wqx_cache)` at NAMESPACE line 81. Consistent with `#' @export` tags in source. |

### Data-Flow Trace (Level 4)

Not applicable — this phase delivers a data-loading library function, not a UI component or page rendering dynamic data. The tibble returned by `load_wqx_dictionary()` is the data source consumed by Phase 44.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| RDS loads as valid tibble with correct schema | `Rscript verify_rds.R` (via temp file) | rows=124070, cols=6, types=canonical/retired/standardize/synonym, canonical name==canonical_name TRUE, alias cas_number NA TRUE | PASS |
| `load_wqx_dictionary` exported in NAMESPACE | `grep export(load_wqx_dictionary) NAMESPACE` | Line 49 match | PASS |
| `refresh_wqx_cache` exported in NAMESPACE | `grep export(refresh_wqx_cache) NAMESPACE` | Line 81 match | PASS |
| `.build_wqx_dictionary` not exported | `grep .build_wqx_dictionary NAMESPACE` | No match | PASS |
| RDS file > 1 MB | `ls -lh wqx_dictionary.rds` | 20 MB | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DICT-01 | 43-01, 43-02 | Package downloads Characteristic.csv and Characteristic Alias.csv from EPA and caches as combined lookup RDS in `inst/extdata/reference_cache/` | SATISFIED | `.build_wqx_dictionary()` downloads both zips from `cdx.epa.gov`, parses CSVs, returns combined 124,070-row tibble. `load_or_fetch_reference` saves to `wqx_dictionary.rds` in cache dir. Pre-built artifact ships in `inst/extdata/reference_cache/`. |
| DICT-02 | 43-01, 43-02 | Package checks for dictionary RDS on first use and downloads/builds if missing | SATISFIED | `load_wqx_dictionary(cache_dir)` uses `load_or_fetch_reference` which checks `file.exists(cache_path)` on every call; on miss, triggers `.build_wqx_dictionary()` and saves. Pre-built RDS ships so users get immediate data; `.build_wqx_dictionary()` fires on miss only. `zzz.R` NOT modified — D-02's no-eager-loading constraint honored. |
| DICT-03 | 43-01, 43-02 | Exported `refresh_wqx_cache()` function re-downloads and rebuilds the lookup RDS | SATISFIED | `refresh_wqx_cache(cache_dir = NULL)` exported in NAMESPACE (line 81). Deletes existing RDS via `unlink`, calls `.build_wqx_dictionary()`, saves new RDS with `compress = FALSE`. Unit test confirms old data replaced. |

All three DICT requirements accounted for. No orphaned requirements — REQUIREMENTS.md maps only DICT-01, DICT-02, DICT-03 to Phase 43.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `R/cleaning_reference.R` | 68 | `"placeholder"` string literal | Info | This is in the stop-words list for chemical name cleaning — a domain vocabulary entry, not a code stub. Not a concern. |

No blockers. No stubs. No hardcoded-empty returns. No TODO/FIXME markers in phase-43 files.

### Human Verification Required

None. All must-haves are verifiable programmatically. The only behavior requiring network (EPA download via `.build_wqx_dictionary`) is not triggered during normal use because the pre-built RDS ships with the package and is verified via Rscript read-back.

### Gaps Summary

No gaps. All 7 observable truths pass verification at all levels (existence, substance, wiring). The pre-built RDS is confirmed with correct row count, schema, and data invariants. Both exported functions appear in NAMESPACE. The build script is documented, reproducible, and >= 40 lines. Unit tests cover cache-hit, cache-miss, refresh overwrite, and pre-built RDS structure.

**Pre-existing test failures** in `test-cleaning-reference.R` and `test-reference-provenance.R` (stale key-count assertions from Phases 37-41) are confirmed out-of-scope: these tests have no WQX references and were failing before any Phase 43 changes (confirmed at base commit f6e1995).

---

_Verified: 2026-05-05T17:05:55Z_
_Verifier: Claude (gsd-verifier)_
