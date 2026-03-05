# Phase 10: Foundation & Clean Data Tab - Research

**Researched:** 2026-03-05
**Domain:** R Shiny module architecture, text cleaning, unicode normalization, audit trail infrastructure, local caching
**Confidence:** HIGH

## Summary

Phase 10 establishes the foundation for the v1.3 data cleaning pipeline by adding a new "Clean Data" tab with audit trail infrastructure, reference data loaders, and basic text transformations (unicode→ASCII, punctuation/whitespace stripping). The phase follows established project patterns: Shiny modules with shared `reactiveValues`, gated navigation using `nav_hide()`/`nav_show()`, and explicit action buttons (not auto-run).

The research confirms all technical building blocks are available: R's `stringi` package provides robust unicode-to-ASCII transliteration, ComptoxR has `clean_unicode()` and functional use category functions, and the project's existing module pattern provides clear guidance for the new Clean Data module. The audit trail structure (separate tibble with row_id, field, step, original_value, new_value, reason) follows standard R data recordkeeping patterns and integrates naturally with the existing `data_store` reactiveValues architecture.

**Primary recommendation:** Create `R/modules/mod_clean_data.R` following the Run Curation module pattern (explicit button, progress tracking, empty state for no-data), implement cleaning as a pipeline of small, testable functions in `R/cleaning_pipeline.R`, and seed reference lists from ComptoxR at app startup with local RDS caching in `data/reference_cache/` (git-ignored).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
**Cleaning Trigger & Flow:**
- Explicit "Run Cleaning" button on the Clean Data tab (matches existing "Run Curation" pattern)
- Before cleaning runs: empty state with friendly message + disabled button until data exists
- After cleaning runs: cleaned data auto-flows into data_store — no user confirmation step needed
- Cleaning is always re-runnable: button stays active, re-running cleans from raw data and resets all downstream state (tags, curation)
- Tag Columns tab is gated behind cleaning — must run cleaning before tagging is available

**Audit Trail Structure:**
- Separate audit tibble in data_store$cleaning_audit (not embedded in data columns)
- Columns: row_id, field, step, original_value, new_value, reason
- Full before/after detail for every transformation
- Re-running cleaning replaces the audit trail (fresh start from raw data each time)
- Audit trail is infrastructure only in this phase — no UI rendering yet (Phase 11+ adds visibility, Phase 14 exports it)

**Reference List Seeding:**
- ComptoxR-seeded at app startup with local disk caching
- Cache stored in data/reference_cache/ (git-ignored)
- If cache exists: load from disk instantly. If cache missing: download from ComptoxR, cache to disk
- User deletes cache → app re-downloads on next startup
- Silent loading with brief notification ("Reference lists loaded from cache" or "Downloading reference lists...")
- All three list types seeded in this phase: stop words, block list patterns, functional categories

**Tab Content & Layout:**
- Clean Data tab positioned after Data Preview, before Tag Columns in the nav
- Tab is gated — only visible after file upload (like Detection Info, Raw Data)
- Sidebar hides when Clean Data tab is active (like curation tabs)
- After cleaning: show cleaned data table (DT::datatable) + brief text summary above ("X rows cleaned, Y unicode chars fixed, Z fields trimmed")

