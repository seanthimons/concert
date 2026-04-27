# Phase 40: Date Parser - Research

**Researched:** 2026-04-26
**Domain:** lubridate date parsing, tag system extension, pipeline stage insertion
**Confidence:** HIGH — all critical claims verified by live R session against lubridate 1.9.4

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01/D-02:** Parse order YMD → MDY → DMY (plus SAS, year-only, month-year). ISO priority, then US, then European.
- **D-03/D-04:** Partial dates impute missing components to 1. "2015" → 2015-01-01, "Mar 2015" → 2015-03-01. `date_year` always populated.
- **D-05:** `date_year` is always populated from available year, even on partial flag.
- **D-06:** Ambiguous dates surface in QC dashboard value box + harmonization audit. Advisory only — does not gate export.
- **D-07:** No new ToxVal schema column. `date_flag` lives in audit/QC layer only.
- **D-08:** 2-digit years use custom cutoff — threshold value at Claude's discretion.
- **D-09:** ALL 2-digit year inputs get `date_flag = "inferred_format"` regardless of cutoff result.
- **D-10:** Unparseable → `parsed_date = NA`, `date_year = NA`, `date_flag = "unparseable"`. Raw string preserved in audit.
- **D-11:** Consistent with `harmonize_units()` — pass-through with flag, no data loss.
- **D-12:** `parse_dates()` is dedup-eligible via `dedup_step()` at orchestrator level.
- **D-13:** New `study_types` group in `classify_tags()` containing `"StudyDate"`.
- **D-14:** Tag Columns dropdown gets a third optgroup label "Study / Contextual".
- **D-15:** Single `StudyDate` tag — no companion format hint tag.
- **D-16:** Date results merge into `expanded_curated` BEFORE `map_to_toxval_schema()`.
- **D-17:** Date parsing is a new pipeline stage after duration, before ToxVal mapping.
- **D-18:** `curate_headless()` gains Stage 3c conditional call for StudyDate-tagged columns.

### Claude's Discretion
- Exact `orders` vector for `lubridate::parse_date_time()`
- Specific 2-digit year cutoff value for `cutoff_2000`
- Stage numbering and progress bar percentages in `mod_harmonize.R`
- Internal implementation of `parse_dates()` — vectorized vs. row-level detection
- Test structure for DATE-03 ambiguity detection and DATE-02 output schema
- QC dashboard value box placement and label text
- How `study_types` integrates with the optgroup rendering in `mod_tag_columns.R`

### Deferred Ideas (OUT OF SCOPE)
- Date range parsing ("1990-1995", "Jan-Mar 2020") → DFUT-01
- DateFormat companion tag for per-dataset format override
- `study_duration_class` population based on parsed dates + durations
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DATE-01 | `parse_dates()` in `R/date_parser.R` handles ISO, MDY, DMY, SAS, YYYYMMDD, year-only, 2-digit year via `lubridate::parse_date_time()` | Verified orders vector below; train=FALSE required for heterogeneous columns |
| DATE-02 | Returns tibble with `orig_row_id`, `raw_date`, `parsed_date`, `date_year`, `date_flag` | Output schema pattern matches `harmonize_units()` tibble |
| DATE-03 | Ambiguous dates (day <= 12 AND month <= 12) flagged in audit | Post-parse check on `lubridate::day()` and `lubridate::month()` of result |
| DATE-04 | `StudyDate` tag type added to `classify_tags()`; Harmonize tab routes tagged columns through `parse_dates()` | `classify_tags()` at `R/tag_helpers.R:35` — add `study_types` group; UI-SPEC confirms optgroup rename |
| DATE-05 | `curate_headless()` gains Stage 3c conditional call for StudyDate-tagged columns | Template at `curate_headless.R:275-295` (Stage 3.5 duration) |
| DATE-06 | `map_to_toxval_schema()` populates `original_year` from `date_year` output | `toxval_mapper.R:153` — `safe_extract_num(curated_data, "year", n_rows)`. Date stage must add a `year` column to `expanded_curated`. |
</phase_requirements>

---

## Summary

Phase 40 adds date parsing as a new harmonization pipeline stage. The core function `parse_dates()` uses `lubridate::parse_date_time()` with `train=FALSE` to handle heterogeneous date formats in a single column. The key architectural finding is that `train=TRUE` (the default) fits a single format across the entire input vector — this produces wrong parses for mixed-format columns (e.g., "Jan 2015" parsed as 2015-01-20 when MDY format dominates). `train=FALSE` tries each order independently per value, which is correct for regulatory data.

