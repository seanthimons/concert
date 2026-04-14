# Roadmap: ChemReg

## Milestones

- ✅ **v1.5 Disagreement Enrichment** — Phases 17-18 (shipped 2026-03-13)
- ✅ **v1.6 Cleaning Ruleset Fixes** — Phases 19-21 (shipped 2026-03-20)
- ✅ **v1.7 UI Polish & Isotope Cleaning** — Phases 22-23 (shipped 2026-04-13)
- 🔵 **v1.8 R Package Migration** — Phases 24-28 (active)

## Phases

<details>
<summary>✅ v1.5 Disagreement Enrichment (Phases 17-18) — SHIPPED 2026-03-13</summary>

### Phase 17: Enrichment Pipeline
**Goal**: Enrich disagreement candidates with CompTox metadata
**Plans**: Complete

### Phase 18: Comparison Modal + Export
**Goal**: Surface enrichment in resolution UI and export
**Plans**: Complete

</details>

<details>
<summary>✅ v1.6 Cleaning Ruleset Fixes (Phases 19-21) — SHIPPED 2026-03-20</summary>

- [x] Phase 19: Synonym Splitter Comma Protection (1/1 plans) — completed 2026-03-19
- [x] Phase 20: Roman Numeral Handling (1/1 plans) — completed 2026-03-19
- [x] Phase 21: Unicode Cleaning Coverage (1/1 plans) — completed 2026-03-20

</details>

<details>
<summary>✅ v1.7 UI Polish & Isotope Cleaning (Phases 22-23) — SHIPPED 2026-04-13</summary>

- [x] Phase 22: UI Polish (1/1 plans) — completed 2026-04-01
- [x] Phase 23: Isotope Cleaning (2/2 plans) — completed 2026-04-02

</details>

<details open>
<summary>🔵 v1.8 R Package Migration (Phases 24-28) — ACTIVE</summary>

- [ ] **Phase 24: Package Scaffolding** — DESCRIPTION, NAMESPACE, devtools::document()
  Plans:
  - [x] 24-01-PLAN.md — Create DESCRIPTION/LICENSE/NAMESPACE, add @export tags, verify install
- [ ] **Phase 25: Source File Cleanup** — strip library() calls, :: coverage, devtools::check()
  Plans:
  - [x] 25-01-PLAN.md — Remove library() calls, add @importFrom magrittr pipe, run devtools::check()
- [ ] **Phase 26: App Relocation** — inst/app/, run_app(), system.file() paths
  Plans:
  - [x] 26-01-PLAN.md — Relocate app to inst/app/, create run_app() launcher, update reference cache paths
- [ ] **Phase 27: Headless Pipeline** — curate_headless() wired end-to-end
  Plans:
  - [x] 27-01-PLAN.md — Create curate_headless() function, promote writexl to Imports, smoke test
- [ ] **Phase 28: Test Migration** — tests/testthat/ structure, fix pre-existing failure

</details>

## Phase Details

### Phase 24: Package Scaffolding
**Goal**: The project is a valid, installable R package that loads without errors
**Depends on**: Nothing (first phase of v1.8)
**Requirements**: PKG-01, PKG-02, PKG-03
**Success Criteria** (what must be TRUE):
  1. Developer runs `devtools::install()` and then `library(chemreg)` without any errors or warnings about missing fields
  2. `DESCRIPTION` file contains correct Imports and Suggests lists matching the actual package dependencies
  3. `devtools::document()` succeeds and generates a valid `NAMESPACE` file from roxygen2 tags
**Plans:** 1/1 plans complete
**UI hint**: no

