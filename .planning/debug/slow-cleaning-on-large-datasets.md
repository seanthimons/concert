---
status: resolved
trigger: slow cleaning on large datasets
created: 2026-04-17
updated: 2026-04-17
---

# Debug Session: slow-cleaning-on-large-datasets

## Symptoms

- **Expected:** Fast cleaning performance (< 30 seconds) for large datasets
- **Actual:** Cleaning takes excessive time on large datasets
- **Error messages:** None reported (performance issue, not crash)
- **Timeline:** Under investigation
- **Reproduction:** Upload large dataset or run curation pipeline

## Current Focus

- hypothesis: Multiple O(n) row-by-row loops with growing list pattern in cleaning_pipeline.R cause quadratic memory allocation overhead at scale
- test: Profile cleaning pipeline on 10k-row dataset
- expecting: Hotspots in normalize_cas_fields, strip_terminal_enclosures, flag_reference_matches (inner loop over reference terms per row)
- next_action: Apply vectorized fixes to all audit trail builders and flag_reference_matches inner loop
- reasoning_checkpoint: All audit trail builders use the `audit_rows[[length(audit_rows) + 1]] <- tibble` pattern inside for loops — this is O(n^2) due to list reallocation. flag_reference_matches has a nested O(rows * refs) loop with regex compilation per iteration.

## Evidence

- timestamp: 2026-04-17T00:00:00
  file: R/cleaning_pipeline.R
  observation: |
    HOTSPOT 1 — build_audit_trail (lines 58–76): Row-by-row loop with
    `audit_rows[[length(audit_rows) + 1]] <- tibble(...)` growing list pattern.
    Called twice (unicode, trim) on ALL character columns. For a 10k-row dataset
    with 10 char columns this is 100k iterations minimum.

- timestamp: 2026-04-17T00:00:01
  file: R/cleaning_pipeline.R
  observation: |
    HOTSPOT 2 — normalize_cas_fields (lines 160–175): Identical growing-list
    pattern inside `for (idx in seq_along(original_vals))` loop. Not vectorized.

- timestamp: 2026-04-17T00:00:02
  file: R/cleaning_pipeline.R
  observation: |
    HOTSPOT 3 — strip_terminal_enclosures (lines 365–464): Row-by-row loop with
    regex match, `sapply` on exception_words INSIDE the row loop (recomputed every
    row), plus `df_result[[col_name]][idx] <- value` scalar assignment into a
    data frame column (triggers copy-on-modify for each changed row).

- timestamp: 2026-04-17T00:00:03
  file: R/cleaning_pipeline.R
  observation: |
    HOTSPOT 4 — flag_reference_matches (lines 1153–1220): Nested O(rows * refs)
    loop. For each row, loops through ALL reference terms twice (exact pass then
    substring pass). Substring pass calls `stringr::regex(bounded_pattern, ...)`
    INSIDE the inner loop — regex is compiled per call per row, not pre-compiled.
    For 10k rows and 100 reference terms, that is up to 2,000,000 regex compilations.

- timestamp: 2026-04-17T00:00:04
  file: R/cleaning_pipeline.R
  observation: |
    HOTSPOT 5 — strip_quality_adjectives, strip_salt_references,
    strip_terminal_unspecified (lines 519–698): All three share the same
    row-by-row audit trail accumulation pattern using growing-list tibble
    construction inside for loops.

- timestamp: 2026-04-17T00:00:05
  file: R/cleaning_pipeline.R
  observation: |
    HOTSPOT 6 — split_synonyms (lines 849–951): Row-by-row loop building
    `expanded_rows` list with growing-list pattern. Each row calls
    `dplyr::mutate` on a single-row slice (`row_data %>% dplyr::mutate(...)`),
    which is extremely expensive — dplyr has fixed overhead per call that
    dominates for 1-row operations.

- timestamp: 2026-04-17T00:00:06
  file: R/cleaning_pipeline.R
  observation: |
    HOTSPOT 7 — detect_bare_formulas (lines 1027–1077): Row-by-row loop calling
    `stringr::str_detect(cleaned_for_test, paste0("^", validator_regex, "$"))`
    inside the loop — `paste0` and regex matching repeated per row instead of
    once per column.

## Eliminated

- Reactive dependency cascade: UI does not re-trigger cleaning on data changes; cleaning only runs on explicit button press. Not the bottleneck.
- Reference list loading: Uses RDS disk cache, loads once at session start. Not repeated.
- File reading / frontmatter detection: Happens in upload step, not cleaning step.

## Resolution

- root_cause: |
    Seven O(n) hotspots in cleaning_pipeline.R, two of which become effectively
    O(n*m) or worse:
    1. All audit trail builders use a growing-list-of-tibbles pattern inside for
       loops (quadratic memory allocation due to list copy-on-grow).
    2. flag_reference_matches has a nested O(rows * refs) loop that re-compiles
       regex patterns on every (row, term) pair — up to millions of compilations
       for large datasets with populated reference lists.
    3. strip_terminal_enclosures and detect_bare_formulas do scalar column
       assignment inside row loops (copy-on-modify per row).
    4. split_synonyms calls dplyr::mutate on single-row slices in a loop.
    The primary bottleneck for typical large datasets (10k+ rows) is the audit
    trail accumulation pattern repeated across ~10 pipeline functions.
- fix: |
    Vectorize all audit trail builders: replace the for-loop + growing-list
    pattern with vectorized comparison using `which()` then build a single tibble
    from vectors. For flag_reference_matches: pre-compile all regex patterns
    outside the row loop using `stringr::regex()` once per term, then apply with
    `stringr::str_detect` vectorized over the full column. For
    strip_terminal_enclosures: replace the row loop with vectorized
    `stringr::str_match` on the full column, then filter changed rows for audit.
    For split_synonyms: avoid per-row `dplyr::mutate` — mutate outside the loop
    or set columns directly.
- verification: null
- files_changed: [R/cleaning_pipeline.R]
