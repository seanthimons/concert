# Phase 22: UI Polish - Research

**Researched:** 2026-04-01
**Domain:** Shiny/reactable widget configuration, htmlwidgets/jsonlite serialization
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 (UIPOL-01):** Change `wrap = FALSE` to `wrap = TRUE` in the reactable call at `R/modules/mod_review_results.R:754`.

**D-02 (UIPOL-02):** Remove the explicit `elementId = table_id` from the reactable call at `R/modules/mod_review_results.R:758`. The `Reactable.setFilter()` JS calls in the filter dropdowns must be updated to use the auto-generated Shiny output ID instead of the manually set `elementId`.

**D-03 (UIPOL-03):** Runtime tracing needed to identify the exact jsonlite warning call site. Fix is either converting named vectors to named lists in CONCERT code, or a package update. No `jsonlite` calls exist directly in `R/`.

### Claude's Discretion

- Approach for tracing the jsonlite warning source (runtime debugging vs. package version check)
- Whether to add CSS styling for wrapped headers (e.g., smaller font, vertical alignment)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UIPOL-01 | Review Results DT table column headers wrap to show full text instead of truncating | `wrap = TRUE` in reactable controls both cell and header wrapping; confirmed working |
| UIPOL-02 | Remove explicit widget ID from results table to silence `renderWidget` warning | Shiny output ID `session$ns("curation_table")` (with `-` separator) is the correct ID for `Reactable.setFilter()` |
| UIPOL-03 | Convert named vectors to named lists to fix `jsonlite` deprecation warning | Root cause confirmed: `shiny:::toJSON` calls `jsonlite::toJSON(..., keep_vec_names=TRUE)` — any named vector passed through Shiny serialization triggers the warning |
</phase_requirements>

---

## Summary

Phase 22 is a three-fix polish pass on `mod_review_results.R`. All three fixes are narrow, well-understood changes — no new dependencies, no new modules, no architectural changes.

**UIPOL-01** is a single-character change: `wrap = FALSE` → `wrap = TRUE` at line 754. The reactable `wrap` parameter controls both cell content and column header text wrapping. Setting it to `TRUE` (the default) causes long headers to flow onto multiple lines instead of truncating with an ellipsis.

**UIPOL-02** requires removing `elementId = table_id` from the `reactable()` call (line 758) and updating the three `Reactable.setFilter(table_id, ...)` JavaScript calls in the filter dropdowns. The key insight is that Shiny already assigns the correct namespaced ID to the widget via its output binding — the output ID is `session$ns("curation_table")` (the module namespace uses `"-"` as separator in HTML, e.g. `review_results-curation_table`). The existing `table_id` variable already equals `session$ns("curation_table")`, which IS the correct Shiny-managed ID for `Reactable.setFilter`. So the Shiny output ID and the `table_id` variable are the same value — removing `elementId` does not break the JS filter calls; they keep using `table_id` as the string.

**UIPOL-03** is the most complex. Root cause confirmed via code inspection: `shiny:::toJSON` (which all Shiny output serialization goes through) internally calls `jsonlite::toJSON(..., keep_vec_names=TRUE)`. This triggers a deprecation warning in jsonlite 2.0.0 whenever it receives a named R vector (as opposed to a named list). The warning fires at Shiny's output serialization layer — not from CONCERT's own jsonlite calls (there are none in `R/`). The fix direction is to ensure that any named character/integer vector that flows into a Shiny reactive output is converted to an unnamed vector or a named list before reaching serialization. Two confirmed patterns in `mod_review_results.R` trigger this path: `unlist(column_tags)` (line 1129 context), and any named vector used in reactive output expressions. The safest targeted fix is wrapping named vectors in `as.list()` or `unname()` before passing them through Shiny outputs.

**Primary recommendation:** Implement all three fixes in `R/modules/mod_review_results.R` in a single wave. UIPOL-01 and UIPOL-02 are trivial. UIPOL-03 requires runtime tracing inside a live Shiny session to catch every named vector that flows to a browser output, then converting each to `as.list()`.

---

## Standard Stack