### Claude's Discretion
- Exact empty state wording and icon
- DT table column formatting and pagination defaults
- Internal cleaning function organization (single function vs pipeline of small functions)
- How to handle edge cases where no transformations are needed (still show table, summary says "0 changes")
- Notification wording and duration
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-01 | User can see a per-row audit trail showing every cleaning transformation applied (what changed and why) | Audit trail tibble with row_id, field, step, original_value, new_value, reason columns; stored in data_store$cleaning_audit; R tibbles support this structure natively |
| INFRA-02 | User can configure reference lists (stop words, block lists, functional categories) that are loaded at app startup | ComptoxR provides `ct_functional_use()` for functional categories; custom R functions can load stop words and block patterns; local RDS caching via `saveRDS()`/`readRDS()` for startup performance |
| INFRA-03 | Unicode characters in chemical names and CAS fields are automatically cleaned to ASCII equivalents via ComptoxR::clean_unicode() | ComptoxR package has `clean_unicode()` function; alternative is stringi's `stri_trans_general(x, "latin-ascii")` for robust unicode→ASCII transliteration |
| INFRA-04 | Leading/trailing punctuation, whitespace, and extraction artifacts (underscores, asterisks) are automatically stripped from all text fields | stringr functions: `str_trim()` for whitespace, `str_remove_all(x, "[[:punct:]]")` for punctuation; can chain with dplyr mutate for field-by-field cleaning |
| UIUX-01 | User can access a "Clean Data" tab between Data Preview and Tag Columns in the gated workflow | bslib nav_panel in navset_underline; gated with nav_hide()/nav_show(); follows existing project pattern from app.R lines 79-105 |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | 1.7+ | Module framework | Project uses Shiny 1.5+ `moduleServer()` syntax throughout |
| bslib | 0.6+ | Nav containers & layout | Project uses bslib `page_sidebar()`, `nav_panel()`, `nav_hide()`/`nav_show()` |
| DT | 0.31+ | Interactive data tables | Already used in Data Preview, Review Results modules for datatable display |
| stringr | 1.5+ | Text cleaning | tidyverse standard for string manipulation; `str_trim()`, `str_remove_all()`, `str_squish()` |
| stringi | 1.8+ | Unicode transliteration | ICU-backed unicode transforms; `stri_trans_general(x, "latin-ascii")` for robust unicode→ASCII |
| ComptoxR | latest | Reference data & unicode cleaning | Already in project dependencies; provides `clean_unicode()`, `ct_functional_use()` |
| dplyr | 1.1+ | Data transformation | tidyverse standard for mutate pipelines; project uses throughout |
| purrr | 1.0+ | Functional programming | Project uses `safely()` for error handling in detection algorithms |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tibble | 3.2+ | Data frames | Used for audit trail structure (tibble with row_id, field, step, etc.) |
| fs | 1.6+ | File system operations | Cross-platform directory creation (`dir_create()`) for cache directory |
| digest | 0.6+ | File hashing | Optional: cache validation via MD5 hashing (project has checkpoint.R example) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| stringi | textclean::replace_non_ascii() | textclean attempts substitution (¢ → "cent") but less robust than ICU transliteration |
| DT | reactable | reactable has better theming but DT already integrated, more mature for Shiny |
| saveRDS/readRDS | qs::qsave/qread | qs is 2-10x faster but adds dependency; RDS sufficient for reference list caching |

**Installation:**
All dependencies already in project (see app.R lines 5-25). No new packages required.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── modules/
│   ├── mod_clean_data.R          # NEW: Clean Data tab module (UI + server)
├── cleaning_reference.R          # NEW: Reference list loaders (stop words, block list, functional categories)
├── cleaning_pipeline.R           # NEW: Text cleaning functions (unicode, trim, audit tracking)
data/
├── reference_cache/              # NEW: Local cache for ComptoxR-seeded lists (git-ignored)
    ├── functional_categories.rds
    ├── stop_words.rds
    ├── block_patterns.rds
```

### Pattern 1: Shiny Module with Shared reactiveValues
**What:** Modules communicate via shared `reactiveValues` passed as function parameter
**When to use:** All tab modules in this project
**Example:**
```r
# Source: Project app.R lines 111-119, mod_run_curation.R lines 54-55
# In app.R:
data_store <- reactiveValues(
  raw = NULL, clean = NULL, detection = NULL, file_info = NULL,
  cleaning_audit = NULL,  # NEW: audit trail tibble
  cleaned_data = NULL     # NEW: cleaned data (flows to data_store$clean)
)

