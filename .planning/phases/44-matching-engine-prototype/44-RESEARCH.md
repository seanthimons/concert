# Phase 44: Matching Engine + Prototype - Research

**Researched:** 2026-05-05
**Domain:** WQX characteristic name matching (exact, alias, fuzzy) in R
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Jaro-Winkler distance via `stringdist` package. New DESCRIPTION Import.
- **D-02:** Fixed threshold `0.85`. Matches below threshold returned as unresolved with nearest candidate + distance shown.
- **D-03:** `stringdist` added to DESCRIPTION Imports.
- **D-04:** `cli` package added to DESCRIPTION Imports.
- **D-05:** Default summary-only logging. Per-name verbose via `verbose = TRUE`.
- **D-06:** Signature: `match_wqx(names, dictionary, threshold = 0.85, verbose = FALSE)` → tibble.
- **D-07:** Return columns: `input_name`, `wqx_name`, `match_tier`, `match_distance`, `alias_type`.
- **D-08:** Named-vector hash lookups for tiers 1-2 (O(1)). Fuzzy only runs on unresolved remainder.
- **D-09:** Prototype at `scripts/prototype_wqx_matching.R`.
- **D-10:** Prototype runs against `detections_uat_sample_50.csv` and prints tier breakdown + fuzzy matches for review.

### Claude's Discretion
- Internal hash structure choice (named character vector vs R environment vs data.table keyed join)
- How to handle NA/empty input names (skip silently or include with tier="none")
- Whether to `tolower()` upfront once or at each tier
- Test file organization and test case design

### Deferred Ideas (OUT OF SCOPE)
- Benchmarking fuzzy tier performance at scale (10K+ names)
- Threshold tuning based on larger datasets
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MATCH-01 | Exact case-insensitive match against ~23K canonical WQX Characteristic Names | Tier 1 hash lookup on `type == "canonical"` rows; actual canonical count is 23,304 |
| MATCH-02 | Exact case-insensitive match against alias crosswalk, resolving to canonical name | Tier 2 hash lookup on `type %in% c("synonym","standardize","retired")` rows; actual alias count is 100,766 |
| MATCH-03 | Fuzzy fallback via stringdist against canonical names, configurable threshold | Tier 3 using `stringdist::stringdistmatrix(method="jw")`; target set is the 23,304 canonical names |
| MATCH-04 | cli-formatted console logging per match result | `cli::cli_inform()` for verbose mode; `cli::cli_alert_success/warning/danger()` for summary |
| INTG-01 | Standalone prototype validates matching against `detections_uat_sample_50.csv` before Shiny integration | `scripts/prototype_wqx_matching.R` sources needed R files, reads CSV, calls `match_wqx()`, prints report |
</phase_requirements>

---

## Summary

Phase 44 delivers a self-contained `match_wqx()` function implementing a three-tier WQX characteristic name resolver validated against a 50-row training dataset. The phase has no Shiny integration — it ends at a working prototype script.

The dictionary (already built in Phase 43) contains 124,070 rows: 23,304 canonical names and 100,766 alias rows (synonym 75,268 + standardize 23,485 + retired 2,013). The original CONTEXT.md estimated ~13,800 canonical and ~145K aliases — the actual numbers differ, but this does not change the architecture. Tier 1 and tier 2 are hash lookups keyed on `tolower(name)`; tier 3 fuzzy runs only against the 23,304 canonical names. Both `stringdist` (0.9.17) and `cli` (3.6.5) are already installed; neither is in DESCRIPTION yet.

The training data (`detections_uat_sample_50.csv`) has 19 columns; the relevant column for matching is `analyte` (plain text chemical names). A secondary column `cas` is present but is not consumed by `match_wqx()` — that is out of scope for this phase.

