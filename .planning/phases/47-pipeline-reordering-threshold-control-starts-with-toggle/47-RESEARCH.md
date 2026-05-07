# Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle - Research

**Researched:** 2026-05-06
**Domain:** R/Shiny — pipeline orchestration, pre-flight modal UI, headless API
**Confidence:** HIGH

## Summary

This phase makes three targeted changes to an existing, well-understood codebase. All three changes are code-only modifications to files that have already been fully read and analyzed. There are no external API changes, no schema changes, and no new dependencies required.

The current pipeline in `run_curation_pipeline()` (R/curation.R) places the WQX tier at the very end — after starts-with — contradicting the intent of decisions D-01 and D-02. The reordering moves WQX to Tier 3 (after CAS fallback) and pushes starts-with to Tier 4 (gated by a new boolean flag). The UI work adds a third accordion panel to the pre-flight modal already defined in `mod_clean_data.R`. The headless API work adds two arguments to `curate_headless()` and threads them through to `run_curation_pipeline()`.

**Primary recommendation:** Implement in three sequential tasks: (1) pipeline reorder + `starts_with` flag in `run_curation_pipeline()`, (2) UI controls in the pre-flight modal, (3) headless API argument forwarding. This order keeps each task independently testable.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** New tier order: Exact → CAS → WQX → Starts-with. WQX receives all names that failed exact+CAS (no minimum character filter).
- **D-02:** Starts-with only receives names still unresolved after WQX, even when the starts-with toggle is on.
- **D-03:** New "Search Settings" accordion section goes below the existing cleaning steps accordion in the pre-flight modal (`mod_clean_data.R`).
- **D-04:** WQX threshold control is a `sliderInput` with a companion `numericInput` showing the exact value. Range 0.50–1.00, step 0.01, default 0.85.
- **D-05:** Starts-with toggle is a switch/checkbox, off by default (per TOG-01). When off, the pipeline skips starts-with entirely (per TOG-02).
- **D-06:** Add `wqx_threshold = 0.85` and `starts_with = FALSE` as named top-level arguments to `curate_headless()`.
- **D-07:** `run_curation_pipeline()` gains `wqx_threshold` and `starts_with` parameters. `wqx_threshold` passes through to `match_wqx()`. `starts_with` gates the starts-with tier.

### Claude's Discretion
- Internal wiring of how the pre-flight modal values are passed from UI → server → `run_curation_pipeline()`
- Whether the slider and numeric input are synced via `observe()` or `updateSliderInput()`/`updateNumericInput()`
- Notification/progress message text for the reordered tiers

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORD-01 | WQX matching tier runs before CompTox starts-with in the curation search chain | Pipeline reorder in `run_curation_pipeline()` — move WQX block from after starts-with to before it |
| ORD-02 | CompTox starts-with fires only on names still unresolved after WQX matching | Gate starts-with on `final_missed` after WQX resolves — `final_missed` is already the right variable |
| CONF-01 | Pre-flight modal includes a WQX fuzzy threshold slider with numeric input (default 0.85) | New accordion panel in `output$preflight_checklist` renderUI in `mod_clean_data.R` |
| CONF-02 | Pipeline passes user-configured threshold to `match_wqx()` instead of hardcoded default | `wqx_threshold` parameter flows: modal input → `execute_pipeline()` → `run_curation_pipeline()` → `match_wqx()` |
| TOG-01 | Pre-flight modal includes a toggle to enable/disable CompTox starts-with tier (off by default) | Switch input in new "Search Settings" accordion panel |
| TOG-02 | Pipeline skips starts-with search when toggle is off | `starts_with` boolean flag gates the `search_starts_with()` block |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pipeline tier ordering | API/Backend (R pure functions) | — | `run_curation_pipeline()` is a pure R function with no UI dependency |
| WQX threshold configuration | Frontend Server (Shiny module) | API/Backend | User sets in modal; value passed down to pipeline |
| Starts-with toggle | Frontend Server (Shiny module) | API/Backend | User sets in modal; boolean passed down to pipeline |
| Headless API parameter forwarding | API/Backend | — | `curate_headless()` argument additions only |
| Progress message text | Frontend Server (Shiny module) | — | `progress_callback` stage labels live in `mod_run_curation.R` |