### Core (Already Installed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| reactable | 0.4.5 | Table widget | Already in use throughout app |
| htmlwidgets | 1.6.4 | Widget serialization layer | Dependency of reactable |
| jsonlite | 2.0.0 | JSON serialization | Shiny and htmlwidgets dependency |
| shiny | (installed) | Reactive framework | App framework |

No new packages required for this phase.

**Version verification (confirmed 2026-04-01):**
- `reactable`: 0.4.5 (installed, built for R 4.5.2 — version mismatch warning is cosmetic)
- `jsonlite`: 2.0.0 (installed 2025-03-27)
- `htmlwidgets`: 1.6.4

---

## Architecture Patterns

### UIPOL-01: wrap Parameter

The `reactable::reactable()` `wrap` parameter controls text wrapping for both cell content and column headers. Default is `TRUE` (wrap enabled). The existing code sets `wrap = FALSE` explicitly to prevent wrapping.

**Change:**
```r
# R/modules/mod_review_results.R line 754
# Before:
wrap = FALSE,

# After:
wrap = TRUE,
```

**Optional CSS refinement** (Claude's discretion): If wrapped headers look too tall, add a `theme` or `defaultColDef` to control header font-size or vertical alignment:
```r
reactable::reactable(
  df_display,
  defaultColDef = reactable::colDef(
    headerStyle = list(fontSize = "0.85em", whiteSpace = "normal")
  ),
  wrap = TRUE,
  ...
)
```

### UIPOL-02: Removing elementId Without Breaking Reactable.setFilter

**How Shiny names reactable widgets:**
When `output$curation_table <- reactable::renderReactable({...})` is used inside a Shiny module, Shiny assigns the widget the namespaced output ID as its HTML element ID. The format is `<module_namespace>-<outputId>` where the namespace separator is `-`.

The existing code:
```r
table_id <- session$ns("curation_table")  # e.g. "review_results-curation_table"
```

`session$ns("curation_table")` already produces `"review_results-curation_table"` — exactly the ID Shiny assigns to the widget. So the `Reactable.setFilter(table_id, ...)` calls are already using the correct string. The `elementId = table_id` line is redundant (Shiny ignores it and warns).

**Change:** Simply delete the `elementId = table_id` line (line 758). No changes to `table_id` or `Reactable.setFilter` calls are needed.

```r
# Before (lines 745-759):
reactable::reactable(
  df_display,
  ...
  wrap = FALSE,
  compact = TRUE,
  bordered = TRUE,
  highlight = TRUE,
  elementId = table_id   # <-- DELETE THIS LINE
)

# After:
reactable::reactable(
  df_display,
  ...
  wrap = TRUE,           # also changed per UIPOL-01
  compact = TRUE,
  bordered = TRUE,
  highlight = TRUE
)
```

The three `Reactable.setFilter(table_id, ...)` calls in `make_select_filter()` (line 562), the inline `qc_flag` filter (line 668) — these remain unchanged. They already use the correct namespaced ID.

**Verification:** Source: [reactable JavaScript API docs](https://glin.github.io/reactable/articles/javascript-api.html) — "For tables in Shiny apps, the ID will be the Shiny output ID specified in `reactableOutput()`."

### UIPOL-03: jsonlite Named Vector Warning

**Root cause confirmed (HIGH confidence):**

`shiny:::toJSON` (used for all Shiny output serialization) always calls `jsonlite::toJSON(..., keep_vec_names=TRUE)`. In jsonlite 2.0.0, passing a named R vector (not a named list) with `keep_vec_names=TRUE` triggers:

```
Input to asJSON(keep_vec_names=TRUE) is a named vector. In a future version of jsonlite,
this option will not be supported, and named vectors will be translated into arrays instead
of objects. If you want JSON object output, please use a named list instead. See ?toJSON.
```

This warning fires on every named vector that flows through a Shiny reactive output binding — not just at module load time, but whenever Shiny serializes a reactive value containing a named vector to send to the browser.

**Also confirmed:** `htmlwidgets:::toJSON2` (used by reactable widget serialization) also calls `jsonlite::toJSON(..., keep_vec_names=TRUE)`. However, reactable internally stores data as dataframes and named lists — testing showed reactable table rendering alone does NOT trigger the warning. The warning source is Shiny output bindings sending named vectors.

**Pattern that triggers warning:**
```r
# Any named character or integer vector going through a Shiny output
x <- c(a = "val1", b = "val2")   # named character vector - TRIGGERS WARNING
y <- stats::setNames(1:3, c("a", "b", "c"))  # named integer vector - TRIGGERS WARNING

# These do NOT trigger:
x <- list(a = "val1", b = "val2")  # named list - safe
x <- c("val1", "val2")              # unnamed vector - safe
x <- unname(named_vector)           # unnamed - safe
```

**Fix strategy:**

The CONTEXT.md says to use `withCallingHandlers` or `options(warn=2)` to trace the exact call site at runtime. The pattern in CONCERT that is most likely to trigger this:

1. **`unlist(queue)` at mod_review_results.R line 1129** — `queue` is a named list; `unlist()` preserves names, producing a named vector. If this value is later passed to a Shiny output context, it will trigger the warning. Fix: `unname(unlist(queue))`.

2. **Any named vector created inside a `renderUI` or `reactive` expression** that is returned or stored in `data_store`. Specifically, named vectors from `c(name = value)` patterns that end up in `data_store$*` and are then read by output bindings.

3. **`data_store$column_tags`** is a named list (set as `list()` in mod_tag_columns.R:103) — this is already safe.

**Runtime tracing approach** (for use during implementation):
```r
# In app.R or test session, add before running curation:
options(warn = 2)  # promote warnings to errors to get full stack trace
# OR
withCallingHandlers(
  { ... run curation ... },
  warning = function(w) {
    if (grepl("keep_vec_names", conditionMessage(w))) {
      message("STACK: ", paste(deparse(sys.calls()), collapse="\n"))
    }
    invokeRestart("muffleWarning")
  }
)
```

**Likely complete fix:** `unname()` around named vectors in output-bound reactive expressions and `unlist()` calls that feed Shiny outputs. Candidate locations:
- `R/modules/mod_review_results.R:1129` — `all_dtxsids <- unname(unlist(queue))`
- Any `output$X <- reactive({ ... })` that returns a named vector

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Finding named vectors in Shiny outputs | Custom static analysis | `options(warn=2)` + runtime trace | Only live execution reveals which outputs fire |
| Table ID for JS API in Shiny modules | Custom ID registry | `session$ns("outputId")` | Shiny's namespacing already produces the correct HTML ID |

---

## Common Pitfalls

### Pitfall 1: Assuming elementId matches the Shiny output ID format
**What goes wrong:** Developer sees `session$ns("curation_table")` returns `"review_results-curation_table"` and worries this won't match Shiny's auto-generated ID.
**Why it happens:** Confusion about whether Shiny uses a different separator internally.
**How to avoid:** `session$ns()` uses `-` as namespace separator. Shiny's widget HTML ID for `output$curation_table` in a module is exactly `<ns_prefix>-curation_table`. These match.
**Warning signs:** N/A — they are the same value by definition.

### Pitfall 2: Only fixing unlist() but missing other named vector sites
**What goes wrong:** UIPOL-03 warning persists after fix because another named vector is still flowing through.
**Why it happens:** Named vectors can appear anywhere: `setNames()`, `c(name=val)`, subsetting a named vector, `unlist()` on a named list.
**How to avoid:** Use runtime tracing (`options(warn=2)`) in a live session to enumerate ALL warning invocations before declaring fix complete.
**Warning signs:** Warning still appears after fixing the most obvious site.

### Pitfall 3: wrap=TRUE making headers overly tall on wide tables
**What goes wrong:** Long column headers wrap to 3+ lines, making the table header area very tall and awkward.
**Why it happens:** Some columns in the curation table have long snake_case names.
**How to avoid:** After setting `wrap=TRUE`, test with actual data. If headers are too tall, add `headerStyle = list(whiteSpace = "normal", fontSize = "0.85em")` to `defaultColDef`.
**Warning signs:** Header row height > 3 lines for any column.

### Pitfall 4: Thinking the jsonlite warning is from CONCERT's own toJSON calls
**What goes wrong:** Developer greps for `toJSON` in `R/` and finds only `PW_ChemicalCuration.R:55` — concludes it's unrelated to curation module and searches elsewhere.
**Why it happens:** The actual call chain is: `Shiny output serialization → shiny:::toJSON → jsonlite::toJSON(keep_vec_names=TRUE)`. CONCERT doesn't call jsonlite directly — Shiny does, on CONCERT's data.
**How to avoid:** Understand that any named vector stored in `data_store$*` or returned from `output$X` can trigger this.

---

## Code Examples

### UIPOL-01: Complete reactable call change
```r
# Source: R/modules/mod_review_results.R line 745-759
reactable::reactable(
  df_display,
  columns = col_defs,
  filterable = TRUE,
  selection = selection_mode,
  onClick = if (!is.null(selection_mode)) "select" else NULL,
  rowStyle = row_style_fn,
  defaultPageSize = 25,
  resizable = TRUE,
  wrap = TRUE,         # Changed from FALSE (UIPOL-01)
  compact = TRUE,
  bordered = TRUE,
  highlight = TRUE
  # elementId removed (UIPOL-02)
)
```

### UIPOL-02: Reactable.setFilter still works without elementId
```r
# table_id is still used in all Reactable.setFilter calls — this is CORRECT
# session$ns("curation_table") = "review_results-curation_table"
# = same ID Shiny assigns to output$curation_table
table_id <- session$ns("curation_table")  # Keep this line

make_select_filter <- function(choices, col_name) {
  function(values, name) {
    htmltools::tags$select(
      onchange = sprintf(
        "Reactable.setFilter('%s', '%s', event.target.value || undefined)",
        table_id, col_name  # table_id still works correctly
      ),
      ...
    )
  }
}
```

### UIPOL-03: Converting named vectors to avoid jsonlite warning
```r
# Pattern: unlist() on named list preserves names → triggers warning
# Fix: use unname() to strip names when object identity matters, not key order

# Before (triggers warning):
all_dtxsids <- unlist(queue)

# After (safe):
all_dtxsids <- unname(unlist(queue))

# Alternative when names are semantically meaningful:
# Convert to named list instead of named vector
x_as_list <- as.list(named_vector)  # safe for shiny:::toJSON
```

### UIPOL-03: Runtime tracing to find all warning sites
```r
# Add temporarily to app.R before running curation, check R console:
old_warn <- getOption("warn")
options(warn = 2)  # Promote warning to error with full traceback
# ... trigger curation ...
options(warn = old_warn)

# Alternative: non-stopping trace
withCallingHandlers(
  { shiny::runApp() },
  warning = function(w) {
    if (grepl("keep_vec_names", conditionMessage(w))) {
      cat("=== NAMED VECTOR WARNING ===\n")
      traceback()
    }
    invokeRestart("muffleWarning")
  }
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `elementId` in Shiny for JS widget targeting | Rely on Shiny output ID for JS API | Reactable 0.4+ | `elementId` always ignored in Shiny — don't use it |
| Named vectors to `toJSON` | Named lists to `toJSON` | jsonlite 2.0.0 (2025-03-27) | Warning in 2.0.0; will break in future version |
| `wrap = FALSE` (compact, no overflow) | `wrap = TRUE` with CSS control | Best practice | More accessible; control via CSS if needed |

---

## Open Questions

1. **Are there named vector sites beyond mod_review_results.R line 1129?**
   - What we know: `shiny:::toJSON` triggers for any named vector in a Shiny output
   - What's unclear: The full set of CONCERT named vectors flowing through Shiny outputs
   - Recommendation: Use `options(warn=2)` runtime trace during implementation to enumerate all sites before declaring fix complete

2. **Does `wrap = TRUE` affect all tables or just the review results table?**
   - What we know: `wrap = FALSE` is set in 6 locations across 4 modules
   - What's unclear: Phase scope — CONTEXT.md says fix only `mod_review_results.R:754`
   - Recommendation: Only change the review results table per D-01; note other tables in implementation

---

## Environment Availability

Step 2.6: SKIPPED — no external dependencies. All changes are code edits to `R/modules/mod_review_results.R`. No CLI tools, databases, or external services required.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (version from installed packages) |
| Config file | none — test_dir("tests") pattern |
| Quick run command | `"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "testthat::test_file('tests/test_modules_render.R')"` |
| Full suite command | `"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "testthat::test_dir('tests')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| UIPOL-01 | review results reactable uses `wrap=TRUE` | unit (code assertion) | `testthat::test_file('tests/test_modules_render.R')` | ✅ (extend existing) |
| UIPOL-02 | no `elementId` in renderReactable call | unit (code assertion) | `testthat::test_file('tests/test_modules_render.R')` | ✅ (extend existing) |
| UIPOL-03 | no jsonlite warning during curation rendering | unit (warning capture) | `testthat::test_file('tests/test_modules_render.R')` | ✅ (extend existing) |

All three requirements can be tested by extending `tests/test_modules_render.R`. Smoke test (start app, wait for "Listening on") verifies no startup crashes.

### Sampling Rate
- **Per task commit:** `"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "testthat::test_file('tests/test_modules_render.R')"`
- **Per wave merge:** `"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "testthat::test_dir('tests')"`
- **Phase gate:** Full suite green + Shiny smoke test before `/gsd:verify-work`

### Wave 0 Gaps
None — `tests/test_modules_render.R` exists and tests module initialization. New test cases for UIPOL-01/02/03 can be added to the existing file. No new test infrastructure required.

---

## Sources

### Primary (HIGH confidence)
- Reactable JavaScript API docs (https://glin.github.io/reactable/articles/javascript-api.html) — Shiny output ID as table ID
- Runtime code inspection: `body(shiny:::toJSON)`, `body(htmlwidgets:::toJSON2)` — both confirmed `keep_vec_names=TRUE`
- Runtime test: `shiny:::toJSON(c(a="x", b="y"))` → triggers jsonlite warning
- Runtime test: `shiny:::toJSON(list(a="x", b="y"))` → no warning
- Installed package inspection: `reactable` 0.4.5, `jsonlite` 2.0.0, `htmlwidgets` 1.6.4

### Secondary (MEDIUM confidence)
- [reactable renderWidget warning explanation](https://glin.github.io/reactable/reference/reactable-shiny.html) — confirmed elementId is ignored in Shiny
- [jsonlite GitHub issue #226 (dygraphs)](https://github.com/rstudio/dygraphs/issues/226) — same warning pattern confirmed in other packages
- [Shiny jsonlite warning issue #2673](https://github.com/rstudio/shiny/issues/2673) — shiny:::toJSON as source

### Tertiary (LOW confidence)
None.

---

## Project Constraints (from CLAUDE.md)

Directives that apply to this phase:

- **Use `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe"`** for all R script execution
- **Never use `Rscript -e "..."` for multi-statement R** — write to temp file first
- **Shiny Smoke Test required** after any Shiny UI/server changes — start app, wait for "Listening on", kill, fix crashes before proceeding
- **Always use explicit `ggplot2::` namespace prefixes** — not applicable this phase (no ggplot2)
- **For Shiny modules: always use proper namespacing (ns())** — confirmed existing code already does this
- **Feature branch required** before making code changes — do not commit to main
- **Verify field names by reading actual source code** before implementing — done (lines 754-759 confirmed)
- **After implementing: verify all referenced names exist** — run tests + smoke test
- **Air formatter config** at `air.toml` — line width 120, 2-space indent
- **Commit iteratively** after each logical unit of work

---

## Metadata

**Confidence breakdown:**
- UIPOL-01 (wrap): HIGH — single parameter change, confirmed from docs and code
- UIPOL-02 (elementId): HIGH — confirmed that `session$ns("curation_table")` equals Shiny's auto-assigned ID; JS filter calls are unaffected
- UIPOL-03 (jsonlite): HIGH for root cause (`shiny:::toJSON` + `keep_vec_names=TRUE`); MEDIUM for complete fix scope (need runtime trace to find all named vector sites)

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable packages, no expected breaking changes)
