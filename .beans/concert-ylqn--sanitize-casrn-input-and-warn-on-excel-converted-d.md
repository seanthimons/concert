---
# concert-ylqn
title: Sanitize CASRN input and warn on Excel-converted date strings
status: todo
type: bug
priority: high
tags:
    - casrn
    - preflight
    - data-cleaning
    - github:issue
created_at: 2026-05-21T14:32:56Z
updated_at: 2026-06-17T01:14:58Z
parent: concert-d6hb
---


## Problem

CASRN-like identifiers can be silently corrupted when users open/edit source files in Excel or export through spreadsheet workflows. Hyphenated CASRNs may arrive as date-like strings, Excel date serials, or formatted dates instead of canonical CASRN text.

That is dangerous because downstream matching may treat corrupted values as ordinary unresolved identifiers instead of warning the user that the input itself was damaged.

## Scope

Add a CASRN sanitization/cleaning step that is used before CASRN validation and before automated resolution. It should normalize safe, recoverable formatting issues and flag likely Excel-converted values during preflight.

## Requirements

- Create an exported or internal helper function for CASRN cleaning, e.g. `clean_casrn()` / `sanitize_casrn()`.
- Preserve valid canonical CASRNs: `<digits>-<2 digits>-<check digit>`.
- Normalize recoverable text problems:
  - leading/trailing whitespace
  - repeated/internal spaces around hyphens
  - unicode/en dash variants if present
  - common placeholder/empty values to `NA_character_`
- Detect likely spreadsheet/date corruption patterns and return structured warnings/flags rather than silently coercing:
  - date-like strings such as `MM/DD/YYYY`, `YYYY-MM-DD`, or locale-formatted dates
  - numeric Excel date serials in CASRN columns
  - values that look like dates after import class coercion
- Integrate the warning into preflight so users see a clear message before curation/resolution proceeds.
- Do not invent CASRNs from ambiguous dates. If original CASRN text cannot be reconstructed defensibly, flag it and require source-file correction.

## Acceptance criteria

- Unit tests cover valid CASRNs, whitespace/hyphen normalization, blank placeholders, invalid checksum CASRNs, and likely Excel-date converted strings.
- Preflight output includes row/column/value context for flagged Excel-converted CASRN candidates.
- Existing CASRN validation behavior still works on canonical cleaned values.
- Documentation or inline help explains that Excel-converted CASRNs are input corruption and may require re-exporting the source file with CASRN columns forced to text.

## Implementation notes

This should sit upstream of matching/resolution so bad CASRN input fails loudly before producing false negatives or misleading unresolved rows.



## GitHub

- GitHub #35: https://github.com/seanthimons/concert/issues/35
