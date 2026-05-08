# Phase 49: Conflict Scoring Engine - Research

**Researched:** 2026-05-08
**Domain:** Jaro-Winkler string similarity, CompTox synonym API, Shiny reactive data flow
**Confidence:** HIGH

## Summary

Phase 49 adds a similarity score to disagree rows by comparing the user's original chemical name against each candidate's CompTox preferred name and synonym list. The score formula is locked in CONTEXT.md (D-03): `max(JW_similarity(input, name_i))` across all names, with a +0.05 rank bonus for candidates ranked ≤ 3, clamped to [0, 1].

All infrastructure required for scoring already exists: `stringdist` is a declared DESCRIPTION dependency and is used in `R/wqx_matching.R` with the same JW method. The enrichment cache pattern in `enrich_candidates()` is the direct model for synonym caching. The WQX Conf. column in `mod_review_results.R` is the exact template for the Sim. Score column.

The main new work is: (1) extend `enrich_candidates()` to also call `ct_chemical_synonym_search_bulk()` and store a `synonyms` string column in the cache, (2) add `compute_similarity_scores()` in `R/consensus.R` to produce a `similarity_score` column in `resolution_state`, (3) wire the column into the Review Results table colDef and comparison modal cards, and (4) include the score in export.

**Primary recommendation:** Extend the existing enrichment cache (add `synonyms` column), compute scores after enrichment in `mod_run_curation.R`, store as `similarity_score` on `resolution_state`, and render identically to the WQX Conf. column pattern.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Expand `enrich_candidates()` to also call `ct_chemical_synonym_search_bulk()` during enrichment. Synonym data is cached alongside CASRN/formula/MW in the enrichment cache. Score computation reads from cache only — no API calls at score time.

**D-02:** `ct_chemical_synonym_search_bulk()` returns synonym tiers (valid, good, other, beilstein, alternate). All tiers are stored in the cache for potential future use, but scoring treats all synonyms equally.

**D-03:** Score formula: `score = max(JW(input, preferredName), JW(input, synonym_1), ..., JW(input, synonym_N))`. If candidate rank ≤ 3, add +0.05 bonus. Clamp final score to [0, 1].

**D-04:** All synonym tiers treated equally for JW comparison — no tier-based weighting.

**D-05:** New "Sim. Score" column in Review Results table, matching the existing WQX Conf. pattern: 2-decimal right-aligned format, blank for non-disagree rows.

**D-06:** Table column shows the **best** candidate's score for that row. Individual per-candidate scores are shown in the existing comparison modal.

**D-07:** The input string is always the user's original chemical name from the row.

**D-08:** CAS-sourced candidates are scored the same way as name-sourced candidates.

### Claude's Discretion

- Prototype script structure and test case selection
- Enrichment cache schema extension details (how synonym strings are stored)
- Whether to batch synonym fetches or fetch all at once
- Score function naming and file placement (new file vs. extending consensus.R)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCORE-01 | User can see a similarity score between original input and each candidate name in disagree rows | WQX Conf. colDef pattern (§765-788) is direct template; `similarity_score` column on `resolution_state`; per-candidate scores in modal cards |
| SCORE-02 | Similarity scoring incorporates CompTox synonym lists and rank data to weight candidates | `ct_chemical_synonym_search_bulk()` provides synonym tiers; rank column already in `get_resolution_options()` output; D-03 formula verified to produce clear separation (Silica vs Silicon Dioxide: 1.00, Silica vs Estradiol: 0.35) |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Synonym fetch + cache | API/Backend (`R/curation.R`) | — | Follows existing `enrich_candidates()` pattern; network call isolated here |
| Score computation | API/Backend (`R/consensus.R`) | — | Pure function over cached data; no Shiny dependency |
| Score injection into resolution_state | Server (`mod_run_curation.R`) | — | Same location as enrichment call; flows through data_store |
| Table column rendering | UI Server (`mod_review_results.R`) | — | Identical to WQX Conf. colDef pattern at §769-788 |
| Modal per-candidate scores | UI Server (`mod_review_results.R`) | — | Inline computation from enrichment_cache at modal render time |
| Export inclusion | Backend (`R/export_helpers.R`) | — | Curated Data sheet already includes enrichment columns via left_join |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| stringdist | listed in DESCRIPTION | Jaro-Winkler distance computation | Already a project dependency; used in `R/wqx_matching.R` §112 [VERIFIED: DESCRIPTION] |
| ComptoxR | (remote: seanthimons/ComptoxR) | `ct_chemical_synonym_search_bulk()` synonym fetch | Only CompTox API client in project; synonym endpoint confirmed [VERIFIED: ComptoxR namespace] |