**Primary recommendation:** Build `match_wqx()` in a new file `R/wqx_matching.R` following existing namespace conventions, pre-build both hash tables once at function entry from the `dictionary` argument, then escalate through three tiers in sequence on the unresolved remainder.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dictionary loading | R package (file I/O) | — | `load_wqx_dictionary()` already exists; `match_wqx()` accepts pre-loaded dictionary as argument |
| Tier 1 exact canonical lookup | In-memory hash (R named vector) | — | O(1) per name; canonical names only (23,304 rows) |
| Tier 2 alias lookup + resolution | In-memory hash (R named vector) | — | O(1) per name; alias → canonical_name mapping |
| Tier 3 fuzzy match | `stringdist` vectorized matrix | — | Runs only on unresolved remainder against 23,304 canonical names |
| Console logging | `cli` package | — | Summary always; per-name detail when `verbose = TRUE` |
| Prototype validation | Standalone R script | — | Sources R files, reads CSV, calls `match_wqx()`, prints report |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| stringdist | 0.9.17 [VERIFIED: installed] | Jaro-Winkler fuzzy distance computation | Locked by D-01; mature, CRAN, vectorized |
| cli | 3.6.5 [VERIFIED: installed] | Styled console output | Locked by D-04; already used in chemreg ecosystem |
| dplyr | already in DESCRIPTION | Tibble construction, filtering | Project standard |
| tibble | already in DESCRIPTION | Return structure | Project standard |

### Not Used in This Phase

| Skipped | Reason |
|---------|--------|
| data.table keyed join | Claude's discretion resolved to named vector — simpler, adequate for 23K keys |
| R environment hash | Named character vector is sufficient; environments add complexity without measurable benefit at this scale |

**Installation (DESCRIPTION additions only):**
```
stringdist
cli
```
Both are already installed locally; only DESCRIPTION Imports needs updating.

---

## Architecture Patterns

### System Architecture Diagram

```
Input: character vector (analyte names)
           |
           v
    [Pre-processing]
    tolower() once upfront
    Handle NA/empty → tier="none" row, skip from lookup
           |
           v
    [Hash Table Construction] (at function entry, from dictionary arg)
    tier1_hash: setNames(canonical_rows$name, tolower(canonical_rows$name))
    tier2_hash: setNames(alias_rows$canonical_name, tolower(alias_rows$name))
    tier2_type: setNames(alias_rows$type, tolower(alias_rows$name))
           |
           v
    [Tier 1: Exact Canonical Lookup] (O(1) per name)
    names_lower %in% names(tier1_hash)
    → resolved: match_tier="exact", wqx_name=canonical name, alias_type=NA
    → unresolved_1: pass to tier 2
           |
           v
    [Tier 2: Alias Lookup] (O(1) per name)
    unresolved_1_lower %in% names(tier2_hash)
    → resolved: match_tier="alias", wqx_name=tier2_hash[name], alias_type=tier2_type[name]
    → unresolved_2: pass to tier 3
           |
           v
    [Tier 3: Fuzzy Match] (O(n × 23304) Jaro-Winkler)
    stringdist::stringdistmatrix(unresolved_2, canonical_names, method="jw")
    best_distance = apply(mat, 1, min)
    best_match   = canonical_names[apply(mat, 1, which.min)]
    accepted: distance <= (1 - threshold)  [JW distance, lower=more similar]
    → resolved: match_tier="fuzzy", wqx_name=best_match, match_distance=best_distance
    → rejected: match_tier="none", wqx_name=NA, match_distance=best_distance (nearest shown)
           |
           v
    [Logging]
    Summary always via cli (N exact, N alias, N fuzzy, N unresolved)
    Per-name detail if verbose=TRUE
           |
           v
Output: tibble (input_name, wqx_name, match_tier, match_distance, alias_type)
```

### Key Implementation Detail: Jaro-Winkler Distance Direction

`stringdist::stringdist(method="jw")` returns a **distance** (0 = identical, 1 = maximally different), not a similarity. The threshold `0.85` in D-02 refers to **similarity**. Therefore:

- Accept match when `distance <= (1 - 0.85)` → `distance <= 0.15`
- Report `match_distance` as the raw distance value (planner should document this conversion clearly in task comments)

[VERIFIED: stringdist package documentation — `method="jw"` returns Jaro-Winkler distance in [0,1]]

### Recommended Project Structure