The integration pattern exactly mirrors the duration stage (Phase 39): new function in a new file → conditional call in `mod_harmonize.R` after Stage 4.5 → merge into `expanded_curated` before ToxVal map → same block in `curate_headless.R` as Stage 3c. The `original_year` field is already wired in `toxval_mapper.R:153` via `safe_extract_num(curated_data, "year", n_rows)` — the date stage must add a `year` column to `expanded_curated`.

`lubridate` is currently in `Suggests` in DESCRIPTION. It must move to `Imports`. [VERIFIED: DESCRIPTION file]

**Primary recommendation:** Implement `parse_dates()` using `parse_date_time(..., train=FALSE)` with the verified orders vector. Flag ambiguity post-parse via day/month check. Wire exactly like duration, with `year` column added to `expanded_curated`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Date string parsing + flag assignment | `R/date_parser.R` | — | Pure data transformation, no UI dependency |
| Ambiguity detection | `R/date_parser.R` | — | Post-parse column check, belongs with parsing logic |
| Tag classification (`StudyDate`) | `R/tag_helpers.R` | `R/mod_tag_columns.R` | `classify_tags()` is single source of truth per design |
| Optgroup UI update | `R/mod_tag_columns.R` | — | Dropdown rendering, follows existing optgroup pattern |
| Pipeline stage (Shiny) | `R/mod_harmonize.R` | — | Stage 4.6 after duration (Stage 4.5) |
| Pipeline stage (headless) | `R/curate_headless.R` | — | Stage 3c after duration (Stage 3.5) |
| ToxVal `original_year` population | `R/toxval_mapper.R` | — | Already wired via `safe_extract_num(..., "year", ...)` — no change needed in mapper |
| QC dashboard value boxes | `R/mod_harmonize.R` | — | Conditional render inside existing `qc_dashboard` output |

---

## Standard Stack

### Core
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| lubridate | 1.9.4 | Date parsing via `parse_date_time()` | Currently in `Suggests` — **must move to `Imports`** |

[VERIFIED: `packageVersion("lubridate")` = 1.9.4 in project R session]

**DESCRIPTION change required:**
```
# Move from Suggests to Imports:
lubridate,
```

### Supporting (already imported)
| Library | Purpose |
|---------|---------|
| tibble | Output tibble construction |
| dplyr | Column operations in pipeline merge |
| purrr | `safely()` wrapper for error isolation |

---

## lubridate API Findings

### Critical: `train=FALSE` is Required

`parse_date_time()` defaults to `train=TRUE`, which selects a single "best" format by training across the entire input vector. For heterogeneous date columns this is wrong:

```r
# WRONG (train=TRUE default): "Jan 2015" parsed as 2015-01-20 (mdy wins training)
parse_date_time(c("Jan 2015", "03/15/2015"), orders=c("bY","mdy"), quiet=TRUE)
# -> c("2015-01-20", "2015-03-15")

# CORRECT (train=FALSE): each value tried against orders independently
parse_date_time(c("Jan 2015", "03/15/2015"), orders=c("bY","mdy"), train=FALSE, quiet=TRUE)
# -> c("2015-01-01", "2015-03-15")
```

[VERIFIED: Live R session, lubridate 1.9.4]

### Verified Orders Vector

```r
orders <- c("ymd", "Ymd", "bY", "BY", "dBY", "BdY", "mdy", "dmy", "Y", "Ym")
```

Order rationale (matters with `train=FALSE` — first match wins):
1. `"ymd"` — ISO standard, highest priority (D-01)
2. `"Ymd"` — YYYYMMDD compact form (e.g., "20150315")
3. `"bY"`, `"BY"` — named month + year BEFORE `"mdy"` — prevents "Jan 2015" → mdy misparse
4. `"dBY"`, `"BdY"` — SAS format (15JAN1985, JAN 15 1985)
5. `"mdy"` — US convention (D-01/D-02)
6. `"dmy"` — European (D-02 fallback)
7. `"Y"` — year-only (D-03)
8. `"Ym"` — month-year numeric (2015-03)

[VERIFIED: Full test suite in R session — all formats parse correctly with this order]

### Partial Date Handling via `train=FALSE`

`parse_date_time()` with `"Y"` and `"Ym"` orders imputes to January 1st automatically:

```r
parse_date_time("2015", orders="Y", train=FALSE, quiet=TRUE)  # -> 2015-01-01
parse_date_time("2015-03", orders="Ym", train=FALSE, quiet=TRUE)  # -> 2015-03-01
```

No `truncated` parameter needed — the orders-based approach handles this correctly. [VERIFIED]

### 2-Digit Year Handling