No new dependencies are needed for this phase.

**Verified function signature:** `ct_chemical_synonym_search_bulk(query)` — takes a character vector of DTXSIDs, POSTs to `chemical/synonym/search/by-dtxsid/`, returns a tidied tibble. [VERIFIED: ComptoxR:::generic_request body inspection]

---

## Architecture Patterns

### System Architecture Diagram

```
[User uploads file]
        |
[Curation pipeline runs] --> resolution_state (disagree rows have dtxsid_* cols)
        |
[enrich_candidates() - EXTENDED]
  |- ct_chemical_detail_search_bulk() --> casrn, formula, mw
  |- ct_chemical_synonym_search_bulk() --> synonyms (pipe-joined string)
  --> enrichment_cache: {dtxsid, casrn, molecular_formula, molecular_weight, synonyms}
        |
[compute_similarity_scores(resolution_state, enrichment_cache, dtxsid_cols)]
  |- For each disagree row:
  |    for each candidate DTXSID:
  |      all_names = [preferredName] + split(synonyms, "|")
  |      sim = max(1 - stringdist(input, all_names, method="jw"))
  |      if rank <= 3: sim = min(1.0, sim + 0.05)
  |    best_score = max(candidate_scores)
  |- similarity_score column added to resolution_state
        |
[data_store$resolution_state] -- has similarity_score
        |
[Review Results table colDef] --> "Sim. Score" column (blank for non-disagree)
        |
[Comparison modal cards] --> per-candidate score computed inline from enrichment_cache
```

### Recommended Project Structure

No new files required. Changes are confined to:

```
R/
├── curation.R          # extend enrich_candidates() + new enrich_synonyms()
├── consensus.R         # new compute_similarity_scores()
├── mod_run_curation.R  # wire synonym fetch + score computation after enrichment
├── mod_review_results.R # add Sim. Score colDef + scores in modal cards
└── export_helpers.R    # include similarity_score in Curated Data sheet
tests/testthat/
├── test-enrichment.R   # add synonym cache tests
└── test-consensus.R    # add compute_similarity_scores tests
scripts/
└── prototype_conflict_scoring.R  # (Claude's discretion) offline test script
```

### Pattern 1: Synonym Cache Extension

**What:** Add a `synonyms` column (pipe-separated string, NA if none returned) to the existing enrichment cache tibble. This follows the same incremental-caching pattern already in `enrich_candidates()`.

**When to use:** Always — the column is nullable, so existing cache entries without synonyms remain valid.

**Example (cache schema):**
```r
# Source: R/curation.R enrich_candidates() pattern
tibble::tibble(
  dtxsid           = character(),
  casrn            = character(),
  molecular_formula = character(),
  molecular_weight  = numeric(),
  synonyms         = character()   # pipe-joined; NA if API returned 0 rows
)
```

**Synonym fetch function (new, in R/curation.R):**
```r
# Incremental synonym fetch — mirrors enrich_candidates() structure
enrich_synonyms <- function(dtxsids, existing_cache = NULL) {
  # filter already-cached, fetch new, flatten tiers, join pipe string
  # Returns list(cache = tibble_with_synonyms_col, failed_dtxsids = character())
}
```

**Flattening synonym tiers:**
```r
# All tiers treated equally per D-04
flatten_synonym_tiers <- function(row) {
  tier_cols <- c("valid", "good", "other", "deleted", "beilstein", "alternate", "pcCode")
  syns <- unlist(lapply(tier_cols, function(col) {
    vals <- row[[col]]
    if (!is.null(vals)) as.character(unlist(vals)) else character(0)
  }))
  syns <- unique(syns[!is.na(syns) & nchar(syns) > 0])
  if (length(syns) == 0) NA_character_ else paste(syns, collapse = "|")
}
```