```
R/
├── wqx_matching.R       # match_wqx() — new file this phase
scripts/
├── prototype_wqx_matching.R   # new this phase
tests/
├── test_wqx_matching.R        # new this phase (WFUT-01, deferred but worth scaffolding)
```

### Pattern 1: Named Vector Hash Lookup (Tier 1 and 2)

```r
# Build once at function entry
canonical_rows <- dictionary[dictionary$type == "canonical", ]
alias_rows     <- dictionary[dictionary$type %in% c("synonym", "standardize", "retired"), ]

tier1_keys  <- tolower(canonical_rows$name)           # lookup keys
tier1_vals  <- canonical_rows$name                    # original-cased canonical name

tier2_keys  <- tolower(alias_rows$name)
tier2_vals  <- alias_rows$canonical_name              # resolves to canonical
tier2_types <- alias_rows$type                        # "synonym"/"standardize"/"retired"

tier1_map <- stats::setNames(tier1_vals, tier1_keys)
tier2_map <- stats::setNames(tier2_vals, tier2_keys)
tier2_type_map <- stats::setNames(tier2_types, tier2_keys)

# O(1) lookup
names_lower <- tolower(input_names)
tier1_hits  <- tier1_map[names_lower]                 # NA where no match
```

[ASSUMED] Named character vector lookup via `[` on a named vector performs O(1) hash lookup in R for large vectors. This is standard R behavior but not explicitly benchmarked here at 23K scale.

### Pattern 2: Fuzzy Matrix for Tier 3

```r
# Only run on unresolved names (after tiers 1-2)
unresolved <- input_names[is.na(tier2_hit)]
canonical_name_vec <- canonical_rows$name   # 23,304 names

dist_matrix <- stringdist::stringdistmatrix(
  tolower(unresolved),
  tolower(canonical_name_vec),
  method = "jw"
)
# dist_matrix: nrow = length(unresolved), ncol = 23304

best_dist  <- apply(dist_matrix, 1, min)
best_idx   <- apply(dist_matrix, 1, which.min)
best_match <- canonical_name_vec[best_idx]

accepted <- best_dist <= (1 - threshold)   # threshold=0.85 → cutoff=0.15
```

[VERIFIED: stringdist 0.9.17 — `stringdistmatrix()` accepts two character vectors and returns a distance matrix]

### Pattern 3: cli Logging (Project Convention)

```r
# Summary (always)
cli::cli_inform(c(
  "v" = "WQX match complete: {n_exact} exact, {n_alias} alias, {n_fuzzy} fuzzy, {n_none} unresolved"
))

# Per-name verbose (when verbose=TRUE)
cli::cli_alert_success("'{input}' -> '{wqx}' [{tier}, dist={dist}]")
cli::cli_alert_warning("'{input}' -> unresolved (nearest: '{candidate}', dist={dist})")
```

### Pattern 4: Prototype Script Structure (mirrors benchmark_pipeline.R)

```r
# scripts/prototype_wqx_matching.R
CHEMREG_ROOT <- here::here()
source(file.path(CHEMREG_ROOT, "R", "cleaning_reference.R"))
source(file.path(CHEMREG_ROOT, "R", "wqx_matching.R"))

# Load dictionary from shipped cache
cache_dir <- file.path(CHEMREG_ROOT, "inst", "extdata", "reference_cache")
dict <- load_wqx_dictionary(cache_dir)

# Load training data
train <- readr::read_csv(
  file.path(CHEMREG_ROOT, "detections_uat_sample_50.csv"),
  show_col_types = FALSE
)

# Run matcher
results <- match_wqx(train$analyte, dict, threshold = 0.85, verbose = TRUE)

# Accuracy report
print(table(results$match_tier))
fuzzy_hits <- results[results$match_tier == "fuzzy", ]
print(fuzzy_hits[, c("input_name", "wqx_name", "match_distance")])
```

### Anti-Patterns to Avoid

