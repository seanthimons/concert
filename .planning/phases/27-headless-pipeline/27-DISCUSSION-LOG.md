# Phase 27: Headless Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 27-headless-pipeline
**Areas discussed:** Verbosity, Reference list handling, Frontmatter detection, Error handling

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Verbosity / progress reporting | How verbose should headless runs be? Silent, message()-based progress, or optional callback? | ✓ |
| Reference list handling | Should headless users be able to pass custom reference lists, or always use package defaults? | ✓ |
| Frontmatter detection | Automatic detection vs. optional manual header_row override in the function signature? | ✓ |
| Error handling strategy | Fail fast on API errors vs. partial results? What if no CompTox API key is set? | ✓ |

**User's choice:** All areas selected

---

## Verbosity / Progress Reporting

| Option | Description | Selected |
|--------|-------------|----------|
| Keep messages | Standard R behavior, suppressMessages() if needed | |
| Add verbose flag | Explicit control via `verbose = TRUE/FALSE` parameter | ✓ |
| Something else | Custom approach | |

**User's choice:** Add verbose flag
**Notes:** User prefers explicit parameter control over relying on suppressMessages()

---

## Reference List Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Package defaults only | Simplest, always use bundled reference lists | |
| Optional override | Add `reference_lists = NULL` parameter for custom lists | ✓ |
| Cache directory | Add `cache_dir = NULL` parameter pointing to RDS files | |

**User's choice:** Optional override parameter
**Notes:** Allows power users to customize while keeping simple default behavior

---

## Frontmatter Detection

| Option | Description | Selected |
|--------|-------------|----------|
| Automatic only | Always run ensemble detection | |
| Optional header_row | Add `header_row = NULL` parameter for manual override | ✓ |
| Something else | Custom approach | |

**User's choice:** Optional header_row parameter
**Notes:** Matches Shiny app capability — same feature, different interface

---

## Error Handling Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Fail fast | Stop on first error | ✓ |
| Partial results | Continue with warnings, return what succeeded | |
| Pre-flight + partial | Validate API key upfront, then partial results for lookup failures | |

**User's choice:** Fail fast
**Notes:** Simpler mental model — fix issue and re-run rather than dealing with partial state

---

## Claude's Discretion

- Internal helper functions vs. inline implementation
- Exact error message wording
- Whether to add @examples in roxygen docs

## Deferred Ideas

None — discussion stayed within phase scope
