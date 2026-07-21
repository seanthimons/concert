---
# concert-eg2o
title: Multi-analyte detection misses ' & ' and ' / ' separators
status: done
type: bug
priority: normal
tags:
    - github:issue
    - github:54
created_at: 2026-07-20T22:49:48Z
updated_at: 2026-07-21T00:00:00Z
---

## Problem

Multi-analyte detection recognizes only naked ` + ` and ` and ` separators. Names using ` & ` or ` / ` (e.g. `"acetone & ethanol"`, `"toluene / benzene"`) are never flagged — a silent false negative: the row never reaches the "Rows Needing Review" surface.

Three functions share the same two-separator pattern and must stay in lockstep:

- `precheck_multi_analyte()` — `R/cleaning_pipeline.R:481`, pattern `(?<!\()\s\+\s(?!\))|(?i)\s+and\s+`
- `flag_multi_analyte()` — `NAKED_PLUS_PATTERN` + `NAKED_AND_PATTERN`
- `suggest_multi_analyte_parts()` — `gsub` on ` + ` and ` and `

## Evidence

Two tests already assert `&` / `/` support and fail on `main` today (quarantined snapshots in `tests/testthat/_problems/test-precheck-infrastructure-279.R` and `-280.R`):

- `test-precheck-infrastructure.R:297` — "detects ' & ' and ' / ' separators" expects `est_changes = 2`, gets `0`.

## Risk / caveats

`/` is dangerous: it collides with units (`mg/L`, `w/w`) and the numeric ratio patterns `extract_mixture()` already handles (`1.5:1`). Space-flanked matching (like the existing ` and `) is required. Decide explicitly whether ` / ` should split at all, or only ` & `.

## Definition of done

- Add ` & ` (and a decision on ` / `) to all three functions in lockstep.
- Un-quarantine the two tests; add false-positive guards (mg/L, w/w, ratios).