### Pattern 2: Score Formula Implementation

**What:** `compute_similarity_scores()` takes `resolution_state`, `enrichment_cache`, and `dtxsid_cols`, returns `resolution_state` with a `similarity_score` column added. NA for non-disagree rows.

**Example:**
```r
# Source: verified against stringdist behavior, D-03 formula
compute_similarity_scores <- function(resolution_state, enrichment_cache, dtxsid_cols) {
  n <- nrow(resolution_state)
  scores <- rep(NA_real_, n)

  disagree_idx <- which(resolution_state$consensus_status == "disagree")

  for (i in disagree_idx) {
    # Identify input name column (first Name-tagged column value)
    input_name <- get_input_name(resolution_state, i)  # see below

    candidate_scores <- numeric(0)
    for (col in dtxsid_cols) {
      dtxsid_val <- resolution_state[[col]][i]
      if (is.na(dtxsid_val)) next

      pref_col <- sub("^dtxsid_", "preferredName_", col)
      rank_col <- sub("^dtxsid_", "rank_", col)
      pref_name <- if (pref_col %in% names(resolution_state)) resolution_state[[pref_col]][i] else NA_character_
      rank_val  <- if (rank_col %in% names(resolution_state)) resolution_state[[rank_col]][i] else NA_real_

      # Get synonyms from cache
      synonyms_str <- NA_character_
      if (!is.null(enrichment_cache) && nrow(enrichment_cache) > 0) {
        idx <- which(enrichment_cache$dtxsid == dtxsid_val)
        if (length(idx) > 0 && "synonyms" %in% names(enrichment_cache)) {
          synonyms_str <- enrichment_cache$synonyms[idx[1]]
        }
      }

      syns <- if (!is.na(synonyms_str)) strsplit(synonyms_str, "|", fixed = TRUE)[[1]] else character(0)
      all_names <- c(pref_name, syns)
      all_names <- all_names[!is.na(all_names) & nchar(trimws(all_names)) > 0]
      if (length(all_names) == 0) next

      sims <- 1 - stringdist::stringdist(tolower(input_name), tolower(all_names), method = "jw")
      base_score <- max(sims, na.rm = TRUE)
      bonus <- if (!is.na(rank_val) && rank_val <= 3) 0.05 else 0.0
      candidate_score <- min(1.0, base_score + bonus)
      candidate_scores <- c(candidate_scores, candidate_score)
    }

    if (length(candidate_scores) > 0) {
      scores[i] <- max(candidate_scores)
    }
  }

  resolution_state$similarity_score <- scores
  resolution_state
}
```

### Pattern 3: Identifying the Input Name Column

**What:** The input name for scoring is always the user's original chemical name (D-07). This is the value in the Name-tagged column(s) before curation.

**Key insight:** `resolution_state` retains the original column values. The Name-tagged column name is known from `data_store$column_tags`. The score function needs the column_tags to identify which column holds the input name.

```r
# Approach: pass the Name-tagged column name(s) to compute_similarity_scores()
# Or: look up the first column tagged "Name" from column_tags
get_input_name_from_tags <- function(row, column_tags) {
  name_cols <- names(column_tags)[column_tags == "Name"]
  if (length(name_cols) == 0) return(NA_character_)
  val <- row[[name_cols[1]]]
  if (!is.null(val) && !is.na(val)) as.character(val) else NA_character_
}
```

### Pattern 4: Table Column (Sim. Score colDef)

**What:** Exact mirror of WQX Conf. pattern at `R/mod_review_results.R` §769-788.

```r
# Source: R/mod_review_results.R §769-788 — direct template
if ("similarity_score" %in% names(df_display)) {
  col_defs[["similarity_score"]] <- reactable::colDef(
    name = "Sim. Score",
    minWidth = 80,
    align = "right",
    cell = function(value, index) {
      if (is.na(value)) return("")
      formatC(value, digits = 2, format = "f")
    }
  )
}
```

### Pattern 5: Per-Candidate Score in Modal Cards

**What:** Compute per-candidate score inline when building modal candidate cards. The modal already has access to `enrichment_cache` (passed to `get_resolution_options()`) and the input row.

