---
# concert-r6sz
title: Improve source-specific strip, stop, and block regex terms
status: todo
type: feature
priority: normal
tags:
    - reference-lists
    - data-cleaning
    - chemical-janitor
    - regex
created_at: 2026-07-01T14:40:27-04:00
updated_at: 2026-07-01T14:40:27-04:00
parent: concert-06o2
---

## Summary

Follow up on the chemical-janitor comparison item 5 by improving CONCERT's default and/or optional reference terms for source-specific name cleanup.

The old chemical-janitor pipeline included a few source-specific text rules that CONCERT does not currently seed by default:

- remove `Part A:` / `Part B:` style prefixes before the chemical name
- flag or strip `modif*` / modified-form text when it destroys chemical identity
- optionally flag known extraction artifacts such as `cyanidef`
- decide whether exact pseudo-analyte terms belong in stop words or anchored block patterns

CONCERT should not blindly port the old behavior. Some old rules were destructive, and CONCERT intentionally preserves percentage qualifiers. The feature should make the useful cases explicit, reviewable, and regex-safe.

## Scope

- Review the chemical-janitor `drop_text()` behavior against CONCERT's current `strip_terms`, `stop_words`, and `block_patterns`.
- Add narrowly-scoped default or optional reference rows for source-specific cleanup where the behavior is defensible.
- Prefer anchored exact block patterns for hard pseudo-analyte/extraction artifacts.
- Prefer stop words for broad ambiguous language that should warn but remain reviewable.
- Prefer strip terms only when deleting text preserves the intended chemical identity.
- Do not add broad unanchored block regexes such as `alcohol`, `rose`, or `pp`.
- Do not strip terminal percentages by default; percentage qualifiers are intentionally preserved.

## Candidate Terms

- Strip candidates:
  - `^part\\s+[a-z]:\\s*` for leading source-part labels
- Stop-word candidates:
  - `modified`
  - `modification`
  - `unknown modification`
- Block-pattern candidates:
  - `^cyanidef$`
  - exact known extraction artifacts, if validated against real source data

## Acceptance Criteria

- Tests cover the new terms in `strip_terms`, `stop_words`, or `block_patterns` according to their semantics.
- Tests include adversarial non-matches so broad patterns do not overmatch valid chemical names.
- `Part A: acetone` or equivalent source labels can be cleaned without damaging names containing internal `part`.
- `modified acetone` / `acetone modified` behavior is explicitly chosen as warn-only or strip, with test coverage.
- Terminal percentage qualifiers such as `technical grade ethanol (95%)` remain preserved.
- Any block-pattern additions are anchored or otherwise proven not to match inside valid chemical names.

## Notes

This came from the comparative audit against `kaphillips/chemical-janitor` dev branch. It is related to the completed stop/block/strip semantics work in `concert-06o2`, but is narrower: improve the actual seeded regex/reference terms based on source-specific cleanup gaps.