# In module:
mod_clean_data_server <- function(id, data_store, on_cleaning_complete = NULL) {
  moduleServer(id, function(input, output, session) {
    # Read from data_store$raw
    # Write to data_store$cleaning_audit and data_store$cleaned_data
  })
}
```

### Pattern 2: Explicit Action Button with Empty State
**What:** Tab content conditional on data existence; action button triggers operations
**When to use:** Operations that transform data (cleaning, curation)
**Example:**
```r
# Source: Project mod_run_curation.R lines 13-44
tagList(
  conditionalPanel(
    condition = paste0("output['", ns("has_data"), "']"),
    actionButton(ns("run_cleaning"), "Run Cleaning", class = "btn-success btn-lg")
  ),
  conditionalPanel(
    condition = paste0("!output['", ns("has_data"), "']"),
    div(class = "text-center text-muted py-5",
      bsicons::bs_icon("magic", size = "3em"),
      h4("No data loaded"),
      p("Upload a file to begin cleaning.")
    )
  )
)

# Server logic:
output$has_data <- reactive({ !is.null(data_store$clean) })
outputOptions(output, "has_data", suspendWhenHidden = FALSE)
```

### Pattern 3: Local Disk Caching with RDS
**What:** Download reference data once, cache to disk, reload from disk on subsequent startups
**When to use:** Reference data that changes infrequently (functional use categories, stop words)
**Example:**
```r
# Source: WebSearch results for saveRDS/readRDS best practices
load_or_fetch_reference <- function(cache_path, fetch_fn, name) {
  if (file.exists(cache_path)) {
    readRDS(cache_path)
  } else {
    message(sprintf("Downloading %s from ComptoxR...", name))
    data <- fetch_fn()
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(data, cache_path)
    data
  }
}

# In app startup (before ui/server):
cache_dir <- here::here("data", "reference_cache")
functional_categories <- load_or_fetch_reference(
  file.path(cache_dir, "functional_categories.rds"),
  function() ComptoxR::ct_functional_use("", domain = "func_use"),
  "functional use categories"
)
```

### Pattern 4: Audit Trail Construction
**What:** Build tibble recording each transformation (row, field, original, new, reason)
**When to use:** Operations that modify user data (Phase 10 cleaning, Phase 11-12 CAS/name cleaning)
**Example:**
```r
# Audit trail tibble structure
audit_trail <- tibble::tibble(
  row_id = integer(),        # Original row number
  field = character(),       # Column name
  step = character(),        # Cleaning step name (e.g., "unicode_to_ascii", "trim_punctuation")
  original_value = character(),  # Value before transformation
  new_value = character(),       # Value after transformation
  reason = character()           # Human-readable explanation
)

# Example: Append audit record during cleaning
append_audit <- function(audit, row_id, field, step, orig, new, reason) {
  if (orig != new) {  # Only log if changed
    dplyr::bind_rows(audit, tibble::tibble(
      row_id = row_id, field = field, step = step,
      original_value = as.character(orig),
      new_value = as.character(new),
      reason = reason
    ))
  } else {
    audit
  }
}
```

### Pattern 5: Gated Navigation with Callbacks
**What:** Tabs hidden until prerequisites met; callbacks notify app when state changes
**When to use:** Sequential workflows (upload → clean → tag → curate)
**Example:**
```r
# Source: Project app.R lines 122-128, 163-169, 186-197
# In app.R server:
observe({
  req(data_store$cleaned_data)
  show_tab_with_pulse("tag_columns")
})