```r
# Inside the lapply(names(options), ...) loop that builds candidate cards
# opt already has: dtxsid, preferredName, rank
# enrichment_cache already in scope
sim_score <- score_one_candidate(
  input_name  = input_name,
  preferred_name = opt$preferredName,
  synonyms_str   = get_synonyms_from_cache(enrichment_cache, opt$dtxsid),
  rank           = opt$rank
)
# Add to card UI: tags$span(class="badge bg-info", sprintf("%.2f", sim_score))
```

### Anti-Patterns to Avoid

- **Row-by-row stringdist calls inside nested loops with scalar extraction:** Pre-extract the full `all_names` vector per candidate, then call `stringdist()` once over the vector. Do not call `stringdist()` on individual string pairs inside a loop.
- **Re-fetching synonyms at score time:** Scores are computed from cache only (D-01). Never call `ct_chemical_synonym_search_bulk()` from `compute_similarity_scores()`.
- **Storing synonyms as a list column:** Use a pipe-joined character string. List columns in tibbles break `dplyr::bind_rows()` in the incremental cache merge.
- **Using `stringdist::stringsim()` directly:** The `stringdist` package does not export `stringsim()` in all versions. Use `1 - stringdist::stringdist(..., method = "jw")` consistently, matching the existing pattern at `R/wqx_matching.R` §112.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Jaro-Winkler similarity | Custom character comparison loop | `stringdist::stringdist(..., method = "jw")` | Already a dependency, vectorized, handles Unicode |
| Synonym API call batching | Custom HTTP batching | `ct_chemical_synonym_search_bulk()` batch_limit env var | ComptoxR handles batching internally (default 100 per batch) |
| Pipe-string splitting | Custom parser | `strsplit(s, "|", fixed = TRUE)` | Simple, no dependencies |

---

## Common Pitfalls

### Pitfall 1: Synonym API Returns 0 Rows for Some DTXSIDs

**What goes wrong:** `ct_chemical_synonym_search_bulk()` returns an empty tibble for DTXSIDs with no synonym data (confirmed in CONTEXT.md specifics: DTXSID7020006 / Acetone returned 0 rows). If the scoring function assumes at least one synonym row exists, it will error or return NA incorrectly.

**Why it happens:** Not all chemicals in CompTox have synonym records in the bulk endpoint.

**How to avoid:** Store `NA_character_` in the `synonyms` column when the API returns 0 rows for that DTXSID. Score function checks `is.na(synonyms_str)` and falls back to `preferredName`-only comparison.

**Warning signs:** `max()` called on `numeric(0)` throws a warning; guard with `if (length(candidate_scores) > 0)`.

### Pitfall 2: enrichment_cache Missing `synonyms` Column on Old Sessions

**What goes wrong:** If a user runs curation on an older session where the cache was built without the `synonyms` column, `compute_similarity_scores()` will fail or silently skip scoring when it tries to access `enrichment_cache$synonyms`.

**Why it happens:** The enrichment cache is stored in `data_store$enrichment_cache` (reactiveValues) and persists across re-runs within the same session. If the column didn't exist when the cache was first built, it won't appear later.

**How to avoid:** In `compute_similarity_scores()`, check `"synonyms" %in% names(enrichment_cache)` before accessing the column. If absent, treat all synonyms as missing (score on preferredName only). In `enrich_synonyms()`, always add the `synonyms` column even for the empty cache tibble.

### Pitfall 3: Input Name Column Discovery

**What goes wrong:** `compute_similarity_scores()` needs to know which column holds the user's original chemical name (D-07). If `column_tags` is not passed to the function, or if a row has no Name-tagged column, scoring fails silently.

**Why it happens:** `resolution_state` has many columns; the Name column varies by dataset.

**How to avoid:** Pass `column_tags` (or the resolved Name column name) to `compute_similarity_scores()`. Default gracefully: if no Name-tagged column found, skip scoring for that row (leave `similarity_score` as NA).

### Pitfall 4: `similarity_score` Column Not Present When Table Renders

**What goes wrong:** `mod_review_results.R` renders before `compute_similarity_scores()` runs (or enrichment fails). The colDef references a column that doesn't exist in `df_display`.

**Why it happens:** Reactive rendering order — table can render before the enrichment + scoring pipeline completes.

