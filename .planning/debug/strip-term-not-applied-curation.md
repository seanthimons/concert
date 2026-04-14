---
status: awaiting_human_verify
trigger: "strip-term-not-applied-curation"
created: 2026-03-12T00:00:00Z
updated: 2026-03-12T00:06:00Z
---

## Current Focus

hypothesis: Fix applied - curation now uses cleaned_data when available
test: Smoke test Shiny startup to ensure no syntax errors
expecting: App starts without errors
next_action: Request human verification with test workflow

## Symptoms

expected: Strip terms added in the cleaning module should carry through and be applied in the curation/review workflow as well.
actual: Strip terms are applied during cleaning but silently ignored during curation. No errors.
errors: None - silently ignored.
reproduction: Add a strip term in the cleaning UI, run cleaning (works), then proceed to curation (strip term not applied).
started: Current behavior - user discovered it during testing.

## Eliminated

## Evidence

- timestamp: 2026-03-12T00:01:00Z
  checked: R/curation.R (entire file)
  found: No references to reference_lists, strip_terms, stop_words, or block_patterns
  implication: Curation pipeline doesn't use reference lists at all - only cleaning pipeline does

- timestamp: 2026-03-12T00:01:30Z
  checked: R/cleaning_pipeline.R
  found: strip_reference_terms() function (lines 693-800) uses strip_terms_tbl parameter
  implication: Cleaning correctly applies strip terms

- timestamp: 2026-03-12T00:02:00Z
  checked: R/modules/mod_clean_data.R lines 199-204
  found: Cleaning module calls strip_reference_terms() with data_store$reference_lists$strip_terms
  implication: Cleaning module correctly passes strip terms to pipeline

- timestamp: 2026-03-12T00:03:00Z
  checked: PRE_POST_CURATION_PLAN.md architecture diagram (lines 9-28)
  found: Document shows cleaning is "PRE-curation", curation is separate, then POST-curation
  implication: By design, cleaning happens BEFORE curation as a separate workflow stage

- timestamp: 2026-03-12T00:04:00Z
  checked: R/modules/mod_run_curation.R line 153
  found: run_curation_pipeline is called with clean_data = data_store$clean (NOT data_store$cleaned_data)
  implication: Curation is using the WRONG input data - it uses pre-cleaning data, not post-cleaning data!

## Resolution

root_cause: R/modules/mod_run_curation.R line 153 passes `data_store$clean` to curation pipeline instead of `data_store$cleaned_data`. This means curation operates on the RAW uploaded data, completely bypassing all cleaning (including strip terms, quality adjectives, salt references, etc.). The cleaning workflow stores results in `data_store$cleaned_data`, but curation never reads from it.

fix: Change line 153 from `clean_data = data_store$clean` to `clean_data = data_store$cleaned_data %||% data_store$clean` (with fallback for when cleaning hasn't run)

verification:
- Smoke test: App loads without syntax errors ✓
- Next: Human verification required (see checkpoint below)
1. Run cleaning with custom strip term
2. Verify cleaned_data reflects the stripping
3. Run curation
4. Verify curation results use cleaned names (not original raw names)

files_changed:
- R/modules/mod_run_curation.R