`cutoff_2000` is **NOT** a parameter of `parse_date_time()` — it exists only in `fast_strptime()`. [VERIFIED: `formals(parse_date_time)` has no `cutoff_2000`]

`parse_date_time()` uses R's base `strptime` behavior: year < 69 → 2000+year, year >= 69 → 1900+year. This is equivalent to a `cutoff_2000 = 68` default. For regulatory data spanning 1950-2030, this is acceptable.

**Implementation strategy per D-08/D-09:** Detect 2-digit year inputs via regex pre-scan, flag as `"inferred_format"`, then let `parse_date_time()` apply its default cutoff:

```r
# Detect 2-digit year pattern in raw string
has_2digit_year <- grepl("[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}\\b", raw_date, perl = TRUE)
# If TRUE -> date_flag = "inferred_format" (regardless of parse result)
```

The "cutoff" Claude selects is effectively the library default (68). Document this choice explicitly in code comments.

### Ambiguity Detection

Post-parse, using `lubridate::day()` and `lubridate::month()`:

```r
is_ambiguous <- !is.na(parsed) &
  lubridate::day(parsed) <= 12 &
  lubridate::month(parsed) <= 12
```

Note: ambiguity and partial flags are not mutually exclusive. Priority order for `date_flag`:
`"unparseable"` > `"partial"` > `"inferred_format"` > `"ambiguous"` > `""`

A year-only "2015" result has day=1, month=1 — both <= 12 — so without the partial check first, it would also get flagged ambiguous. The partial check must occur before ambiguity.

---

## Integration Points (Exact Lines)

### 1. `R/tag_helpers.R` — `classify_tags()` (line 35–82)

Current membership vectors at lines 37–39:
```r
chemical_types <- c("Name", "CASRN", "Other")
numeric_types  <- c("Result", "Unit", "Qualifier", "Duration", "DurationUnit")
metadata_types <- c("Species", "ExposureRoute")
```

**Required change:** Add `study_types <- c("StudyDate")` and a fourth partition (`study_type_idx`). The return list gains `study_type_tags`. Every caller that destructures `classify_tags()` output needs updating.

The empty return at lines 44–48 also needs a `study_type_tags = list()` slot.

### 2. `R/mod_tag_columns.R` — Optgroup dropdown (lines 84–91)

Current structure:
```r
"Study" = c("Duration" = "Duration", "Duration Unit" = "DurationUnit",
            "Species" = "Species", "Exposure Route" = "ExposureRoute")
```

**Required change:** Rename optgroup key to `"Study / Contextual"`, add `"Study Date" = "StudyDate"` entry.

Per UI-SPEC: existing "Study" optgroup is renamed, not a new group added. Duration, DurationUnit, Species, ExposureRoute, and StudyDate all go in "Study / Contextual".

### 3. `R/mod_harmonize.R` — Stage insertion (after line 406)

Duration stage ends at line 406. Date stage slots in as Stage 4.6 between duration (4.5) and ToxVal mapping (Stage 5, line 408):

```r
# Stage 4.6: Date parsing (DATE-01, DATE-05)
incProgress(0.05, detail = "Parsing dates...")
study_type_tags_vec <- unlist(data_store$study_type_tags)
date_cols <- names(study_type_tags_vec)[study_type_tags_vec == "StudyDate"]
data_store$date_results <- NULL

if (length(date_cols) > 0) {
  date_tibble <- parse_dates(
    raw_dates = as.character(input_df[[date_cols[1]]]),
    orig_row_id = seq_len(nrow(input_df))
  )
  data_store$date_results <- date_tibble
}
```

Then merge into `expanded_curated` before ToxVal map (mirror of duration merge at lines 415–430):

```r
if (!is.null(data_store$date_results)) {
  year_expanded <- data_store$date_results$date_year[harmonize_tibble$orig_row_id]
  expanded_curated$year <- year_expanded
}
```

### 4. `R/toxval_mapper.R` — `original_year` (line 153)

```r
original_year = safe_extract_num(curated_data, "year", n_rows)
```

No change needed — this already reads from `curated_data$year`. The date stage just needs to populate `expanded_curated$year` before the mapper is called.

### 5. `R/curate_headless.R` — Stage 3c (after line 294)

Duration stage ends at line 294. Headless date path mirrors exactly:

```r
# Stage 3c: Date parsing (DATE-05, DATE-06)
message("[headless] Stage 3c: Parsing dates...")
date_cols <- names(tag_map)[tag_map == "StudyDate"]

if (length(date_cols) > 0) {
  date_tibble <- parse_dates(
    raw_dates = as.character(input_df[[date_cols[1]]]),
    orig_row_id = seq_len(nrow(input_df))
  )
  input_df$year <- date_tibble$date_year[
    match(seq_len(nrow(input_df)), date_tibble$orig_row_id)
  ]
}
```