---

## Standard Stack

All packages below are already present in the project. No new installations required.

### Core (already in use)
| Library | Purpose | Relevant Usage |
|---------|---------|----------------|
| shiny | Reactive UI framework | `sliderInput`, `numericInput`, `checkboxInput`, `observe`, `observeEvent` |
| bslib | Bootstrap 5 components | `accordion_panel` — already used for Cleaning Steps and Harmonization Steps in the modal |
| shinyjs | JS helpers | `enable`/`disable` button state |

### No New Dependencies
This phase requires zero new package installs. [VERIFIED: full codebase scan]

---

## Architecture Patterns

### System Architecture Diagram

```
User clicks "Run Pipeline"
        |
        v
[Pre-flight modal — mod_clean_data.R]
  - Cleaning Steps accordion (existing)
  - Harmonization Steps accordion (existing)
  - Search Settings accordion (NEW)
      * sliderInput: wqx_threshold (0.50–1.00, default 0.85)
      * numericInput: wqx_threshold_num (synced companion)
      * checkboxInput: starts_with_enabled (default FALSE)
        |
        v
execute_pipeline(mask)  ← mask gains wqx_threshold + starts_with fields
        |
        v
[run_curation_pipeline() — R/curation.R]
  Tier 1: Exact match (unchanged)
  Tier 2: CAS fallback (unchanged)
  Tier 3: WQX  ←  MOVED UP from position 4 (was after starts-with)
    match_wqx(still_missed, wqx_dict, threshold = wqx_threshold)
  Tier 4: Starts-with  ←  GATED by starts_with flag
    if (starts_with) { search_starts_with(final_missed_after_wqx) }
  Tier 5: CAS columns (unchanged)
        |
        v
[curate_headless() — R/curate_headless.R]  ← parallel path
  gains: wqx_threshold = 0.85, starts_with = FALSE
  passes both to run_curation_pipeline()
```

### Recommended Project Structure

No structural changes. All modifications are within existing files:

