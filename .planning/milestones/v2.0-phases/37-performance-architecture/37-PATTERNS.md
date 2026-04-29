# Phase 37: Performance Architecture - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 5 (3 modified, 2 new function groups)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/cleaning_pipeline.R` — `dedup_step()` wrapper | utility / orchestrator | transform | `R/unit_harmonizer.R` lines 337-347 (`unique_dtxsids` dedup block) | role-match |
| `R/cleaning_pipeline.R` — `remap_audit_to_parent()` | utility | transform | `R/cleaning_pipeline.R` lines 50-98 (`build_audit_trail()`) | exact |
| `R/cleaning_pipeline.R` — pre-check predicate fns | utility | transform | `R/cleaning_pipeline.R` lines 131-149 (skip-if-empty early return in `normalize_cas_fields`) | role-match |
| `R/cleaning_pipeline.R` — `run_cleaning_pipeline()` call sites | orchestrator | transform | `R/cleaning_pipeline.R` lines 1546-1704 (existing orchestrator) | exact |
| `R/unit_harmonizer.R` — unit-key dedup | utility | transform | `R/unit_harmonizer.R` lines 337-347 and 398-435 (existing hash-map dedup pattern) | exact |

---

## Pattern Assignments

### `dedup_step()` wrapper (new function in `R/cleaning_pipeline.R`)

**Role:** utility / orchestrator wrapper
**Data flow:** transform (string-in / string-out)
**Analog:** `R/unit_harmonizer.R` lines 337-347 — the existing partial dedup for DTXSID API calls

**Existing partial-dedup pattern to extend** (lines 337-347):
```r
# Pre-fetch MW for rows that need it (molarity + dtxsid but no mw_override)
needs_api_lookup <- molarity_mask & !is.na(dtxsid_vec) & is.na(mw_vec)

if (any(needs_api_lookup)) {
  unique_dtxsids <- unique(dtxsid_vec[needs_api_lookup])
  unique_dtxsids <- unique_dtxsids[!is.na(unique_dtxsids)]
  if (length(unique_dtxsids) > 0) {
    fetched_mw <- fetch_molecular_weight(unique_dtxsids)
    # Vectorized MW assignment via match
    lookup_idx <- match(dtxsid_vec[needs_api_lookup], names(fetched_mw))
    mw_vec[needs_api_lookup] <- fetched_mw[lookup_idx]
  }
}
```

**What `dedup_step()` adds over the analog:** The analog dedupes a single vector for a single purpose. `dedup_step()` must dedup the target column(s) across the entire df slice, call the step function on the unique slice, then call `remap_audit_to_parent()` to expand audit row IDs back to the full parent.

**Uniqueness bypass guard pattern** (D-03 — modeled after the `if (any(...))` guard above):
The `n_distinct / n_total > 0.5` threshold check follows the same conditional-bypass shape: compute a condition, then skip the dedup path and fall through to a direct step call.

**Step function contract that `dedup_step()` must preserve** (lines 1580-1583):
```r
cas_result <- normalize_cas_fields(df_after_trim, tag_map)
df_after_cas <- cas_result$cleaned_data
audit_combined <- dplyr::bind_rows(audit_combined, cas_result$audit_trail)
```
Every step returns `list(cleaned_data, audit_trail)`. `dedup_step()` must accept and return the same shape so call sites need no changes.

---

### `remap_audit_to_parent()` (new function in `R/cleaning_pipeline.R`)

**Role:** utility
**Data flow:** transform (row-ID remapping)
**Analog:** `R/cleaning_pipeline.R` lines 50-98 — `build_audit_trail()` pre-allocated vector pattern