**How to avoid:** Gate the Sim. Score colDef with `if ("similarity_score" %in% names(df_display))`, identical to how the WQX confidence columns are gated. If the column is absent, no colDef is added and the column does not appear.

### Pitfall 5: Synonym Fetch Added to Wrong Enrichment Call Site

**What goes wrong:** `enrich_candidates()` is called once at §229 in `mod_run_curation.R`. A synonym fetch must happen at the same call site, not inside `enrich_candidates()` itself (which would couple the two API calls together and make them harder to mock in tests).

**Why it happens:** It's tempting to put the synonym fetch inside `enrich_candidates()` for convenience.

**How to avoid:** Keep synonym fetch as a separate `enrich_synonyms()` function called immediately after `enrich_candidates()` in `mod_run_curation.R`. This keeps functions single-responsibility and maintains the existing test isolation pattern (each enrichment function is independently mockable).

---

## Code Examples

### JW Similarity (verified behavior)

```r
# Source: verified against stringdist 0.9.x via runtime test
# stringdist() returns DISTANCE (0 = identical, 1 = maximally different)
# Similarity = 1 - distance
library(stringdist)
sim <- 1 - stringdist::stringdist(
  tolower("Silica"),
  tolower(c("Silicon Dioxide", "Silica gel", "Estradiol")),
  method = "jw"
)
# sim: 0.722, 0.867, 0.352
```

### Vectorized batch scoring (verified, 500 rows x 5 candidates x 100 synonyms = 0.61 sec)

```r
# Source: runtime performance test 2026-05-08
sims <- 1 - stringdist::stringdist(
  tolower(input_name),
  tolower(all_names_vector),   # preferredName + all synonyms
  method = "jw"
)
max(sims, na.rm = TRUE)
```

### enrichment_cache empty schema (with synonyms column)

```r
empty_cache <- tibble::tibble(
  dtxsid            = character(0),
  casrn             = character(0),
  molecular_formula = character(0),
  molecular_weight  = numeric(0),
  synonyms          = character(0)   # <-- new column
)
```

### WQX Conf. colDef (template for Sim. Score)