### 6. `R/date_parser.R` — New file

Output tibble schema (DATE-02):
```r
tibble::tibble(
  orig_row_id = integer(),
  raw_date    = character(),
  parsed_date = character(),   # ISO-8601 "YYYY-MM-DD" or NA
  date_year   = integer(),     # year(parsed_date) or NA
  date_flag   = character()    # "" | "partial" | "inferred_format" | "ambiguous" | "unparseable"
)
```

---

## Common Pitfalls

### Pitfall 1: `train=TRUE` Gives Wrong Month for "Jan 2015"
**What goes wrong:** With `train=TRUE` (default), MDY format trains as dominant when numeric slash-separated dates are present. "Jan 2015" then parses as month=Jan, day=20, year=15 → 2015-01-20.
**How to avoid:** Always use `train=FALSE`. [VERIFIED]

### Pitfall 2: `bY` Must Precede `mdy` in Orders Vector
**What goes wrong:** Even with `train=FALSE`, if `"mdy"` is tried before `"bY"`, "Jan 2015" matches MDY as m=Jan, d=20, y=15.
**How to avoid:** Put `"bY"` and `"BY"` before `"mdy"` in the orders vector. [VERIFIED]

### Pitfall 3: `cutoff_2000` Does Not Exist in `parse_date_time()`
**What goes wrong:** Passing `cutoff_2000` to `parse_date_time()` throws "unused argument" error.
**How to avoid:** Use regex to detect 2-digit year inputs before parsing; flag them as `"inferred_format"`. The library default (cutoff=68) applies automatically. [VERIFIED]

### Pitfall 4: Year-Only / Month-Year Dates Flag as Ambiguous Without Priority Check
**What goes wrong:** "2015" → parsed as 2015-01-01 → day=1 <=12, month=1 <=12 → ambiguous flag fires incorrectly.
**How to avoid:** Assign `"partial"` flag before ambiguity check. Ambiguity check only applies to fully-specified dates that were NOT partial.

### Pitfall 5: `classify_tags()` Return List Signature Change Breaks Callers
**What goes wrong:** Adding `study_type_tags` slot breaks any caller that pattern-matches on the three-element list or uses positional access.
**How to avoid:** Search all callers of `classify_tags()` before implementing. Known callers include `mod_harmonize.R`, `mod_tag_columns.R`, and test files `tests/testthat/test-tag-dispatch.R:20-21,140-141`.

### Pitfall 6: `lubridate` in `Suggests` Causes NAMESPACE Error
**What goes wrong:** `parse_date_time()` call fails at runtime because `lubridate` is not in `Imports`.
**How to avoid:** Move `lubridate` from `Suggests` to `Imports` in DESCRIPTION as Wave 0 task.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-format date parsing | Custom regex parser | `lubridate::parse_date_time()` | Handles locale, truncation, multiple format orders with a single call |
| 2-digit year inference | Custom century logic | Library default (cutoff=68) + `"inferred_format"` flag | Regulatory data spans 1950-2030; default is correct, flag ensures visibility |
| SAS date format (15JAN1985) | Regex with month-name lookup | `"dBY"` order in parse_date_time | Already handles case-insensitive month abbreviations |

---

## Architecture Patterns

### `parse_dates()` Function Skeleton

```r
# R/date_parser.R
parse_dates <- function(raw_dates, orig_row_id = seq_along(raw_dates)) {
  # Pre-compiled orders (bY/BY before mdy — critical ordering)
  ORDERS <- c("ymd", "Ymd", "bY", "BY", "dBY", "BdY", "mdy", "dmy", "Y", "Ym")
  # 2-digit year detection pattern
  TWO_DIGIT_PAT <- "[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$"

  # Vectorized parse (train=FALSE for heterogeneous formats)
  parsed_posix <- lubridate::parse_date_time(raw_dates, orders = ORDERS,
                                              train = FALSE, quiet = TRUE)
  parsed_date <- format(as.Date(parsed_posix), "%Y-%m-%d")
  parsed_date[is.na(parsed_posix)] <- NA_character_

  date_year <- lubridate::year(parsed_posix)
  date_year[is.na(parsed_posix)] <- NA_integer_

  # Flag assignment (priority: unparseable > partial > inferred_format > ambiguous > "")
  is_unparseable <- is.na(parsed_posix)
  is_partial     <- !is_unparseable &
    grepl("^[0-9]{4}$", trimws(raw_dates)) |
    grepl("^[0-9]{4}[-/][0-9]{1,2}$", trimws(raw_dates)) |
    grepl("^[A-Za-z]+ [0-9]{4}$", trimws(raw_dates))
  is_inferred    <- !is_unparseable & grepl(TWO_DIGIT_PAT, raw_dates, perl = TRUE)
  is_ambiguous   <- !is_unparseable & !is_partial &
    lubridate::day(parsed_posix) <= 12 &
    lubridate::month(parsed_posix) <= 12

  date_flag <- dplyr::case_when(
    is_unparseable ~ "unparseable",
    is_partial     ~ "partial",
    is_inferred    ~ "inferred_format",
    is_ambiguous   ~ "ambiguous",
    TRUE           ~ ""
  )

  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    raw_date    = as.character(raw_dates),
    parsed_date = parsed_date,
    date_year   = as.integer(date_year),
    date_flag   = date_flag
  )
}
```