**Exact audit construction pattern to mirror** (lines 54-97):
```r
# Pre-allocate vectors for all audit entries (avoids O(n^2) growing-list pattern)
all_row_ids <- integer()
all_fields <- character()
all_originals <- character()
all_news <- character()

for (col_name in char_cols) {
  original_vals <- as.character(df_original[[col_name]])
  cleaned_vals  <- as.character(df_cleaned[[col_name]])

  changed_idx <- which(original_vals != cleaned_vals)

  if (length(changed_idx) > 0) {
    all_row_ids  <- c(all_row_ids,  as.integer(changed_idx))
    all_fields   <- c(all_fields,   rep(col_name, length(changed_idx)))
    all_originals <- c(all_originals, original_vals[changed_idx])
    all_news     <- c(all_news,     cleaned_vals[changed_idx])
  }
}

# Build single tibble from vectors (O(1) vs O(n) bind_rows)
if (length(all_row_ids) == 0) {
  return(tibble::tibble(
    row_id = integer(), field = character(), step = character(),
    original_value = character(), new_value = character(), reason = character()
  ))
}
tibble::tibble(
  row_id        = all_row_ids,
  field         = all_fields,
  step          = rep(step_name, length(all_row_ids)),
  original_value = all_originals,
  new_value     = all_news,
  reason        = vapply(all_fields, reason_fn, character(1))
)
```

**What `remap_audit_to_parent()` does differently:** it does NOT re-compare dataframes. Instead it receives `audit_slice` (audit trail from the deduped unique-string slice, with row IDs 1..n_unique) and `parent_indices` (integer vector mapping each unique row back to all matching parent rows), then expands the slice row IDs. Use `match()` or `rep()` with the parent_indices map — same vectorized append pattern as above, no `dplyr::bind_rows()` loop.

**Audit schema invariant** (PERF-02 — must assert after remap):
```r
stopifnot(max(remapped_audit$row_id) <= nrow(parent_df))
```

**Row lineage dependency** (lines 100-113 — `inject_row_lineage`):
```r
inject_row_lineage <- function(df) {
  df %>%
    dplyr::mutate(original_row_id = 1:nrow(df), .before = 1)
}
```
The `original_row_id` column is injected at Step 0 before any step runs. `dedup_step()` must track the relationship between deduped-slice positions and this column to correctly remap audit row IDs.

---

### Pre-check predicate functions (new functions in `R/cleaning_pipeline.R`)

**Role:** utility predicates
**Data flow:** transform (short-circuit evaluation)
**Analog 1:** `R/cleaning_pipeline.R` lines 131-149 — early-return skip pattern in `normalize_cas_fields`:

```r
normalize_cas_fields <- function(df, tag_map) {
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  # Skip if no CASRN columns
  if (length(cas_cols) == 0) {
    return(list(
      cleaned_data = df,
      audit_trail = tibble::tibble(
        row_id = integer(), field = character(), step = character(),
        original_value = character(), new_value = character(), reason = character()
      )
    ))
  }
  ...
```

**Analog 2:** `R/cleaning_pipeline.R` lines 783-795 — skip-if-no-active-terms in `strip_reference_terms`:

```r
  # Skip if no active terms
  if (nrow(active_terms) == 0) {
    return(list(
      cleaned_data = df,
      audit_trail = tibble::tibble(
        row_id = integer(), field = character(), step = character(),
        original_value = character(), new_value = character(), reason = character()
      )
    ))
  }
```

**What the new pre-check predicates add over the analogs:** The analogs embed skip logic inside the step function. Per D-12, the new pre-checks are orchestrator-only functions separate from the step functions. They return `list(should_run = TRUE/FALSE, est_changes = integer)` per D-06.

**stringi pre-check primitive** (D-05 — use this, not custom regex):
```r
# For unicode step pre-check:
!all(stringi::stri_enc_isascii(col_values), na.rm = TRUE)
```

**Empty typed audit trail for skipped step** (D-04 — exact schema required):
```r
# Skipped step must return this, not NULL:
tibble::tibble(
  row_id         = integer(),
  field          = character(),
  step           = character(),
  original_value = character(),
  new_value      = character(),
  reason         = character()
)
```