```
R/
├── curation.R           # run_curation_pipeline() — tier reorder + new params
├── mod_clean_data.R     # pre-flight modal — new Search Settings accordion panel
├── mod_run_curation.R   # notification text update for reordered tiers
└── curate_headless.R    # new wqx_threshold + starts_with arguments
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Slider ↔ numeric sync | Custom JS binding | Shiny `observe()` + `updateNumericInput()`/`updateSliderInput()` | The standard Shiny reactive pattern for two-way sync; no JS required |
| WQX fuzzy matching | New matching logic | `match_wqx(threshold=)` already exists with the parameter | [VERIFIED: wqx_matching.R line 21] |
| WQX dictionary loading | New loader | `load_wqx_dictionary()` already called inside the pipeline | [VERIFIED: curation.R lines 761–762] |

---

## Common Pitfalls

### Pitfall 1: Wrong Variable Passed to WQX After Reorder

**What goes wrong:** After moving WQX from position 4 to position 3, the variable holding "still unresolved names" changes. Currently `final_missed` is populated after starts-with. After reordering, the variable fed to WQX must be `still_missed` (after CAS fallback), and the variable fed to starts-with must be the post-WQX remainder.

**Current code flow (to change):**
```
still_missed → search_starts_with → sw_matched → final_missed → match_wqx
```
**New code flow:**
```
still_missed → match_wqx → wqx_matched_names → final_missed → [if starts_with] search_starts_with
```

**Why it happens:** Copy-paste confusion when cutting/pasting the WQX block to a new position.

**Warning signs:** WQX gets called with 0 names; starts-with gets called with names already resolved by WQX.

---

### Pitfall 2: 3-Character Minimum on WQX

**What goes wrong:** The current starts-with block applies a 3-character minimum filter (`nchar(still_missed) >= 3`) before calling `search_starts_with()`. Decision D-01 explicitly says WQX has NO minimum character filter.

**Current code (line 739):**
```r
sw_candidates <- still_missed[nchar(still_missed) >= 3]
```

**What to do:** When moving WQX to position 3, pass `still_missed` directly — no character filter. The 3-char filter stays only with the starts-with call.

**Why it matters:** WQX is a local dictionary lookup with no API cost; short names are valid chemical identifiers in the WQX dictionary.

---

### Pitfall 3: Modal Values Not Passed Through execute_pipeline()

**What goes wrong:** The new slider/toggle inputs live inside the modal, but `execute_pipeline()` currently receives only a `mask` list of checkbox booleans for cleaning steps. If `wqx_threshold` and `starts_with` are not explicitly captured from `input$` inside the `observeEvent(input$run_all)` and `observeEvent(input$run_checked)` observers and added to the mask, they will be lost.

**How to avoid:** Extend `build_mask_from_inputs()` to include:
```r
wqx_threshold = input$wqx_threshold,
starts_with = isTRUE(input$starts_with_enabled)
```
And thread both through `execute_pipeline(mask)` → `run_curation_pipeline(..., wqx_threshold = mask$wqx_threshold, starts_with = mask$starts_with)`.

**Warning signs:** Pipeline always uses threshold 0.85 regardless of slider position; starts-with always runs regardless of toggle.

---

### Pitfall 4: run_all Observer Hardcodes Steps — Won't Include New Controls

**What goes wrong:** `observeEvent(input$run_all)` builds its own explicit mask list (lines 631–645) rather than calling `build_mask_from_inputs()`. The new `wqx_threshold` and `starts_with` values will be absent from the run_all path unless explicitly added.

**How to avoid:** Add `wqx_threshold = input$wqx_threshold` and `starts_with = isTRUE(input$starts_with_enabled)` to the explicit mask in the `run_all` observer.

---

### Pitfall 5: n_wqx Counting After Reorder

**What goes wrong:** `n_wqx` and `n_starts_with` are tallied inside the tier block. After reordering, the tally code must move with the tier. If the tally code is left behind at the old position, it tallies against a different variable.

**How to avoid:** Treat the tally lines (`n_wqx <- nrow(wqx_resolved)`, `n_starts_with <- sum(...)`) as belonging to their tier block — move them with the block.

---

### Pitfall 6: Slider/Numeric Input Namespace in Modal

**What goes wrong:** Inputs rendered inside `renderUI({...})` (like `output$preflight_checklist`) do NOT automatically inherit the module namespace. IDs must be explicitly namespaced with `session$ns(...)`.

**Current pattern in the modal (correct):**
```r
checkboxInput(session$ns(paste0("step_", key)), ...)
```

**New inputs must follow the same pattern:**
```r
sliderInput(session$ns("wqx_threshold"), ...),
numericInput(session$ns("wqx_threshold_num"), ...),
checkboxInput(session$ns("starts_with_enabled"), ...)
```

**Warning signs:** `input$wqx_threshold` returns NULL even after slider interaction.

---

### Pitfall 7: Slider ↔ Numeric Sync Infinite Loop

**What goes wrong:** A naive two-way sync between `sliderInput` and `numericInput` where each `observe()` triggers `update*()` which triggers the other `observe()` creates an infinite reactive loop.

**How to avoid:** Use `observeEvent()` with a guard, or rely on Shiny's built-in value-equality check — `updateSliderInput()` only fires when the value actually changes, which breaks the cycle. The standard pattern:

```r
observeEvent(input$wqx_threshold, {
  updateNumericInput(session, "wqx_threshold_num", value = input$wqx_threshold)
}, ignoreInit = TRUE)