# In module server:
mod_clean_data_server <- function(id, data_store, on_cleaning_complete = NULL) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$run_cleaning, {
      # ... perform cleaning ...
      data_store$cleaned_data <- cleaned_df
      data_store$cleaning_audit <- audit_trail

      # Notify app that cleaning is complete
      if (!is.null(on_cleaning_complete)) {
        on_cleaning_complete()
      }
    })
  })
}
```

### Anti-Patterns to Avoid
- **Embedding audit data in columns:** Don't add "_original" columns to cleaned data — use separate audit tibble
- **Auto-run cleaning on upload:** User expects explicit control (matches curation pattern); auto-run confusing if re-upload
- **Tight coupling between modules:** Modules should communicate via data_store only, not direct function calls
- **Missing namespace (ns):** All input/output IDs in module UI MUST use `ns()` wrapper

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unicode normalization | Manual character replacement tables | `stringi::stri_trans_general(x, "latin-ascii")` or `ComptoxR::clean_unicode()` | ICU library handles 1000+ unicode edge cases (diacritics, ligatures, Greek letters); manual tables miss rare characters |
| Whitespace cleaning | Custom regex for spaces/tabs/newlines | `stringr::str_trim()` + `str_squish()` | Handles all unicode whitespace classes (U+0020, U+00A0, U+2000-U+200B, etc.) |
| File system operations | `file.exists()` + `dir.create()` conditionals | `fs::dir_create()` (creates recursively, idempotent) | Cross-platform, handles Windows/Unix path differences |
| Reactive coupling between modules | Custom event broadcasting system | `reactiveValues` + callback functions | Shiny-native pattern, debuggable with `reactlog` package |
| Tabular data transformation | Base R loops + rbind | `dplyr::mutate()` + `purrr::map_*()` | 10-100x faster for large data; vectorized operations avoid R's loop overhead |

**Key insight:** Text cleaning has 100+ edge cases (unicode variants, whitespace classes, punctuation types). Mature libraries encode years of bug fixes and character set knowledge. Re-implementing risks subtle data corruption (e.g., stripping valid chemical symbols).

## Common Pitfalls

### Pitfall 1: Unicode Corruption with Base R Functions
**What goes wrong:** Using `iconv(x, "UTF-8", "ASCII", sub = "")` silently drops characters without substitution
**Why it happens:** Base R iconv removes unmappable characters; doesn't transliterate
**How to avoid:** Use `stringi::stri_trans_general(x, "latin-ascii")` which maps à→a, ß→ss, etc. before stripping
**Warning signs:** Shortened strings, missing vowels in chemical names (e.g., "caf ine" instead of "caffeine")

### Pitfall 2: Over-Aggressive Punctuation Stripping
**What goes wrong:** Removing ALL punctuation breaks chemical names with hyphens (2,4-dichlorophenol) or CAS numbers
**Why it happens:** Regex `[[:punct:]]` includes hyphens, commas, periods in formulas
**How to avoid:** Strip only leading/trailing punctuation: `str_remove_all(x, "^[[:punct:]]+|[[:punct:]]+$")`
**Warning signs:** CAS numbers become "67641" instead of "67-64-1"; IUPAC names lose structure

### Pitfall 3: Cache Staleness
**What goes wrong:** Cached reference lists become outdated when ComptoxR updates, but app keeps using old cache
**Why it happens:** No cache invalidation strategy; users don't know to delete cache
**How to avoid:** Add cache timestamp check (optional Phase 10, required Phase 13); allow user to force refresh
**Warning signs:** New functional use categories missing, chemical searches fail for recently-added compounds

### Pitfall 4: Missing Namespace in Module UI
**What goes wrong:** Shiny inputs in module UI without `ns()` wrapper don't respond in module server
**Why it happens:** Forgetting that module IDs need namespacing (common when copying from non-module code)
**How to avoid:** Every `input$` reference in module server must match `ns("id")` in module UI
**Warning signs:** `input$run_cleaning` is NULL in module server despite button clicks

### Pitfall 5: Audit Trail Memory Explosion
**What goes wrong:** Large files (10,000+ rows × 50+ columns) produce 500,000+ audit records, crash browser when rendering
**Why it happens:** Audit trail stores EVERY field transformation, not just changed values
**How to avoid:** Only append audit record if `original_value != new_value` (see Pattern 4 example)
**Warning signs:** Slow cleaning operations, browser tab freezes, R session memory usage spikes

### Pitfall 6: Reference List Download Blocking UI
**What goes wrong:** App startup hangs for 30+ seconds while downloading functional use categories from ComptoxR
**Why it happens:** ComptoxR API calls in app.R top-level code block Shiny initialization
**How to avoid:** Use async loading with `shiny::withProgress()` after UI renders, OR require cache pre-population in deployment
**Warning signs:** "Grey screen of death" on first app launch, no loading indicator

## Code Examples

Verified patterns from official sources and project code:

### Unicode to ASCII Transliteration
```r
# Source: stringi package documentation (https://stringi.gagolewski.com/rapi/stri_trans_general.html)
# Handles diacritics, ligatures, Greek letters
clean_unicode <- function(x) {
  stringi::stri_trans_general(x, "latin-ascii")
}