**Skip message pattern** (D-04):
```r
message(sprintf("Step %s skipped -- pre-check FALSE", step_name))
```

---

### `run_cleaning_pipeline()` call sites (modified in `R/cleaning_pipeline.R`)

**Role:** orchestrator
**Data flow:** transform (sequential pipeline)
**Analog:** `R/cleaning_pipeline.R` lines 1546-1704 — existing orchestrator (read in full above)

**Two-pass dedup boundary** (D-10 — the synonym split is the structural break):

Pass 1 covers Steps 6-pre through 6d3 (lines 1601-1652). These are dedup-eligible as a group.
Pass 2 covers Steps 7-9 (lines 1676-1688). These run on the post-synonym row set and are dedup-eligible as a second group.
Synonym split itself (line 1655) runs without dedup and is the hard boundary between passes.

**Integration point for `dedup_step()` in orchestrator** (current call pattern, lines 1580-1583):
```r
cas_result <- normalize_cas_fields(df_after_trim, tag_map)
df_after_cas <- cas_result$cleaned_data
audit_combined <- dplyr::bind_rows(audit_combined, cas_result$audit_trail)
```
With `dedup_step()` wrapper this becomes:
```r
cas_result <- dedup_step(normalize_cas_fields, df_after_trim, tag_map, cols = cas_cols)
df_after_cas <- cas_result$cleaned_data
audit_combined <- dplyr::bind_rows(audit_combined, cas_result$audit_trail)
```
The return shape is identical — no downstream changes needed.

**Integration point for pre-check in orchestrator** (current unicode step, lines 1550-1559):
```r
# Step 1: Unicode to ASCII (using ComptoxR for chemistry-specific mappings)
df_after_unicode <- df_after_lineage %>%
  dplyr::mutate(dplyr::across(tidyselect::where(is.character), ComptoxR::clean_unicode))

audit_unicode <- build_audit_trail(
  df_original = df_after_lineage,
  df_cleaned  = df_after_unicode,
  step_name   = "unicode_to_ascii",
  reason_fn   = function(field) paste0("Convert unicode characters to ASCII equivalents in ", field)
)
```
With pre-check wrapping, the pre-check runs first; if `should_run == FALSE`, Step 1 is replaced by the empty typed tibble and the `message()` log line, and `df_after_unicode <- df_after_lineage` (passthrough).

---

### Unit-key dedup in `R/unit_harmonizer.R`

**Role:** utility / performance optimization
**Data flow:** transform (lookup + broadcast multiply)
**Analog:** `R/unit_harmonizer.R` lines 398-435 — existing hash-map vectorized standard lookup

**Hash-map pattern to extend** (lines 398-413):
```r
if (any(standard_mask)) {
  # Build hash maps once: from_unit -> row index (O(m), not O(n*m))
  lookup_hash <- stats::setNames(seq_len(nrow(unit_map)), unit_map$from_unit)
  lookup_hash_ci <- stats::setNames(
    seq_len(nrow(unit_map)),
    tolower(unit_map$from_unit)
  )

  std_units   <- normalized[standard_mask]
  std_indices <- which(standard_mask)

  # Vectorized case-sensitive lookup (O(n))
  lookup_idx <- lookup_hash[std_units]
  ...
}
```

**Existing partial dedup for molarity (D-07 analog)** (lines 337-347 — shows the dedup key + broadcast pattern):
```r
unique_dtxsids <- unique(dtxsid_vec[needs_api_lookup])
...
fetched_mw <- fetch_molecular_weight(unique_dtxsids)
lookup_idx <- match(dtxsid_vec[needs_api_lookup], names(fetched_mw))
mw_vec[needs_api_lookup] <- fetched_mw[lookup_idx]
```

**Unit-key dedup extension (D-07):** For the standard path, construct a dedup key per row as the unit string alone (the numeric value is excluded from the key per D-07 since multiplication is O(1) vectorized). Compute the conversion factor once per distinct key using the existing hash lookup, then broadcast-multiply. For molarity the key is `paste(unit, mw)`. For ppx the key is `paste(unit, media)`. This extends the existing `stats::setNames` hash pattern.