### Phase 25: Source File Cleanup
**Goal**: All R source files are package-compatible — no bare library() calls, full :: notation, devtools::check() passes
**Depends on**: Phase 24
**Requirements**: SRC-01, SRC-02, SRC-03, SRC-04
**Success Criteria** (what must be TRUE):
  1. `R/cleaning_pipeline.R` contains no `library()` calls and all external functions are called with `pkg::fn()` notation
  2. `R/cleaning_reference.R` contains no `library()` calls and all external functions are called with `pkg::fn()` notation
  3. `R/consensus.R` contains no `library()` calls and all external functions are called with `pkg::fn()` notation
  4. `devtools::check()` completes with zero errors (non-standard file warnings are acceptable)
**Plans:** 1/1 plans complete
**UI hint**: no

### Phase 26: App Relocation
**Goal**: The Shiny app lives under inst/app/ and is launchable via chemreg::run_app() after package install
**Depends on**: Phase 25
**Requirements**: APP-01, APP-02, APP-03, APP-04, APP-05
**Success Criteria** (what must be TRUE):
  1. `inst/app/app.R` exists and the project root no longer contains `app.R`
  2. `chemreg::run_app()` launches the Shiny app without errors after `devtools::install()`
  3. Reference cache paths use `system.file("extdata", "reference_cache", package = "chemreg")` — no `here::here()` calls remain in package source files
  4. `inst/app/app.R` contains no `source()` loop (all functions resolve from the package namespace in installed mode)
**Plans:** 1/1 plans complete
Plans:
- [ ] 26-01-PLAN.md — Relocate app to inst/app/, create run_app() launcher, update reference cache paths
**UI hint**: yes

### Phase 27: Headless Pipeline
**Goal**: Developers can run the full curation pipeline from a script without launching the Shiny UI
**Depends on**: Phase 26
**Requirements**: HDL-01, HDL-02, HDL-03, HDL-04
**Success Criteria** (what must be TRUE):
  1. `curate_headless()` is discoverable via `?curate_headless` after package install (exported with roxygen docs)
  2. Running `curate_headless(input_path = "uncurated_sswqs.csv", output_path = "out.xlsx", tag_map = list(...))` produces a valid XLSX file without errors
  3. The returned list from `curate_headless()` contains `$data` (curated data frame) and `$audit_trail` (audit tibble) accessible after the call
**Plans:** 1/1 plans complete
Plans:
- [ ] 27-01-PLAN.md — Create curate_headless() function, promote writexl to Imports, smoke test
**UI hint**: no

### Phase 28: Test Migration
**Goal**: All tests run under devtools::test() with a green result — no failures, standard testthat structure
**Depends on**: Phase 27
**Requirements**: TST-01, TST-02, TST-03, TST-04
**Success Criteria** (what must be TRUE):
  1. `tests/testthat.R` runner file exists and `devtools::test()` discovers and executes all tests
  2. All test files follow `tests/testthat/test-*.R` naming convention (dash, not underscore)
  3. The pre-existing `load_all_reference_lists` key-count failure is fixed — test now expects 4 keys including `strip_terms`
  4. `devtools::test()` completes with zero failures and zero errors across all test files
**Plans**: TBD
**UI hint**: no

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 19. Synonym Splitter Comma Protection | v1.6 | 1/1 | Complete | 2026-03-19 |
| 20. Roman Numeral Handling | v1.6 | 1/1 | Complete | 2026-03-19 |
| 21. Unicode Cleaning Coverage | v1.6 | 1/1 | Complete | 2026-03-20 |
| 22. UI Polish | v1.7 | 1/1 | Complete | 2026-04-01 |
| 23. Isotope Cleaning | v1.7 | 2/2 | Complete | 2026-04-02 |
| 24. Package Scaffolding | v1.8 | 1/1 | Complete    | 2026-04-13 |
| 25. Source File Cleanup | v1.8 | 1/1 | Complete    | 2026-04-13 |
| 26. App Relocation | v1.8 | 1/1 | Complete    | 2026-04-13 |
| 27. Headless Pipeline | v1.8 | 1/1 | Complete    | 2026-04-14 |
| 28. Test Migration | v1.8 | 0/1 | Not started | - |
