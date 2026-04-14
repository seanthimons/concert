# Phase 24: Package Scaffolding — Context

**Phase Goal:** The project is a valid, installable R package that loads without errors

**Requirements:** PKG-01, PKG-02, PKG-03

---

## Decisions

### 1. Package Metadata

**Decision:** Use git author info

| Field | Value |
|-------|-------|
| Author | Sean Thimons |
| Email | thimons.sean@gmail.com |
| Role | `c("aut", "cre")` |

**Rationale:** Git config provides canonical author identity. ORCID is optional — omit for now.

### 2. Export Scope

**Decision:** Export all public-facing functions in Phase 24

Functions in these files should be exported:
- `R/data_detection.R` — detection ensemble entry points
- `R/file_handlers.R` — file reading/validation
- `R/cleaning_pipeline.R` — cleaning functions
- `R/cleaning_reference.R` — reference list loading
- `R/consensus.R` — DTXSID consensus logic
- `R/curation.R` — CompTox API pipeline
- `R/export_helpers.R` — output formatting

Internal helper functions (those not intended for direct user calls) get no `@export` tag.

**Rationale:** Phase 27 (headless pipeline) needs a complete API surface. Exporting early establishes the public contract. The alternative (minimal exports, grow later) adds churn and risks forgetting functions.

### 3. License

**Decision:** MIT License

```
MIT License

Copyright (c) 2026 Sean Thimons

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Rationale:** MIT is the most permissive common license. The DESCRIPTION says `License: MIT + file LICENSE`, so we need this LICENSE file.

### 4. Imports vs Suggests Split (Confirmed)

Per REQUIREMENTS.md PKG-02:

**Imports (required for core functions):**
- dplyr, purrr, stringr, stringi, tibble, tidyr
- readxl, readr, rio, janitor
- rlang, tidyselect, fs, here
- ComptoxR

**Suggests (only for Shiny/testing):**
- shiny, bslib, bsicons, reactable, reactable.extras, shinyjs
- writexl
- testthat (>= 3.0.0)

**Rationale:** Headless users shouldn't need Shiny installed. This split keeps the core dependency footprint small.

### 5. Version Number

**Decision:** Start at `0.1.0`

**Rationale:** Semantic versioning convention for initial development. Not claiming production stability yet.

---

## Claude's Discretion

The following can be decided during implementation:

- **RoxygenNote version**: Use whatever version is installed
- **Roxygen tag style**: Prefer `@export` with `@importFrom` for selective imports; avoid blanket `@import`
- **NAMESPACE structure**: Let roxygen2 generate it — no manual edits
- **Description prose**: Keep it concise, one or two sentences max

---

## Deferred Ideas

*(Captured for future milestones)*

- ORCID in author metadata
- BugReports URL (needs public GitHub repo)
- URL field for pkgdown site

---

## Researcher Guidance

When researching Phase 24:
- Look for R package scaffolding best practices (devtools, usethis workflows)
- Verify ComptoxR is on CRAN or if we need `Remotes:` field for GitHub install
- Check if any imports need version constraints

---

## Next Steps

1. Run `/gsd:plan-phase 24` to create the execution plan
2. Plan should cover: DESCRIPTION, LICENSE, minimal roxygen headers, devtools::document(), verification
