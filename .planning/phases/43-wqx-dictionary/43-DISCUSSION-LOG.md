# Phase 43: WQX Dictionary - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-05
**Phase:** 43-WQX Dictionary
**Areas discussed:** RDS structure, Auto-download behavior, Source URL & freshness, Data cleaning at build time

---

## RDS Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single tibble with type column | One tibble with `name`, `canonical_name`, `type` (canonical/synonym/standardize/retired). Simple to query with dplyr::filter(). | ✓ |
| Named list of two tibbles | `list(characteristics = <tibble>, aliases = <tibble>)`. Mirrors CSV structure. | |
| You decide | Claude picks simplest for matching engine. | |

**User's choice:** Single tibble with type column
**Notes:** None

---

## Auto-Download Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Lazy (on first WQX function call) | `load_or_fetch_reference()` pattern. Consistent with existing loaders. | ✓ |
| Eager (on package load) | `.onLoad()` checks and downloads if missing. | |
| Lazy with offline fallback | Same as lazy but returns NULL if download fails. | |

**User's choice:** Follow existing codebase pattern (lazy on first call)
**Notes:** User directed to research existing code — confirmed all other reference lists use the lazy `load_or_fetch_reference()` pattern, not `.onLoad()`.

---

## Source URL & Freshness

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded EPA URL | Embed URLs directly. `refresh_wqx_cache()` re-downloads silently. | ✓ |
| Configurable URL with silent refresh | URL stored in package option or argument. | |
| You decide | Claude picks simplest. | |

**User's choice:** Hardcoded EPA URL
**Notes:** User provided specific URLs:
- `https://cdx.epa.gov/wqx/download/DomainValues/Characteristic_CSV.zip`
- `https://cdx.epa.gov/wqx/download/DomainValues/CharacteristicAlias_CSV.zip`

---

## Data Cleaning at Build Time

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — lookup-relevant only | Keep only name, cas_number, type, canonical_name. Drop everything else. | |
| Moderate — keep useful metadata | Also retain cas_number, group_name, description. Bigger RDS but more context. | ✓ |
| You decide | Claude picks based on matching engine needs. | |

**User's choice:** Moderate — keep metadata that might be useful later
**Notes:** None

---

## Claude's Discretion

- Column naming details beyond the specified set
- Zip extraction temp directory handling
- Download method (utils::download.file vs curl)
- Error messaging when download fails

## Deferred Ideas

None — discussion stayed within phase scope
