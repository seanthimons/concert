# Phase 26: App Relocation — Context

**Created:** 2026-04-13
**Phase goal:** The Shiny app lives under inst/app/ and is launchable via chemreg::run_app() after package install

---

## Requirements Being Addressed

- APP-01: Shiny app lives at `inst/app/app.R` (moved from project root)
- APP-02: `R/run_app.R` exports `run_app()` that launches the app via `system.file("app", package = "chemreg")`
- APP-03: Reference cache loaded via `system.file("extdata", "reference_cache", package = "chemreg")` — no `here::here()` calls remain in package source files
- APP-04: `inst/app/app.R` has no `source()` loop (functions come from package namespace in installed mode)
- APP-05: User can launch the app via `chemreg::run_app()` after package install

---

## Decisions

### 1. Development Workflow
**Decision:** Standard package workflow — developers must run `devtools::load_all()` before `chemreg::run_app()` during development.

**Rationale:** This is the conventional R package approach. No dual-mode detection or source() loop in inst/app/app.R. Clean separation between development and installed modes.

**Implication:** No conditional sourcing logic in app.R. Developers who want to iterate must use load_all() workflow.

### 2. Reference Cache Location
**Decision:** Move reference cache to `inst/extdata/reference_cache/`

**Access pattern:**
```r
cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
reference_lists <- load_all_reference_lists(cache_dir)
```

**Rationale:** `inst/extdata/` is the standard R convention for external data files that aren't lazily loaded. The reference cache RDS files (~280KB) fit this pattern — they're loaded on demand by the app.

**Files to relocate:**
- block_patterns.rds
- functional_categories.rds
- isotope_lookup.rds
- stop_words.rds
- strip_terms.rds

### 3. library() Calls in inst/app/app.R
**Decision:** Keep explicit library() calls for Shiny UI packages.

**What to keep:**
```r
library(shiny)
library(bslib)
library(bsicons)
library(reactable)
library(reactable.extras)
library(shinyjs)
```

**What to remove:** library() calls for packages that are now in the chemreg namespace via Imports (dplyr, purrr, stringr, etc.).

**Rationale:** Shiny apps conventionally use library() for UI dependencies. The DSL-style syntax (page_sidebar, sidebar, nav_panel) is cleaner than full namespace qualification. The app.R is user-facing code, not package internals.

---

## Current State (Pre-Phase)

### Files to be modified
- `app.R` → relocate to `inst/app/app.R` with modifications
- `data/reference_cache/` → relocate to `inst/extdata/reference_cache/`

### Files to be created
- `R/run_app.R` — exported function to launch the app
- `inst/app/` — directory for app.R
- `inst/extdata/reference_cache/` — directory for cache files

### Key changes in inst/app/app.R
1. Remove the source() loop (lines 35-37 of current app.R)
2. Remove library() calls for non-UI packages (now from chemreg namespace)
3. Change reference cache path from `here::here()` to `system.file()`
4. Remove custom operators (`%ni%`, `%||%`) — these should be in the package namespace

---

## Out of Scope (Deferred)

- Handling dev_app.R or dev mode entry points (users should use load_all())
- Modifying tests/ directory source() calls (Phase 28 scope)
- Keeping original app.R at root as development convenience (would cause confusion)

---

## Claude's Discretion

The following can be decided during planning/execution:

- Exact order of operations (create dirs first vs move files first)
- Whether to add helpful comments in inst/app/app.R explaining the structure
- Error handling approach in run_app() for missing dependencies