**Notes for implementer:**
- `parse_date_time()` is already vectorized — no per-row loop needed
- Partial date detection regex covers "2015", "2015-03", "Jan 2015" (the three `Y` / `Ym` / `bY` cases)
- `dplyr::case_when()` applies priority order — no further sorting needed

---

## Environment Availability

Step 2.6: SKIPPED — phase is code-only changes with one package version bump (`lubridate` Imports). No external services, CLIs, or databases required.

| Dependency | Available | Version | Action |
|------------|-----------|---------|--------|
| lubridate | Yes | 1.9.4 | Move from Suggests to Imports in DESCRIPTION |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | `tests/testthat/` (existing) |
| Quick run command | `testthat::test_file("tests/testthat/test-date-parser.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DATE-01 | All 7 format families parse correctly | unit | `test_file("tests/testthat/test-date-parser.R")` | Wave 0 |
| DATE-02 | Output tibble has correct 5-column schema | unit | Same file | Wave 0 |
| DATE-03 | "01/02/2015" flagged ambiguous; "13/02/2015" not flagged | unit | Same file | Wave 0 |
| DATE-04 | StudyDate in `classify_tags()` study_types group | unit | `test_file("tests/testthat/test-tag-dispatch.R")` | Extend existing |
| DATE-05 | Headless run with StudyDate tag populates `date_year` | integration | `test_file("tests/testthat/test-curate-headless.R")` | Wave 0 or extend |
| DATE-06 | `original_year` populated in ToxVal output | integration | `test_file("tests/testthat/test-toxval-mapper.R")` | Extend existing (lines 244-252) |

### Wave 0 Gaps
- [ ] `tests/testthat/test-date-parser.R` — covers DATE-01, DATE-02, DATE-03
- [ ] Extend `tests/testthat/test-tag-dispatch.R` — add StudyDate to study_types assertions (lines 20-21, 140-141 pattern)
- [ ] Extend `tests/testthat/test-toxval-mapper.R` — add `original_year` from date_year test (lines 244-252 pattern)

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test-date-parser.R")`
- **Per wave merge:** `testthat::test_dir("tests/testthat")`
- **Phase gate:** Full suite green + Shiny cold boot before `/gsd-verify-work`

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `parse_date_time` with `train=FALSE` and the given orders handles all DATE-01 format families | lubridate API Findings | Verified for all listed formats; edge cases in real data may require additional orders |
| A2 | The partial date detection regex covers all practical Y/Ym/bY inputs | `parse_dates()` skeleton | If real data has other partial patterns, partial flag may miss; caught in testing |

---

## Sources

### Primary (HIGH confidence — verified by live R session)
- `lubridate 1.9.4` — `formals(parse_date_time)`, behavior of `train=FALSE`, orders vector, 2-digit year cutoff, `fast_strptime` `cutoff_2000` parameter
- `R/tag_helpers.R` — `classify_tags()` current structure, lines 35-83
- `R/mod_harmonize.R` — Stage 4.5 duration template, lines 387-430
- `R/curate_headless.R` — Stage 3.5 duration template, lines 275-295
- `R/toxval_mapper.R` — `original_year` extraction, line 153
- `R/mod_tag_columns.R` — optgroup structure, lines 84-91
- `DESCRIPTION` — `lubridate` in `Suggests` (not `Imports`), confirmed

### Secondary (HIGH confidence — from project files)
- `40-CONTEXT.md` — 18 locked decisions, all constraints
- `40-UI-SPEC.md` — value box layout, optgroup rename spec, copywriting contract

---

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (lubridate 1.9.4 is stable)