# Examples:
# "café" → "cafe"
# "Größe" → "Grosse"
# "α-tocopherol" → "a-tocopherol"

# Alternative: ComptoxR wrapper (if available)
clean_unicode_comptox <- function(x) {
  ComptoxR::clean_unicode(x)
}
```

### Whitespace & Punctuation Cleaning
```r
# Source: stringr documentation (https://stringr.tidyverse.org/reference/str_trim.html)
clean_text_field <- function(x) {
  x %>%
    stringr::str_trim() %>%              # Remove leading/trailing whitespace
    stringr::str_squish() %>%            # Collapse internal whitespace to single space
    stringr::str_remove_all("^[_*]+") %>%  # Strip leading underscores, asterisks
    stringr::str_remove_all("[_*]+$")      # Strip trailing underscores, asterisks
}

# For full punctuation stripping (use carefully):
strip_punctuation <- function(x) {
  # Only strip leading/trailing to preserve internal structure
  stringr::str_remove_all(x, "^[[:punct:]]+|[[:punct:]]+$")
}
```

### Reference List Loader with Caching
```r
# Source: Project checkpoint.R pattern + WebSearch results for saveRDS best practices
load_functional_categories <- function(cache_path) {
  if (file.exists(cache_path)) {
    message("Loading functional use categories from cache...")
    readRDS(cache_path)
  } else {
    message("Downloading functional use categories from ComptoxR...")
    # ComptoxR ct_functional_use returns all categories when query is empty
    categories <- ComptoxR::ct_functional_use("", domain = "func_use")

    # Ensure cache directory exists
    fs::dir_create(dirname(cache_path), recurse = TRUE)

    # Save to cache (uncompressed for speed)
    saveRDS(categories, cache_path, compress = FALSE)

    showNotification(
      "Reference lists downloaded and cached.",
      type = "message",
      duration = 3
    )

    categories
  }
}

# Usage in app.R (before ui/server definitions):
functional_categories <- load_functional_categories(
  here::here("data", "reference_cache", "functional_categories.rds")
)
```

### Audit Trail Builder
```r
# Source: Project audit trail requirements + R tibble best practices
build_audit_trail <- function(df_original, df_cleaned, step_name, reason_fn) {
  audit_records <- list()

  for (col in names(df_cleaned)) {
    if (col %in% names(df_original)) {
      orig_vals <- df_original[[col]]
      new_vals <- df_cleaned[[col]]

      for (i in seq_along(orig_vals)) {
        if (!identical(orig_vals[i], new_vals[i])) {
          audit_records[[length(audit_records) + 1]] <- tibble::tibble(
            row_id = i,
            field = col,
            step = step_name,
            original_value = as.character(orig_vals[i]),
            new_value = as.character(new_vals[i]),
            reason = reason_fn(orig_vals[i], new_vals[i])
          )
        }
      }
    }
  }

  dplyr::bind_rows(audit_records)
}