- **Row-by-row loop for hash lookup:** Extract the full vector with `map[names_lower]` — do not loop with `for (n in names)`. R vectorizes named-vector subscripting.
- **Running fuzzy on all 124K rows:** Fuzzy must run only on the ~23,304 canonical names as specified in D-08. Fuzzy against alias names would be 5× slower with no accuracy benefit (aliases already matched exactly in tier 2).
- **Recomputing hash tables per call:** Build tier1_map and tier2_map once at the top of `match_wqx()` from the passed-in dictionary, not inside any inner loop.
- **Confusing JW similarity with JW distance:** `stringdist` returns distance (lower = better). Threshold 0.85 similarity → distance cutoff 0.15.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Jaro-Winkler distance | Custom string comparison | `stringdist::stringdistmatrix(method="jw")` | Edge cases in prefix weighting; vectorized C implementation |
| Console color/symbol output | `cat()` with ANSI codes | `cli::cli_inform()`, `cli::cli_alert_*()` | Already a project dependency; handles terminal detection |
| Case-folding normalization | Manual regex | `base::tolower()` once upfront | Sufficient for ASCII chemical names in this dataset |

---

## Common Pitfalls

### Pitfall 1: JW Distance vs. Similarity Inversion

**What goes wrong:** Threshold 0.85 is written in context as a similarity threshold. `stringdist(method="jw")` returns distance. Code that does `distance >= 0.85` accepts the wrong matches (near-misses instead of near-hits).

**Why it happens:** The function name and literature describe Jaro-Winkler "similarity" but the `stringdist` package consistently returns distances for all methods.

**How to avoid:** Always apply `distance <= (1 - threshold)`. Add a comment: `# JW distance: 0=identical, cutoff = 1 - threshold`.

**Warning signs:** Tier 3 returns zero matches on clearly similar names; or returns very dissimilar matches.

### Pitfall 2: Duplicate Keys in Named Vectors

**What goes wrong:** If two alias rows have the same lowercased `name` (duplicate aliases mapping to different canonicals), the last one wins silently in `setNames()`.

**Why it happens:** The WQX alias table can contain the same alias pointing to multiple canonical names (e.g., a synonym shared between two parameters).

**How to avoid:** Before building tier2_map, deduplicate by `tolower(name)` keeping the first row per key (or log a warning about conflicts). Use `dplyr::distinct(tolower_name, .keep_all = TRUE)`.

**Warning signs:** Matches that resolve to unexpected canonical names.

### Pitfall 3: Training Data Analyte Names with Trailing Spaces or Mixed Case

**What goes wrong:** `detections_uat_sample_50.csv` analyte values like `"Ammonia as N"` must match `"Ammonia as N"` in the dictionary. Invisible differences (trailing spaces, non-breaking spaces) break exact lookup.

**Why it happens:** The CSV was generated from external data; whitespace normalization may differ from how the dictionary was built (`trimws()` is applied during dictionary construction).

**How to avoid:** Apply `trimws()` to input names before `tolower()` in `match_wqx()`.

**Warning signs:** Known-good names falling through to tier 3 fuzzy.

### Pitfall 4: `stringdistmatrix` Memory for Large Inputs

**What goes wrong:** At scale (1,000+ unresolved names × 23,304 canonical names), the distance matrix is a 23M-element numeric matrix consuming ~180MB RAM.

**Why it happens:** `stringdistmatrix` materializes the full matrix in memory.

**How to avoid:** For this phase (50-row prototype), this is not a concern. Deferred to Phase 45 per CONTEXT.md. Document the concern in code comments for Phase 45 awareness.

**Warning signs:** R session memory spike during tier 3.

---

## Dictionary Structure Reference

Verified against the shipped `inst/extdata/reference_cache/wqx_dictionary.rds`:

| Column | Type | Notes |
|--------|------|-------|
| `name` | character | The lookup key (the string to match against). Trimmed but not lowercased. |
| `canonical_name` | character | For canonical rows: same as `name`. For alias rows: the authoritative WQX name. |
| `type` | character | One of: `"canonical"`, `"synonym"`, `"standardize"`, `"retired"` |
| `cas_number` | character | Present for canonical rows only; NA for alias rows |
| `group_name` | character | WQX parameter group; NA for alias rows |
| `description` | character | Free text; NA for many rows |