observeEvent(input$wqx_threshold_num, {
  val <- input$wqx_threshold_num
  if (!is.null(val) && !is.na(val) && val >= 0.50 && val <= 1.00) {
    updateSliderInput(session, "wqx_threshold", value = val)
  }
}, ignoreInit = TRUE)
```

`ignoreInit = TRUE` prevents double-fire on modal open. [ASSUMED — standard Shiny pattern, not explicitly verified against this codebase]

---

### Pitfall 8: progress_callback Stage Labels Need Updating

**What goes wrong:** After reordering, the `progress_callback("starts_with", ...)` call fires at tier 4 instead of tier 3. The notification in `mod_run_curation.R` (line 259) still reads `"starts-with"` in the breakdown string, which will be confusing if starts-with is toggled off.

**How to avoid:** Update the notification string in `mod_run_curation.R` to include `n_wqx` alongside `n_starts_with`. Consider: `"Search complete: %d exact, %d CAS, %d WQX, %d starts-with, %d no match"`.

---

## Code Examples

### Pattern 1: Reordered Tier Block (run_curation_pipeline)

[VERIFIED: derived from reading curation.R lines 737–800]

Current (wrong order — starts-with before WQX):
```r
# Tier 3: Starts-with  (CURRENT — to be moved after WQX)
if (length(still_missed) > 0) {
  sw_candidates <- still_missed[nchar(still_missed) >= 3]
  ...
  final_missed <- setdiff(still_missed, sw_matched)
}