# Example usage:
audit_unicode <- build_audit_trail(
  df_original = raw_data,
  df_cleaned = unicode_cleaned_data,
  step_name = "unicode_to_ascii",
  reason_fn = function(orig, new) {
    sprintf("Converted unicode characters: %s → %s", orig, new)
  }
)
```

### Module Server with Cleaning Pipeline
```r
# Source: Project mod_run_curation.R pattern + audit trail requirements
mod_clean_data_server <- function(id, data_store, on_cleaning_complete = NULL) {
  moduleServer(id, function(input, output, session) {

    # Enable button when data exists
    observe({
      if (!is.null(data_store$clean)) {
        shinyjs::enable("run_cleaning")
      } else {
        shinyjs::disable("run_cleaning")
      }
    })

    # Run cleaning pipeline
    observeEvent(input$run_cleaning, {
      req(data_store$clean)

      shinyjs::disable("run_cleaning")

      tryCatch({
        withProgress(message = "Cleaning data...", value = 0, {
          # Step 1: Unicode cleaning
          incProgress(0.3, detail = "Converting unicode to ASCII")
          df_unicode <- dplyr::mutate(
            data_store$clean,
            dplyr::across(where(is.character), clean_unicode)
          )
          audit_unicode <- build_audit_trail(
            data_store$clean, df_unicode,
            "unicode_to_ascii",
            function(o, n) sprintf("Unicode → ASCII: %s → %s", o, n)
          )

          # Step 2: Whitespace & punctuation trimming
          incProgress(0.6, detail = "Trimming whitespace and punctuation")
          df_cleaned <- dplyr::mutate(
            df_unicode,
            dplyr::across(where(is.character), clean_text_field)
          )
          audit_trim <- build_audit_trail(
            df_unicode, df_cleaned,
            "trim_whitespace_punctuation",
            function(o, n) sprintf("Trimmed: %s → %s", o, n)
          )

          # Combine audit trails
          audit_total <- dplyr::bind_rows(audit_unicode, audit_trim)

          # Store results
          data_store$cleaned_data <- df_cleaned
          data_store$cleaning_audit <- audit_total

          incProgress(1.0, detail = "Complete")

          # Show summary
          n_changes <- nrow(audit_total)
          showNotification(
            sprintf("Cleaning complete: %d transformations applied", n_changes),
            type = "message",
            duration = 5
          )

          # Callback to app for navigation
          if (!is.null(on_cleaning_complete)) {
            on_cleaning_complete()
          }
        })
      }, error = function(e) {
        showNotification(
          paste("Cleaning failed:", e$message),
          type = "error",
          duration = NULL
        )
      }, finally = {
        shinyjs::enable("run_cleaning")
      })
    })

    # Has data indicator for conditional UI
    output$has_data <- reactive({ !is.null(data_store$clean) })
    outputOptions(output, "has_data", suspendWhenHidden = FALSE)
  })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `callModule()` for invoking modules | `moduleServer()` | Shiny 1.5.0 (2021) | Simpler syntax, no need for separate `callModule()` wrapper |
| Base R `iconv()` for encoding | `stringi::stri_trans_general()` | stringi 1.0+ (2014) | ICU-backed transliteration vs encoding conversion; preserves meaning |
| Global `reactiveValues` as implicit global | Explicit parameter passing | Engineering Shiny book (2020) | Modules testable in isolation, clearer data flow |
| `save()`/`load()` for caching | `saveRDS()`/`readRDS()` | Always preferred | Single object, no workspace pollution, faster for large objects |
| `hideTab()`/`showTab()` (base Shiny) | `nav_hide()`/`nav_show()` (bslib) | bslib 0.3+ (2022) | Works with modern nav containers (navset_underline, etc.) |

**Deprecated/outdated:**
- `callModule()`: Replaced by `moduleServer()` in Shiny 1.5+; still works but not recommended
- `shinyjs::hide()`/`show()` for tabs: Requires CSS selector knowledge; prefer semantic nav functions
- Base R `trimws()`: Works but doesn't handle unicode whitespace (U+00A0, U+2000-U+200B); use stringr

## Open Questions

1. **ComptoxR API rate limits for reference list downloads**
   - What we know: ComptoxR functions connect to EPA CompTox API; requires API key
   - What's unclear: Rate limits, timeout behavior, fallback if API unavailable
   - Recommendation: Implement retry logic with exponential backoff; allow app to run with empty reference lists if download fails (Phase 13 adds user editing anyway)

2. **Reference list update frequency**
   - What we know: EPA CompTox functional use categories updated periodically
   - What's unclear: How often categories change, whether cache invalidation needed
   - Recommendation: Phase 10 uses indefinite cache; Phase 13 adds manual "Refresh Cache" button; future phase could add timestamp-based validation

3. **Audit trail performance at scale**
   - What we know: Audit trail stores row_id + field for every transformation
   - What's unclear: Performance threshold (1K rows? 10K rows? 100K rows?)
   - Recommendation: Only log changes (orig != new); if performance issues arise, add audit trail pagination or export-only (don't render in UI)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.2+ |
| Config file | None — tests run via `testthat::test_dir("tests")` |
| Quick run command | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 | Audit trail records all transformations with row_id, field, step, original_value, new_value, reason | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R', filter = 'audit')"` | ❌ Wave 0 |
| INFRA-02 | Reference lists load from cache if exists, download if missing | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_reference.R', filter = 'cache')"` | ❌ Wave 0 |
| INFRA-03 | Unicode characters cleaned to ASCII (à→a, ß→ss, etc.) | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R', filter = 'unicode')"` | ❌ Wave 0 |
| INFRA-04 | Leading/trailing whitespace and punctuation stripped | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R', filter = 'trim')"` | ❌ Wave 0 |
| UIUX-01 | Clean Data tab renders between Data Preview and Tag Columns | smoke | `Rscript -e "testthat::test_file('tests/test_modules_render.R', filter = 'clean_data')"` | ✅ (extend existing) |

### Sampling Rate
- **Per task commit:** `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R')"` (< 5 seconds)
- **Per wave merge:** `Rscript -e "testthat::test_dir('tests')"` (full suite, ~30 seconds)
- **Phase gate:** Full suite green + manual smoke test in browser before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_cleaning_pipeline.R` — covers INFRA-01, INFRA-03, INFRA-04
- [ ] `tests/test_cleaning_reference.R` — covers INFRA-02
- [ ] Extend `tests/test_modules_render.R` with Clean Data module — covers UIUX-01

## Sources

### Primary (HIGH confidence)
- [Shiny Module Communication - Rtask](https://rtask.thinkr.fr/communication-between-modules-and-its-whims/) - reactiveValues pattern
- [Shiny Modules Official Documentation - Posit](https://shiny.posit.co/r/articles/improve/modules/) - moduleServer() syntax
- [stringr str_trim Documentation - tidyverse](https://stringr.tidyverse.org/reference/str_trim.html) - whitespace removal
- [stringi stri_trans_general Documentation](https://stringi.gagolewski.com/rapi/stri_trans_general.html) - unicode transliteration
- [bslib Navigation Containers - rstudio](https://rstudio.github.io/bslib/reference/navset.html) - nav_hide/nav_show
- [DT DataTables Options - rstudio](https://rstudio.github.io/DT/options.html) - datatable configuration
- [testthat Unit Testing - r-lib](https://testthat.r-lib.org/) - test framework

### Secondary (MEDIUM confidence)
- [EPA CompTox Functional Use Categories](https://comptox.epa.gov/chemexpo/functional_use_categories/) - reference data structure
- [saveRDS/readRDS Performance - GeeksforGeeks](https://www.geeksforgeeks.org/r-language/saverds-and-readrds-functions-in-r/) - caching patterns
- [Shiny Dynamic Tab Visibility - Posit](https://shiny.posit.co/r/reference/shiny/1.7.0/showtab.html) - hideTab/showTab legacy functions
- [Data Transformation with dplyr - r4ds](https://r4ds.had.co.nz/transform.html) - mutate patterns

### Tertiary (LOW confidence)
- ComptoxR package: Confirmed installed in project with `clean_unicode()`, `ct_functional_use()` functions; documentation sparse but functions verified via `args()` inspection
- Audit trail best practices: No R-specific standard found; followed general data recordkeeping principles (row_id, field, before/after, timestamp)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages already in project, existing patterns verified in codebase
- Architecture: HIGH - Module pattern established in Phase 9, gated navigation pattern verified in app.R
- Pitfalls: MEDIUM - Based on common R/Shiny issues; unicode pitfall verified via stringi docs; audit trail performance is estimate
- Reference lists: MEDIUM - ComptoxR functions verified but API behavior/rate limits not fully documented
- Test infrastructure: HIGH - testthat already in project with established patterns

**Research date:** 2026-03-05
**Valid until:** 30 days (stable R ecosystem; ComptoxR API may change)

---

*Phase 10 research complete. Ready for planning: create PLAN.md files with task breakdowns.*
