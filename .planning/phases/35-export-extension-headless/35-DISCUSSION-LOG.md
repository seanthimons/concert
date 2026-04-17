# Phase 35: Export Extension + Headless - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 35-export-extension-headless
**Areas discussed:** Export format behavior, Headless pipeline extension, Sheet 8 integration, Read-back validation

---

## Export Format Behavior

### Q1: Default export format when arrow is available

| Option | Description | Selected |
|--------|-------------|----------|
| Parquet preferred | Default to parquet when arrow available. Preserves typed NAs exactly. | |
| Always both | Write both parquet AND CSV side-by-side. Doubles I/O. | |
| Let user choose | Add format parameter ("parquet"/"csv"/"both") to headless + radio in UI. | ✓ |

**User's choice:** Let user choose
**Notes:** User wants explicit control over output format.

### Q2: Behavior when arrow is NOT installed

| Option | Description | Selected |
|--------|-------------|----------|
| Informative message + CSV fallback | Print message, write CSV instead. | |
| Warning + CSV fallback | Emit warning(), write CSV. | |
| Error — require arrow | Stop with error if arrow missing. | |
| Add arrow to Imports (user-proposed) | Make arrow a hard dependency, not Suggests. | ✓ |

**User's choice:** Add arrow to Imports (hard dependency)
**Notes:** Overrides SCHM-04 original design. Arrow is always available, no fallback logic needed. CSV becomes a format choice, not a fallback.

### Q3: File naming for ToxVal exports

| Option | Description | Selected |
|--------|-------------|----------|
| Match input name | `{input_basename}_toxval.parquet` / `.csv` | ✓ |
| User specifies full path | Explicit `toxval_output_path` parameter | |
| Claude decides | Let planner work out convention | |

**User's choice:** Match input name
**Notes:** None

---

## Headless Pipeline Extension

### Q4: How curate_headless() accepts numeric/harmonization tags

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing tag_map values | Add "Result", "Unit", "Qualifier", etc. alongside "Name"/"CASRN"/"Other" | ✓ |
| Separate numeric_tag_map parameter | Keep tag_map for chemical, add numeric_tag_map for numeric | |
| Claude decides | Let planner figure out cleanest API | |

**User's choice:** Extend existing tag_map values
**Notes:** Same parameter, richer vocabulary.

### Q5: Return value when harmonize=TRUE

| Option | Description | Selected |
|--------|-------------|----------|
| Extend return list | Add $toxval_output and $harmonize_audit alongside existing $data | |
| Replace $data with toxval output | $data becomes 56-col toxval tibble when harmonize=TRUE | ✓ |
| Claude decides | | |

**User's choice:** Replace $data with toxval output
**Notes:** Breaking change for harmonize=TRUE path, but backward compatible since harmonize defaults to FALSE.

### Q6: File formats in headless mode

| Option | Description | Selected |
|--------|-------------|----------|
| XLSX + ToxVal file | Keep 8-sheet XLSX plus separate parquet/CSV | ✓ |
| ToxVal file only | Skip XLSX when harmonize=TRUE | |
| Both always | Always write XLSX and toxval file | |

**User's choice:** XLSX + ToxVal file
**Notes:** Both outputs when harmonize=TRUE.

---

## Sheet 8 Integration

### Q7: When should Sheet 8 appear

| Option | Description | Selected |
|--------|-------------|----------|
| Only when harmonization ran | Conditional — stays at 7 sheets if no harmonization | |
| Always present | Include Sheet 8 even if empty (with note row) | ✓ |
| Claude decides | | |

**User's choice:** Always present
**Notes:** Empty sheet gets a note row like "Harmonization not run".

---

## Read-back Validation

### Q8: Parquet round-trip validation rigor

| Option | Description | Selected |
|--------|-------------|----------|
| Test-only | testthat round-trip test, no runtime check | ✓ |
| Runtime + test | Read-back assertion at export time plus tests | |
| Claude decides | | |

**User's choice:** Test-only
**Notes:** None

---

## Claude's Discretion

- Internal helper function organization for export logic
- Exact parameter names for harmonization context (unit_map, corrections, media)
- Test case selection beyond round-trip requirement
- Radio button placement and label text in UI
- Error message wording

## Deferred Ideas

None — discussion stayed within phase scope.