# Tier 3b: WQX (CURRENT — to be moved before starts-with)
if (length(final_missed) > 0) {
  wqx_raw <- match_wqx(final_missed, wqx_dict, verbose = FALSE)
  ...
}
```

New (correct order):
```r
# Tier 3: WQX (no character minimum — per D-01)
if (length(still_missed) > 0) {
  cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
  wqx_dict <- load_wqx_dictionary(cache_dir)
  wqx_raw <- match_wqx(still_missed, wqx_dict, threshold = wqx_threshold, verbose = FALSE)

  wqx_resolved <- wqx_raw[wqx_raw$match_tier != "none", ]
  n_wqx <- nrow(wqx_resolved)

  if (n_wqx > 0) {
    wqx_rows <- tibble::tibble(
      searchValue = wqx_resolved$input_name,
      dtxsid = NA_character_,
      preferredName = wqx_resolved$wqx_name,
      searchName = NA_character_,
      rank = NA_integer_,
      source_tier = paste0("wqx_", wqx_resolved$match_tier)
    )
    all_results[[length(all_results) + 1]] <- wqx_rows
  }

  wqx_matched_names <- wqx_resolved$input_name
  final_missed <- setdiff(still_missed, wqx_matched_names)

  if (!is.null(progress_callback)) {
    progress_callback("wqx", sprintf("WQX match: %d more found...", n_wqx))
  }

  # Tier 4: Starts-with — only when enabled AND names remain (per D-02)
  if (starts_with && length(final_missed) > 0) {
    sw_candidates <- final_missed[nchar(final_missed) >= 3]
    if (length(sw_candidates) > 0) {
      sw_results <- search_starts_with(sw_candidates)
      if (nrow(sw_results) > 0) {
        sw_results$source_tier <- "starts_with"
        all_results[[length(all_results) + 1]] <- sw_results
        n_starts_with <- sum(!is.na(sw_results$dtxsid))
      }
      if (!is.null(progress_callback)) {
        progress_callback("starts_with", sprintf("Starts-with: %d more found...", n_starts_with))
      }
      sw_matched <- sw_results$searchValue[!is.na(sw_results$dtxsid)]
      final_missed <- setdiff(final_missed, sw_matched)
    }
  }
}
```

---

### Pattern 2: New Accordion Panel in Pre-flight Modal

[VERIFIED: derived from reading mod_clean_data.R lines 294–300 — existing accordion pattern]

```r
# In output$preflight_checklist renderUI, after harmonize_rows accordion_panel:
bslib::accordion_panel(
  title = "Search Settings",
  value = "search_settings",
  div(
    class = "mb-3",
    tags$label(class = "form-label fw-semibold", "WQX Fuzzy Match Threshold"),
    tags$small(class = "text-muted d-block mb-2",
      "Minimum similarity score for fuzzy WQX matches (0.50 = permissive, 1.00 = exact only)"),
    bslib::layout_columns(
      col_widths = c(8, 4),
      sliderInput(
        session$ns("wqx_threshold"),
        label = NULL,
        min = 0.50, max = 1.00, step = 0.01, value = 0.85,
        ticks = FALSE
      ),
      numericInput(
        session$ns("wqx_threshold_num"),
        label = NULL,
        value = 0.85, min = 0.50, max = 1.00, step = 0.01
      )
    )
  ),
  div(
    checkboxInput(
      session$ns("starts_with_enabled"),
      label = "Enable CompTox starts-with search",
      value = FALSE
    ),
    tags$small(class = "text-muted",
      "Off by default. Enable for datasets where exact + CAS + WQX resolution is insufficient.")
  )
)
```

---

### Pattern 3: curate_headless() Signature Extension

[VERIFIED: derived from reading curate_headless.R lines 63–76]

```r
curate_headless <- function(
  input_path,
  output_path,
  tag_map,
  skip_flags = NULL,
  header_row = NULL,
  reference_lists = NULL,
  verbose = TRUE,
  harmonize = FALSE,
  format = "parquet",
  unit_map = NULL,
  corrections = NULL,
  media = NULL,
  wqx_threshold = 0.85,   # NEW
  starts_with = FALSE      # NEW
) {
  ...
  # Step 8: Run curation pipeline
  pipeline_result <- run_curation_pipeline(
    cleaning_result$cleaned_data,
    merged_tags,
    wqx_threshold = wqx_threshold,   # NEW
    starts_with = starts_with         # NEW
  )
```

---

### Pattern 4: run_curation_pipeline() Signature Extension

[VERIFIED: derived from reading curation.R line 629]

```r
run_curation_pipeline <- function(
  clean_data,
  column_tags,
  progress_callback = NULL,
  dedup_only = FALSE,
  wqx_threshold = 0.85,   # NEW
  starts_with = FALSE      # NEW
) {
```

---

## State of the Art

| Old Approach | Current Approach | Impact for This Phase |
|--------------|------------------|----------------------|
| WQX at end of chain (after starts-with) | WQX before starts-with | Primary change — move block in curation.R |
| starts-with always runs | starts-with gated by flag | Gate with `starts_with` boolean |
| threshold hardcoded as 0.85 in pipeline | threshold passed through from modal | Thread `wqx_threshold` param through call stack |

---

## Runtime State Inventory

> Greenfield parameter additions — no runtime state affected. No stored data, live service config, OS-registered state, secrets, or build artifacts contain references to WQX threshold or starts-with toggle. The session-level `.starts_with_cache` environment in `curation.R` is unaffected by the toggle — it is still used when starts-with runs. [VERIFIED: codebase grep for ".starts_with_cache"]

---

## Environment Availability

Step 2.6: SKIPPED — this phase is pure code changes within the existing R package. No new external tools, services, CLIs, or runtimes are required.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (detected in tests/testthat/) |
| Config file | tests/testthat.R |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::load_all(); testthat::test_file('tests/testthat/test-wqx-pipeline-integration.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::load_all(); testthat::test_dir('tests')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORD-01 | WQX fires before starts-with in the tier sequence | unit | test `run_curation_pipeline()` with mock data where WQX resolves a name that starts-with would also resolve — verify `source_tier == "wqx_exact"` not `"starts_with"` | ❌ Wave 0 |
| ORD-02 | Names resolved by WQX never enter starts-with | unit | verify starts-with mock is called with 0 names when WQX resolves all misses | ❌ Wave 0 |
| CONF-01 | Slider + numeric input render in modal | smoke | Shiny app cold boot (existing procedure) | ✅ (smoke only) |
| CONF-02 | Pipeline receives user threshold (not hardcoded 0.85) | unit | call `run_curation_pipeline(..., wqx_threshold = 0.75)` and verify `match_wqx` is called with threshold 0.75 (via mock or argument capture) | ❌ Wave 0 |
| TOG-01 | Toggle renders off by default | smoke | Shiny app cold boot | ✅ (smoke only) |
| TOG-02 | Pipeline skips starts-with when `starts_with = FALSE` | unit | call `run_curation_pipeline(..., starts_with = FALSE)` with names that would normally trigger starts-with; verify `source_tier` is never `"starts_with"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `devtools::load_all(); testthat::test_file('tests/testthat/test-wqx-pipeline-integration.R')`
- **Per wave merge:** Full test suite
- **Phase gate:** Full suite green + Shiny cold boot before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-pipeline-reorder-toggle.R` — covers ORD-01, ORD-02, CONF-02, TOG-02 (new file needed; existing `test-wqx-pipeline-integration.R` tests consensus classification, not tier order)
- [ ] Framework install: none needed

---

## Security Domain

This phase adds two scalar parameters (numeric, boolean) to internal function signatures and one UI accordion panel. No authentication, session management, access control, cryptography, or user-controlled data parsing is introduced. ASVS categories V2–V6 are not applicable. The `wqx_threshold` value flows from a bounded slider (server-side `min`/`max` enforced) directly into a numeric comparison — no injection surface exists.

---

## Open Questions

1. **Should `run_all` in the modal apply starts-with ON or OFF?**
   - What we know: D-05 says starts-with is off by default; `run_all` currently enables all cleaning and harmonization steps.
   - What's unclear: Does "Run All Steps" mean "run all cleaning steps with current search settings" (i.e., respect the toggle), or "run everything including starts-with"?
   - Recommendation: Honor the toggle — `run_all` reads `input$starts_with_enabled` just like `run_checked` does. The toggle's purpose is to let the user control starts-with; overriding it on "Run All" would defeat that purpose.

2. **Notification text for WQX count in mod_run_curation.R**
   - What we know: Line 259 currently shows `n_starts_with` but not `n_wqx`. After the reorder, WQX is a primary tier and should appear in the breakdown.
   - What's unclear: Exact string format.
   - Recommendation: `"Search complete: %d exact, %d CAS, %d WQX, %d starts-with, %d no match"` using `pipeline_result$search_summary$n_wqx`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ignoreInit = TRUE` on `observeEvent` prevents slider/numeric double-fire on modal open | Pitfall 7 | Minor — worst case is a redundant `update*()` call on modal open, not a loop |
| A2 | `run_all` should honor the starts-with toggle rather than force-enable it | Open Questions | Behavior mismatch from user expectation — low risk since default is FALSE |

---

## Sources

### Primary (HIGH confidence)
- `R/curation.R` [VERIFIED: read in full] — exact current tier order, variable names, progress_callback call sites
- `R/wqx_matching.R` [VERIFIED: read in full] — `threshold` parameter confirmed at line 21, `match_wqx()` signature
- `R/curate_headless.R` [VERIFIED: read in full] — current function signature lines 63–76, `run_curation_pipeline()` call at line 176
- `R/mod_clean_data.R` [VERIFIED: read in full] — pre-flight modal renderUI at lines 254–300, accordion pattern, `build_mask_from_inputs()` at lines 304–318, `run_all` observer at lines 631–645
- `R/mod_run_curation.R` [VERIFIED: read in full] — notification text at line 259, `run_curation_pipeline()` call at line 161
- `tests/testthat/` [VERIFIED: directory listing] — existing test files; no test currently covers tier order

### Secondary (MEDIUM confidence)
- Shiny `observe`/`observeEvent` sync pattern for slider+numeric — standard documented pattern [ASSUMED based on training knowledge]

---

## Metadata

**Confidence breakdown:**
- Pipeline reorder: HIGH — exact code read, variable names confirmed
- UI accordion pattern: HIGH — existing pattern in same file confirmed
- Headless API extension: HIGH — current signature read, call site confirmed
- Slider sync pattern: MEDIUM — standard Shiny pattern, not verified against a specific docs page

**Research date:** 2026-05-06
**Valid until:** 2026-06-05 (stable internal codebase)