**`harmonize_units()` output tibble schema** (lines 438-447 — must be preserved after dedup):
```r
tibble::tibble(
  orig_row_id      = as.integer(orig_row_id),
  orig_unit        = orig_unit,
  harmonized_value = harmonized_value,
  harmonized_unit  = harmonized_unit,
  conversion_factor = conversion_factor,
  unit_flag        = unit_flag
)
```

**Empty input passthrough** (lines 265-276 — must still work post-dedup):
```r
if (n == 0) {
  return(tibble::tibble(
    orig_row_id = integer(0), orig_unit = character(0),
    harmonized_value = numeric(0), harmonized_unit = character(0),
    conversion_factor = numeric(0), unit_flag = character(0)
  ))
}
```

---

## Shared Patterns

### Audit Trail Empty-Typed Return (SKIP-02)
**Source:** `R/cleaning_pipeline.R` lines 79-88 and lines 131-149 (multiple step functions)
**Apply to:** All pre-check skip paths, `dedup_step()` passthrough when uniqueness threshold bypasses dedup
```r
tibble::tibble(
  row_id         = integer(),
  field          = character(),
  step           = character(),
  original_value = character(),
  new_value      = character(),
  reason         = character()
)
```

### Pre-allocated Vector Audit Construction (CLAUDE.md performance guardrail)
**Source:** `R/cleaning_pipeline.R` lines 54-97 (`build_audit_trail`)
**Apply to:** `remap_audit_to_parent()`, any new predicate helpers that build partial audit vectors
- Never use `list()` that grows inside a loop with `[[length(x)+1]]`
- Pre-allocate with `integer()`, `character()` then `c()` append
- Single `tibble::tibble()` construction at end, never `dplyr::bind_rows()` inside a loop

### Hash-Map O(1) Lookup
**Source:** `R/unit_harmonizer.R` lines 73-84 (`apply_synonyms` exact-match section) and lines 398-413
**Apply to:** Unit-key dedup conversion factor cache in `harmonize_units()`
```r
lookup_hash <- stats::setNames(
  values_to_store,
  tolower(keys)
)
matches <- lookup_hash[tolower(query_keys)]
```

### Step Function Return Contract
**Source:** `R/cleaning_pipeline.R` lines 200-205 (`normalize_cas_fields`), lines 752-755 (`strip_terminal_unspecified`), lines 504-515 (`strip_terminal_enclosures`)
**Apply to:** Every step call site inside `dedup_step()` — the wrapper must accept and return the same `list(cleaned_data, audit_trail)` shape
```r
list(
  cleaned_data = df_result,
  audit_trail  = audit_trail   # 6-column tibble, possibly 0-row typed
)
```

### message() for Skip Decisions (D-04)
**Source:** `R/curate_headless.R` lines 126-143 (headless pipeline message pattern)
**Apply to:** All pre-check skip paths in `run_cleaning_pipeline()`
```r
message(sprintf("[headless] Detection: method=%s, confidence=%.2f, header_row=%d",
  detection$method, detection$confidence, detection$header_row))
```
Adapted for skip:
```r
message(sprintf("Step %s skipped -- pre-check FALSE", step_name))
```

---

## No Analog Found

All files have close matches. No entries in this section.

---

## Metadata

**Analog search scope:** `R/cleaning_pipeline.R` (2260 lines), `R/unit_harmonizer.R` (447 lines), `R/curate_headless.R` (351 lines), `R/mod_harmonize.R` (1187 lines), `tests/testthat/test-cleaning-pipeline.R`, `tests/testthat/test-unit-harmonizer.R`
**Files scanned:** 6 source files + REQUIREMENTS.md + ROADMAP.md + CONTEXT.md
**Pattern extraction date:** 2026-04-24
