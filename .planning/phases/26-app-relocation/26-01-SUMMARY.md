---
phase: 26-app-relocation
plan: 01
subsystem: package-structure
tags: [shiny, app-relocation, system.file, run_app]
dependency_graph:
  requires: [24-package-scaffolding, 25-source-file-cleanup]
  provides: [run_app-launcher, inst-app-structure, reference-cache-relocation]
  affects: [app-startup, module-exports]
tech_stack:
  added: []
  patterns: [system.file-for-inst-paths, shiny-module-exports]
key_files:
  created:
    - inst/app/app.R
    - inst/extdata/reference_cache/block_patterns.rds
    - inst/extdata/reference_cache/functional_categories.rds
    - inst/extdata/reference_cache/isotope_lookup.rds
    - inst/extdata/reference_cache/stop_words.rds
    - inst/extdata/reference_cache/strip_terms.rds
    - R/run_app.R
    - man/run_app.Rd
    - man/mod_*_ui.Rd (8 files)
    - man/mod_*_server.Rd (8 files)
  modified:
    - DESCRIPTION (Shiny packages moved to Imports)
    - NAMESPACE (16 module exports added, run_app export added)
    - R/mod_*.R (8 files moved from R/modules/ to R/, @export tags added)
  deleted:
    - app.R (root - replaced by inst/app/app.R)
    - R/modules/ (directory removed - files moved to R/)
decisions:
  - Moved Shiny packages (shiny, bslib, bsicons, reactable, reactable.extras, shinyjs) from Suggests to Imports - required for roxygen2 to process module files
  - Moved module files from R/modules/ to R/ - roxygen2 does not process subdirectories by default
  - Kept library() calls in inst/app/app.R for Shiny UI packages - DSL-style syntax cleaner for user-facing code
metrics:
  duration_seconds: 752
  completed: 2026-04-13T20:49:00Z
  tasks: 4
  files_changed: 27
---

# Phase 26 Plan 01: App Relocation Summary

Shiny app relocated to inst/app/ with run_app() launcher; reference cache moved to inst/extdata/; package installs and app launches via chemreg::run_app().

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Create inst/ directories and relocate reference cache | 941d288 | Created inst/app/, inst/extdata/reference_cache/; copied 5 RDS files |
| 2 | Create R/run_app.R with exported launcher | e2ed886 | run_app() function with system.file("app", package="chemreg"); roxygen docs |
| 3 | Relocate and modify app.R to inst/app/app.R | fbe1595 | Removed source() loop; kept Shiny library() calls; system.file() for cache; moved modules to R/; exported 16 module functions |
| 4 | Verify installation and run_app() launch | (verification) | devtools::install() successful; smoke test passed "Listening on http://127.0.0.1:3939" |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] roxygen2 does not process R/modules/ subdirectory**
- **Found during:** Task 3
- **Issue:** Module files in R/modules/ were not being processed by roxygen2, so @export tags were ignored
- **Fix:** Moved all 8 module files from R/modules/ to R/ root directory
- **Files modified:** R/mod_*.R (8 files)
- **Commit:** fbe1595

**2. [Rule 3 - Blocking] Shiny packages in Suggests prevent roxygen2 from loading module functions**
- **Found during:** Task 3
- **Issue:** Module files use Shiny functions (NS, moduleServer, etc.) which aren't available when Shiny is only in Suggests; roxygen2::load_source fails to load modules
- **Fix:** Moved bslib, bsicons, reactable, reactable.extras, shiny, shinyjs from Suggests to Imports in DESCRIPTION
- **Files modified:** DESCRIPTION
- **Commit:** fbe1595
- **Note:** This is a reasonable change - users running the Shiny app will need these packages anyway

## Verification Results

### devtools::install()
- Package built and installed successfully
- R CMD check warnings about R version dependency (>= 4.1.0) due to pipe syntax - acceptable

### System.file() paths verified
- `system.file("app", package = "chemreg")` returns valid path
- `system.file("extdata", "reference_cache", package = "chemreg")` returns valid path
- All 5 reference cache RDS files accessible

### Shiny Smoke Test
- chemreg::run_app(port = 3939, launch.browser = FALSE) started successfully
- Reference lists loaded from inst/extdata/reference_cache/
- "Listening on http://127.0.0.1:3939" message confirmed

## Success Criteria Met

- [x] APP-01: Shiny app lives at inst/app/app.R
- [x] APP-02: run_app() exported and uses system.file("app", package = "chemreg")
- [x] APP-03: Reference cache uses system.file("extdata", "reference_cache", package = "chemreg")
- [x] APP-04: inst/app/app.R has no source() loop
- [x] APP-05: chemreg::run_app() launches successfully after package install

## Known Stubs

None - all functionality is complete.

## Self-Check: PASSED

- [x] inst/app/app.R exists (337 lines)
- [x] inst/extdata/reference_cache/*.rds (5 files)
- [x] R/run_app.R exists with @export
- [x] NAMESPACE contains export(run_app) and 16 mod_* exports
- [x] All 3 task commits verified (941d288, e2ed886, fbe1595)
- [x] devtools::install() completed without error
- [x] chemreg::run_app() smoke test passed
