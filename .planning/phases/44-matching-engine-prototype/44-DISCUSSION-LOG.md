# Phase 44: Matching Engine + Prototype - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-05
**Phase:** 44-matching-engine-prototype
**Areas discussed:** Fuzzy matching strategy, Console logging approach, Match result structure, Prototype validation scope, Search performance

---

## Fuzzy Matching Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Jaro-Winkler | Best for name-like strings, weighs prefix matches heavily | ✓ |
| Optimal String Alignment | Edit distance with transpositions, better for typos/OCR | |
| You decide | Claude picks metric | |

**User's choice:** Jaro-Winkler
**Notes:** Standard for chemical name fuzzy matching.

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed threshold (e.g., 0.85) | Simple cutoff, accept if similarity ≥ threshold | ✓ |
| Best candidate, no auto-accept | Always return nearest candidate, never auto-resolve | |
| You decide | Claude picks threshold strategy | |

**User's choice:** Fixed threshold
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Parameter with default 0.85 | match_wqx(names, threshold = 0.85) — tunable | ✓ |
| Hardcoded 0.85 | Simpler, refactor later if needed | |

**User's choice:** Parameter with default 0.85
**Notes:** None

---

## Console Logging Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Add cli package | Styled console output, new dependency | ✓ |
| Use message() | Base R, zero dependencies, no colors | |
| You decide | Claude picks | |

**User's choice:** Add cli package
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Every name logged | Per-name lines for every match attempt | |
| Summary + verbose param | Default summary, verbose=TRUE for per-name | ✓ |
| You decide | Claude picks | |

**User's choice:** Summary + verbose param
**Notes:** Scales better to production datasets.

---

## Match Result Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Rich tibble row | input_name, wqx_name, match_tier, match_distance, alias_type | ✓ |
| Minimal: name + canonical only | Just input_name and wqx_canonical_name | |
| You decide | Claude designs return | |

**User's choice:** Rich tibble row
**Notes:** Phase 45 can use any column it needs.

| Option | Description | Selected |
|--------|-------------|----------|
| Character vector | match_wqx(names, dictionary) — clean interface | ✓ |
| Data frame + column name | match_wqx(df, name_col, dictionary) — more coupled | |
| You decide | Claude picks | |

**User's choice:** Character vector
**Notes:** Similar to how stringdist works.

---

## Prototype Validation Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Accuracy report | Tier breakdown, fuzzy matches with distances | ✓ |
| Smoke test only | Run, confirm no errors, print results | |
| You decide | Claude decides depth | |

**User's choice:** Accuracy report
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| scripts/ directory | scripts/prototype_wqx_matching.R | ✓ |
| tests/testthat/ | As a test file | |

**User's choice:** scripts/ directory
**Notes:** Consistent with existing scripts.

| Option | Description | Selected |
|--------|-------------|----------|
| 50-row sample only | detections_uat_sample_50.csv, fast and reproducible | ✓ |
| Both if available | 50-row default, optionally accept larger file | |
| You decide | Claude picks | |

**User's choice:** 50-row sample only
**Notes:** None

---

## Search Performance (User-initiated)

User noted: "Searches should be evaluated for time complexity."

| Option | Description | Selected |
|--------|-------------|----------|
| Hash lookups for tiers 1-2 | Pre-build named vectors/environments at load time, O(1) per name | ✓ |
| Benchmark in prototype script | Time each tier, optimize later based on numbers | |
| Both | Hash lookups AND benchmarking | |

**User's choice:** Hash lookups for tiers 1-2
**Notes:** Fuzzy tier stays O(n×k) but only runs on unresolved remainder.

---

## Claude's Discretion

- Internal hash structure choice
- NA/empty input name handling
- Case normalization strategy (tolower once upfront vs per-tier)
- Test file organization

## Deferred Ideas

- Fuzzy tier benchmarking at scale (10K+ names) — defer to Phase 45
- Threshold tuning on larger datasets — start with 0.85 default
