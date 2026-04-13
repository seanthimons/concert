# Phase 25: Source File Cleanup - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert three R source files to package-compatible form: remove all bare `library()` calls, ensure full `pkg::fn()` notation for external functions, and pass `devtools::check()` with zero errors.

Target files:
- `R/cleaning_pipeline.R`
- `R/cleaning_reference.R`
- `R/consensus.R`

</domain>

<decisions>
## Implementation Decisions

### Namespacing Strategy

- **D-01:** Use explicit `pkg::fn()` notation for all external function calls (carried forward from Phase 24 decision on roxygen style)
- **D-02:** Add `@importFrom magrittr %>%` in files that use the pipe operator — this is the standard R package convention
- **D-03:** Add `@importFrom rlang .data` in files that use `.data$` pronoun for tidy evaluation safety
- **D-04:** Do not use blanket `@import pkg` — prefer selective imports to avoid namespace pollution

### check() Tolerance

- **D-05:** `devtools::check()` must pass with **zero errors** (per SRC-04)
- **D-06:** NOTEs about non-standard files (`.planning/`, `data/`, etc.) are acceptable — do not clutter `.Rbuildignore` to silence informational notes
- **D-07:** Existing `.Rbuildignore` entries are sufficient (Phase 24 already added necessary entries)

### Claude's Discretion

- Order of namespacing work across the three files
- Whether to batch similar function prefixing (e.g., all `dplyr::` calls at once)
- Minor roxygen documentation improvements while editing (but don't expand scope to full documentation)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — SRC-01 through SRC-04 define the acceptance criteria

### Prior Phase
- `.planning/phases/24-package-scaffolding/24-CONTEXT.md` — Decisions on roxygen style, NAMESPACE management

### R Package Standards
- No external specs required — standard R package conventions apply (Writing R Extensions manual)

</canonical_refs>

<code_context>
## Existing Code Insights

### Current State

| File | library() calls | Existing :: usage | Effort |
|------|-----------------|-------------------|--------|
| `R/cleaning_pipeline.R` | 4 lines (10-13) | 178 | Low — mostly done |
| `R/cleaning_reference.R` | 3 lines (8-10) | 24 | Medium |
| `R/consensus.R` | 2 lines (6-7) | 0 | High — full conversion |

### Packages to Namespace

Based on current `library()` calls:
- `dplyr` — used in all three files
- `tibble` — used in all three files
- `stringr` — used in `cleaning_pipeline.R`
- `stringi` — used in `cleaning_pipeline.R`
- `fs` — used in `cleaning_reference.R`

### Already Namespaced

`cleaning_pipeline.R` already uses explicit namespacing extensively:
- `stringr::str_*`, `dplyr::mutate`, `dplyr::across`, `ComptoxR::*`

This establishes the pattern to follow for the other files.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard R package namespacing conventions apply.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 25-source-file-cleanup*
*Context gathered: 2026-04-13*