**Actual row counts [VERIFIED: loaded RDS]:**

| Type | Count | Used In |
|------|-------|---------|
| canonical | 23,304 | Tier 1 lookup keys + Tier 3 fuzzy target |
| synonym | 75,268 | Tier 2 lookup keys |
| standardize | 23,485 | Tier 2 lookup keys |
| retired | 2,013 | Tier 2 lookup keys |
| **Total** | **124,070** | — |

Note: CONTEXT.md estimated ~13,800 canonical and ~145K aliases. Actual counts differ — use these verified figures.

---

## Training Data Reference

`detections_uat_sample_50.csv` columns: `site_id, event_id, sample_date, year, month, analyte_id, analyte, cas, domain, family, order, units, detected, concentration, reporting_limit, result_qualifier, reported_result, dist_nearest_discharge_km, site_type`

- **Target column for matching:** `analyte` (plain text, e.g., "Ammonia as N", "GenX (HFPO-DA)", "Arsenic", "Mercury")
- **50 rows total** — no batching needed in prototype
- The `cas` column is present but not consumed by `match_wqx()` in this phase

---

## DESCRIPTION Changes Required

Add to `Imports:` section:

```
cli,
stringdist,
```

Neither is currently listed in DESCRIPTION [VERIFIED: read DESCRIPTION]. Both are installed locally at correct versions.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stringdist | Tier 3 fuzzy | Yes | 0.9.17 | — |
| cli | Logging | Yes | 3.6.5 | — |
| wqx_dictionary.rds | All tiers | Yes | — (Phase 43 output) | Run `scripts/build_wqx_dictionary.R` |
| detections_uat_sample_50.csv | Prototype | Yes | — | — |

No missing dependencies.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat >= 3.0.0 |
| Config file | none — run via `testthat::test_dir("tests")` |
| Quick run command | `testthat::test_file("tests/test_wqx_matching.R")` |
| Full suite command | `testthat::test_dir("tests")` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MATCH-01 | Exact canonical hit returns `match_tier="exact"` | unit | `testthat::test_file("tests/test_wqx_matching.R")` | No — Wave 0 |
| MATCH-02 | Alias hit returns `match_tier="alias"` with correct `alias_type` and `wqx_name` | unit | same | No — Wave 0 |
| MATCH-03 | Near-match returns `match_tier="fuzzy"` with distance; far name returns `match_tier="none"` | unit | same | No — Wave 0 |
| MATCH-04 | `verbose=FALSE` produces no per-name output; `verbose=TRUE` does | unit | same | No — Wave 0 |
| INTG-01 | Prototype script runs without error on training CSV | smoke | `source("scripts/prototype_wqx_matching.R")` | No — Wave 0 |

### Wave 0 Gaps

- `tests/test_wqx_matching.R` — covers MATCH-01 through MATCH-04
- `scripts/prototype_wqx_matching.R` — covers INTG-01 (also Wave 0 deliverable)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Named character vector `[` subscripting is O(1) at 23K keys | Architecture Patterns | Tier 1/2 may be slower than expected; fallback is `match()` which is also fast |
| A2 | Prototype's 50-name fuzzy run completes in < 10 seconds | Common Pitfalls | Negligible risk at 50 rows |

---

## Sources

### Primary (HIGH confidence)
- `inst/extdata/reference_cache/wqx_dictionary.rds` — loaded and inspected: row counts, column names, type distribution
- `R/cleaning_reference.R` lines 519-629 — dictionary builder and loader implementations read directly
- `R/curation.R` — tiered search orchestration pattern read directly
- `DESCRIPTION` — confirmed stringdist and cli are not yet in Imports
- Bash: `Rscript -e "packageVersion(...)"` — confirmed stringdist 0.9.17, cli 3.6.5 installed
- `detections_uat_sample_50.csv` — header row read directly; `analyte` column confirmed

### Secondary (MEDIUM confidence)
- stringdist package documentation [CITED: stringdist CRAN] — `method="jw"` returns distance in [0,1]

---

## RESEARCH COMPLETE
