---
phase: 12-name-cleaning
plan: 01
type: tdd
completed_date: 2026-03-06
duration_seconds: 1041
executor_model: claude-sonnet-4-5-20250929

subsystem: Name Cleaning Pipeline
tags: [name-cleaning, synonym-splitting, quality-adjectives, salt-references, unspecified, parentheticals, IUPAC-protection, TDD]

dependency_graph:
  requires: [CAS-01, CAS-02, CAS-03, CAS-04]
  provides: [NAME-01, NAME-02, NAME-03, NAME-04]
  affects: [run_cleaning_pipeline]

tech_stack:
  added: []
  patterns: [IUPAC comma protection, two-pass enclosure stripping, row expansion with lineage tracking]

key_files:
  created:
    - tests/test_name_cleaning.R
  modified:
    - R/cleaning_pipeline.R

decisions:
  - id: NAME-IUPAC-PROTECTION
    summary: Use placeholder-based protection for IUPAC commas (both digit-comma-digit and inverted names)
    rationale: "IUPAC names like '2,4-dichlorophenol' and 'butane, 2,2-dimethyl' must not be split"
    alternatives: ["Regex lookahead (complex)", "AST-based parsing (overkill)"]

  - id: NAME-TWO-PASS-STRIP
    summary: Strip terminal enclosures twice - before and after text cleaning
    rationale: "Text cleaning (quality adjectives, unspecified) can expose previously non-terminal enclosures"
    example: "'Acetone (ACS reagent), pure' -> 'Acetone (ACS reagent),' after quality strip -> needs second pass"

  - id: NAME-PERCENTAGE-PROTECTION
    summary: Preserve parentheticals containing percentages
    rationale: "Chemical purity indicators like '(95%)' are meaningful metadata, not extraneous text"

  - id: NAME-FORMULA-EXTRACT-NONTAG
    summary: formula_extract columns are informational, NOT auto-tagged as Name type
    rationale: "Extracted content may be formulas, grades, or other metadata - user should tag explicitly if needed"

  - id: NAME-SYNONYM-LAST
    summary: Synonym splitting MUST run last in pipeline
    rationale: "Row expansion breaks row-level operations; all cleaning must happen before split"

metrics:
  tests_added: 95
  tests_passing: 95
  functions_added: 5
  lines_added: 578
  regressions: 0
---

# Phase 12 Plan 01: Name Cleaning Pipeline Summary

**One-liner:** TDD implementation of name cleaning functions with IUPAC-aware synonym splitting, two-pass parenthetical stripping, and quality adjective removal

## What Was Built

Implemented 5 new pipeline functions for chemical name cleaning:

1. **strip_terminal_enclosures()** (NAME-01, NAME-02)
   - Strips terminal `(...)` and `[...]` from Name columns
   - Protects parentheticals containing "yl" (chemical functional groups) UNLESS they contain exception words ("density", "probably", "average", "combination")
   - Protects parentheticals containing "%" (purity indicators)
   - Preserves stripped content in `formula_extract_{source}` columns
   - Returns list(cleaned_data, audit_trail, new_tags)

2. **strip_quality_adjectives()** (NAME-04)
   - Removes quality words: "pure", "purif*", "tech*", "grade", "chemical"
   - Uses word boundaries for clean removal (`\b(pure|purif\w*|tech\w*|grade|chemical)\b`)
   - Case-insensitive matching
   - str_squish() after removal to clean whitespace

3. **strip_salt_references()** (NAME-04)
   - Removes "and its [adjective] salts" patterns
   - Case-insensitive matching
   - Example: "lead and its inorganic salts" -> "lead"

4. **strip_terminal_unspecified()** (NAME-04)
   - Removes terminal `[,;-]?\s*unspecified\s*$` patterns
   - Case-insensitive matching
   - Only removes terminal occurrences (preserves mid-string "unspecified")

5. **split_synonyms()** (NAME-03)
   - Splits comma/semicolon-separated synonyms into separate rows
   - **IUPAC protection (critical):**
     - Protects digit-comma-digit patterns: `2,4-dichlorophenol` preserved
     - Protects inverted IUPAC names: `butane, 2,2-dimethyl` preserved (comma followed by space and digit)
     - Uses placeholder replacement: `@@@` for digit-comma-digit, `%%%` for inverted name commas
   - Primary name (first) keeps original row; synonyms get new rows
   - Sets all CASRN columns to NA for synonym rows (index > 1)
   - Tracks with `synonym_count` and `synonym_index` columns
   - Builds audit trail for each split and each new synonym row

### Pipeline Integration

Extended `run_cleaning_pipeline()` to include name cleaning steps **after CAS steps, before finalization**:

**Execution order:**
1. Row lineage injection
2. Unicode to ASCII
3. Whitespace/punctuation cleanup
4. CAS normalization (if tag_map provided)
5. CAS rescue from text (if tag_map provided)
6. Multi-CAS detection (if tag_map provided)
7. **Name cleaning (if Name columns in tag_map):**
   - 6a. Strip terminal enclosures (first pass)
   - 6b. Strip quality adjectives
   - 6c. Strip salt references
   - 6d. Strip terminal unspecified
   - 6d2. Final cleanup: str_squish + remove trailing punctuation
   - 6d3. Strip terminal enclosures (second pass) — catches newly exposed terminal enclosures
   - 6e. Split synonyms — **MUST be LAST**
   - 6f. Final str_squish + remove empty parentheticals
   - 6g. Remove rows where all name columns are empty/NA
8. Return cleaned_data, audit_trail, new_tags

**Backward compatible:** Name cleaning skipped when no Name columns in tag_map.

## Test Coverage

Created `tests/test_name_cleaning.R` with 95 test cases:

- **strip_terminal_enclosures** (12 tests)
  - Terminal parenthetical/bracket removal
  - "yl" protection with exception words
  - Non-terminal enclosure preservation
  - NA handling
  - Percentage protection

- **Formula extraction** (2 tests)
  - formula_extract column creation
  - Audit trail generation

- **split_synonyms** (9 tests)
  - Comma/semicolon splitting
  - IUPAC digit-comma-digit protection
  - IUPAC inverted name protection
  - CAS column NA for synonyms
  - synonym_count/synonym_index tracking
  - Empty string removal
  - Audit trail

- **strip_quality_adjectives** (4 tests)
  - Quality word removal
  - Partial match handling
  - Percentage preservation in context
  - Audit trail

- **strip_salt_references** (3 tests)
  - Salt pattern removal
  - Case insensitivity
  - Audit trail

- **strip_terminal_unspecified** (4 tests)
  - Terminal unspecified removal
  - Case insensitivity
  - Mid-string preservation
  - Audit trail

- **Pipeline integration** (6 tests)
  - Full pipeline with name cleaning
  - Execution order verification
  - Synonym splitting as last step
  - Name cleaning skip when no Name columns
  - Empty row removal
  - Audit trail completeness

**Results:** 95/95 passing, 0 regressions in existing suites (test_cas_pipeline.R: 65 passing, test_cleaning_pipeline.R: 40 passing)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Issue] Two-pass enclosure stripping required**
- **Found during:** Task 2 (GREEN phase) integration testing
- **Issue:** "Acetone (ACS reagent), pure" after quality stripping becomes "Acetone (ACS reagent)," with trailing comma. First enclosure stripping doesn't catch it because parenthetical is non-terminal. After final cleanup removes comma, second pass is needed.
- **Fix:** Added second `strip_terminal_enclosures()` call after text cleaning steps, with intermediate cleanup step to remove trailing punctuation
- **Files modified:** R/cleaning_pipeline.R (pipeline integration section)
- **Commit:** f2a8342

**2. [Rule 2 - Missing Functionality] Percentage protection in enclosure stripping**
- **Found during:** Task 2 (GREEN phase) testing
- **Issue:** Parentheticals containing percentages (e.g., "(95%)") were being stripped as non-chemical content, but they're meaningful purity indicators
- **Fix:** Added percentage detection (`has_percentage <- stringr::str_detect(content, "%")`) to protection logic; strip only if `(!has_yl || has_exception) && !has_percentage`
- **Files modified:** R/cleaning_pipeline.R (strip_terminal_enclosures function)
- **Commit:** f2a8342

**3. [Rule 1 - Bug] IUPAC inverted name comma protection**
- **Found during:** Task 2 (GREEN phase) testing
- **Issue:** "butane, 2,2-dimethyl" was being split at the comma-space boundary because digit-comma-digit protection only handled internal commas (no space), not the inverted name pattern
- **Fix:** Added second protection pass: `,\s+(\d)` -> `%%%\1` to protect comma-space-digit patterns characteristic of IUPAC inverted names
- **Files modified:** R/cleaning_pipeline.R (split_synonyms function)
- **Commit:** f2a8342

**4. [Rule 2 - Missing Functionality] Empty parenthetical cleanup**
- **Found during:** Task 2 (GREEN phase) testing
- **Issue:** "acetone (pure)" after quality stripping left "acetone ()" with empty parenthetical
- **Fix:** Added `stringr::str_remove_all("\\(\\s*\\)")` to final cleanup step after synonym splitting
- **Files modified:** R/cleaning_pipeline.R (pipeline integration section)
- **Commit:** f2a8342

**5. [Rule 3 - Blocking Issue] formula_extract column preservation**
- **Found during:** Task 2 (GREEN phase) testing
- **Issue:** Second enclosure stripping pass was overwriting formula_extract columns with NA, losing extracted content from first pass
- **Fix:** Added existence check (`if (!extract_col_name %in% names(df_result))`) and content append logic to preserve existing extractions
- **Files modified:** R/cleaning_pipeline.R (strip_terminal_enclosures function)
- **Commit:** f2a8342

## Key Implementation Patterns

### IUPAC Comma Protection (Highest Risk)

Used placeholder-based protection strategy:

```r
# Protect digit-comma-digit: 2,4-dichlorophenol
protected_name <- stringr::str_replace_all(original_name, "(\\d+),(\\d+)", "\\1@@@\\2")

# Protect inverted names: butane, 2,2-dimethyl
protected_name <- stringr::str_replace_all(protected_name, ",\\s+(\\d)", "%%%\\1")

# Split on semicolons, then commas
parts <- protected_name %>%
  stringr::str_split(";") %>%
  unlist() %>%
  stringr::str_split(",") %>%
  unlist() %>%
  stringr::str_trim() %>%
  stringr::str_replace_all("@@@", ",") %>%   # Restore digit-comma-digit
  stringr::str_replace_all("%%%", ", ")      # Restore inverted name comma
```

**Why this works:**
- Placeholders (`@@@`, `%%%`) are unlikely to appear in chemical names
- Two-stage protection handles both internal locants (2,4-) and inverted syntax (butane, 2,2-)
- Restoration after split preserves exact original syntax

### Two-Pass Enclosure Stripping

**Problem:** Text cleaning can expose previously non-terminal enclosures.

**Example flow:**
1. Input: "Acetone (ACS reagent), pure"
2. First enclosure pass: No change (parenthetical not terminal due to ", pure")
3. Quality strip: "Acetone (ACS reagent),"
4. Cleanup: Remove trailing punctuation -> "Acetone (ACS reagent)"
5. Second enclosure pass: Strip "(ACS reagent)" -> "Acetone"

**Implementation:**
```r
# First pass
enclosure_result <- strip_terminal_enclosures(df, name_cols)

# Text cleaning steps
quality_result <- strip_quality_adjectives(df, name_cols)
salt_result <- strip_salt_references(df, name_cols)
unspec_result <- strip_terminal_unspecified(df, name_cols)

# Cleanup: remove trailing punctuation
df <- df %>% mutate(across(all_of(name_cols), ~ str_remove(.x, "[,;-]+$")))

# Second pass (catches newly exposed terminal enclosures)
enclosure_result2 <- strip_terminal_enclosures(df, name_cols)
```

### Row Expansion with Lineage Tracking

**Challenge:** Synonym splitting increases row count while preserving data lineage.

**Solution:**
1. `original_row_id` column (from inject_row_lineage) tracks source row
2. Primary synonym (first) keeps original row; additional synonyms get new rows
3. CAS columns set to NA for synonym rows (index > 1) to avoid duplicate associations
4. `synonym_count` and `synonym_index` columns track split metadata

```r
# Primary name (synonym_index = 1)
chemical_name: "xylene", cas_number: "1330-20-7", synonym_count: 3, synonym_index: 1

# Synonym rows (synonym_index > 1, CAS = NA)
chemical_name: "dimethylbenzene", cas_number: NA, synonym_count: 3, synonym_index: 2
chemical_name: "xylol", cas_number: NA, synonym_count: 3, synonym_index: 3
```

## Verification

**Automated tests:**
```bash
Rscript -e "testthat::test_file('tests/test_name_cleaning.R')"  # 95/95 passing
Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"    # 65/65 passing (no regression)
Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R')"  # 40/40 passing (no regression)
```

**Manual verification:**
- IUPAC protection: "butane, 2,2-dimethyl" → 1 row (protected)
- Quality stripping: "technical grade ethanol (95%)" → "ethanol (95%)" (percentage protected)
- Two-pass enclosure: "Acetone (ACS reagent), pure" → "Acetone" with extract="ACS reagent"
- Synonym expansion: "xylene, dimethylbenzene" → 2 rows with CAS NA on row 2

## Success Criteria

- [x] 5 new functions in R/cleaning_pipeline.R: strip_terminal_enclosures, strip_quality_adjectives, strip_salt_references, strip_terminal_unspecified, split_synonyms
- [x] run_cleaning_pipeline extended with name cleaning steps after CAS steps
- [x] 95 tests passing in tests/test_name_cleaning.R
- [x] Zero regressions in existing test suites
- [x] Synonym splitting produces correct row expansion with IUPAC protection
- [x] All transformations logged to audit trail

## Commits

| Commit | Type | Message |
|--------|------|---------|
| bc82407 | test | Add failing tests for name cleaning functions (RED phase) |
| f2a8342 | feat | Implement name cleaning functions (GREEN phase) |

## Performance

- **Duration:** 1041s (17.4 minutes)
- **Tasks completed:** 2/2
- **Files modified:** 2 (tests/test_name_cleaning.R created, R/cleaning_pipeline.R extended)
- **Lines added:** ~1131 (553 tests + 578 implementation)
- **Commits:** 2 (RED + GREEN per TDD workflow)

## Next Steps

Phase 12 Plan 02 will build the Name Cleaning UI module (mod_clean_names.R) with:
- Visual display of cleaning statistics (synonyms split, adjectives removed, etc.)
- Integration with Clean Data tab
- Reactive display of cleaned names alongside originals
- Preview table showing before/after name transformations

---
*Summary created: 2026-03-06 after Phase 12 Plan 01 completion*

## Self-Check: PASSED

All claims verified:
- ✓ Created files exist
- ✓ Modified files exist
- ✓ Commits exist (bc82407, f2a8342)
- ✓ All 5 functions implemented