```r
# Source: R/mod_review_results.R §776-788
reactable::colDef(
  name = "WQX Conf.",   # change to "Sim. Score"
  minWidth = 80,
  align = "right",
  cell = function(value, index) {
    if (is.na(value)) return("")
    formatC(value, digits = 2, format = "f")
  }
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No conflict scoring | JW score against preferredName + synonyms | Phase 49 | Disagree rows get numeric similarity signal |
| enrichment_cache: 4 columns | enrichment_cache: 5 columns (add `synonyms`) | Phase 49 | Backward-compatible; `synonyms` is nullable |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stringdist | JW scoring | Yes | listed in DESCRIPTION | — |
| ComptoxR | Synonym API | Yes | seanthimons/ComptoxR (remote) | — |
| CompTox API key | ct_chemical_synonym_search_bulk | Assumed set | — | Scoring degrades gracefully to NA if fetch fails |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | tests/testthat.R |
| Quick run command | `testthat::test_file("tests/testthat/test-enrichment.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCORE-01 | similarity_score column present and numeric for disagree rows, NA for non-disagree | unit | `testthat::test_file("tests/testthat/test-consensus.R")` | Exists — add tests |
| SCORE-01 | Sim. Score colDef renders 2-decimal right-aligned value, blank for NA | unit | `testthat::test_file("tests/testthat/test-mod-review-helpers.R")` | Exists — add tests |
| SCORE-02 | Score uses synonyms from cache — Silica vs Silicon Dioxide > Silica vs Estradiol | unit | `testthat::test_file("tests/testthat/test-consensus.R")` | Exists — add tests |
| SCORE-02 | Rank bonus: rank ≤ 3 candidate gets +0.05, clamped to 1.0 | unit | `testthat::test_file("tests/testthat/test-consensus.R")` | Exists — add tests |
| SCORE-01+02 | enrich_synonyms() returns synonyms column; NA when API returns 0 rows | unit | `testthat::test_file("tests/testthat/test-enrichment.R")` | Exists — add tests |

### Sampling Rate

- **Per task commit:** `testthat::test_file("tests/testthat/test-consensus.R")`
- **Per wave merge:** `testthat::test_dir("tests/testthat")`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

No new test files needed — all tests added to existing files:
- `tests/testthat/test-consensus.R` — add `compute_similarity_scores()` tests
- `tests/testthat/test-enrichment.R` — add `enrich_synonyms()` tests

---

## Security Domain

`security_enforcement` not set to false in config.json — treated as enabled.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | Synonym strings from CompTox API are treated as display-only data; no SQL/eval exposure |
| V2 Authentication | no | No new auth surface |
| V3 Session Management | no | No new session state |
| V4 Access Control | no | No new access control surface |
| V6 Cryptography | no | No cryptographic operations |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed synonym strings from API | Tampering | Treat as display strings only; `strsplit()` + `nchar()` guard before JW call |
| NA propagation in score | Information Disclosure | Explicit `na.rm = TRUE` in `max()`; NA score renders as blank in table |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ct_chemical_synonym_search_bulk()` returns columns named `valid`, `good`, `other`, `deleted`, `beilstein`, `alternate`, `pcCode` | Standard Stack | Wrong column names mean flattening produces empty synonyms; planner should verify against a live API call or existing project test |

**Note:** The column names for synonym tiers are stated in the CONTEXT.md canonical refs and are [ASSUMED] as not directly verified via live API call in this session. All other claims are [VERIFIED] via code inspection.

---

## Open Questions

1. **Prototype script as Wave 0 task or separate?**
   - What we know: Claude's discretion controls prototype script structure (CONTEXT.md)
   - What's unclear: Whether the planner should include a prototype script task in Wave 0 before integration
   - Recommendation: Include prototype in Wave 0 to validate the score formula against a real disagree row (e.g., Silica vs Estradiol) before wiring into the app

2. **Synonym fetch batching — all at once vs. chunked**
   - What we know: ComptoxR handles batching internally via `batch_limit` env var (default 100); `ct_chemical_synonym_search_bulk()` takes a full DTXSIDs vector
   - What's unclear: Whether projects with 1000+ unique DTXSIDs will hit timeout or memory issues
   - Recommendation: Fetch all at once (same pattern as `enrich_candidates()`); the internal batching handles chunking

---

## Sources

### Primary (HIGH confidence)

- `R/curation.R` §960-1064 — `enrich_candidates()` full implementation [VERIFIED: direct read]
- `R/consensus.R` §190-258 — `get_resolution_options()` structure [VERIFIED: direct read]
- `R/mod_review_results.R` §765-788 — WQX Conf. colDef pattern [VERIFIED: direct read]
- `R/wqx_matching.R` §101-124 — existing JW usage via `stringdist::stringdistmatrix()` [VERIFIED: direct read]
- `DESCRIPTION` — `stringdist` confirmed as declared dependency [VERIFIED: direct read]
- ComptoxR namespace — `ct_chemical_synonym_search_bulk()` confirmed; endpoint: `chemical/synonym/search/by-dtxsid/` [VERIFIED: runtime introspection]

### Secondary (MEDIUM confidence)

- Runtime JW behavior test — `stringdist()` returns distance 0-1; `1 - dist` gives similarity [VERIFIED: executed 2026-05-08]
- Performance test — 500 rows × 5 candidates × 100 synonyms = 0.61 sec [VERIFIED: executed 2026-05-08]
- Score formula test — Silica vs Silicon Dioxide = 1.00 (with synonym "Silica" in list), Silica vs Estradiol = 0.35 [VERIFIED: executed 2026-05-08]

### Tertiary (LOW confidence)

- Synonym tier column names (`valid`, `good`, `other`, `deleted`, `beilstein`, `alternate`, `pcCode`) — sourced from CONTEXT.md canonical refs [ASSUMED: not verified via live API call]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified in DESCRIPTION and runtime
- Architecture: HIGH — derived from direct code inspection of all canonical files
- Pitfalls: HIGH — derived from code patterns and CONTEXT.md specifics
- Synonym column names: LOW — stated in CONTEXT.md but not confirmed via live API

**Research date:** 2026-05-08
**Valid until:** 2026-06-07 (stable CompTox API; stringdist API is stable)
