---
# concert-06o2
title: Clarify and enforce Stop Words vs Block Patterns vs Strip Terms semantics
status: todo
type: feature
priority: normal
tags:
    - source:github
    - github:issue
    - complexity:medium
    - impact:medium
    - priority:medium
    - reference-lists
created_at: 2026-06-17T00:52:06Z
updated_at: 2026-06-17T00:52:06Z
---

GitHub: #32 https://github.com/seanthimons/concert/issues/32

Imported from GitHub issue #32 during todo sync on 2026-06-17.

---

## Summary

The reference-list UI currently exposes **Stop Words**, **Block Patterns**, and **Strip Terms**, but their operational distinction is easy to misunderstand. The current labels imply a policy distinction that the pipeline only partially enforces.

This issue captures recommended semantics and implementation changes so the cleaning/pre-curation behavior is defensible and less error-prone.

## Current behavior observed

Code paths inspected:

- `R/cleaning_reference.R`
  - `load_stop_words()`
  - `load_block_patterns()`
  - `load_strip_terms()`
  - `update_user_reference_list()`
- `R/mod_clean_data.R`
  - reference-list chip editor and active/inactive toggles
  - stop-word and block-pattern flagging calls
- `R/cleaning_pipeline.R`
  - `strip_reference_terms()`
  - `flag_reference_matches()`
- `R/curation.R`
  - `run_curation_pipeline()` skip behavior
- `tests/testthat/test-flag-matching.R`

### Stop words

Stop words are currently literal terms matched with word-boundary protection through `flag_reference_matches(..., "warning", "stop word")`.

Recommended meaning:

> Suspicious/generic/placeholder language that should warn the curator, but should not automatically remove or hard-block the row.

Examples:

- `ingredient`
- `blend`
- `mixture`
- `material`
- `surfactant`
- `additive`
- `treatment`
- `other`

These are broad semantic signals. They can indicate a bad analyte field, but they are not deterministic proof that the row should be excluded.

### Block patterns

Block patterns are currently raw regex patterns matched through `flag_reference_matches(..., "blocking", "block pattern")`.

Recommended meaning:

> Hard invalidity/redaction/not-searchable values, or exact known pseudo-analyte records that should not masquerade as chemical identities.

Examples:

- `^\\s*$`
- `^-+$`
- `^[.]+$`
- `^proprietary`
- `^confidential`
- `^trade\\s*secret`
- `^not\\s+disclosed`
- `^food starch$` if treating exact pseudo-analytes as blocked values

Important: broad legacy block-list terms should be anchored before activation. For example, use `^alcohol$`, not `alcohol`, otherwise valid names such as `benzyl alcohol` or `polyvinyl alcohol` may be flagged.

### Strip terms

Strip terms mutate the name field through `strip_reference_terms()`.

Recommended meaning:

> Removable text noise that can be deleted while preserving a useful chemical name.

Examples:

- `pure`
- `purified`
- `technical`
- `grade`
- `and its salts`
- `unspecified`

## Problems to fix

1. **"Block" is currently mostly a severity label.**
   - `BLOCK:` rows are colored red, but generic `BLOCK:` cleaning flags do not appear to be automatically excluded from curation.
   - `run_curation_pipeline()` currently skips isotope-pre-resolved rows, not all rows with `cleaning_flag` beginning `BLOCK:`.

2. **Block patterns are raw regex and easy to misuse.**
   - Activating legacy broad terms like `alcohol`, `pp`, or `rose` as unanchored block patterns risks substring false positives.

3. **Block priority can be weakened by first-flag-wins behavior.**
   - `flag_reference_matches()` does not overwrite existing `cleaning_flag` values.
   - Because functional categories and stop words are flagged before block patterns in `mod_clean_data.R`, an earlier warning may prevent a later block flag from being applied.

4. **The UI does not explain the distinction.**
   - Users can toggle terms without knowing whether they are activating a warning term, a hard regex hazard, or a name-mutating strip rule.

## Recommendations

### Policy semantics

- Use **stop words** for broad/generic ambiguous terms that should warn but remain reviewable.
- Use **block patterns** for redacted/non-values/hard invalid entries and exact pseudo-analyte values.
- Use **strip terms** only where deleting the text preserves the intended chemical name.

### Implementation recommendations

- Treat `BLOCK:` rows as true curation exclusions unless explicitly overridden.
- Add a pre-curation/curation option for users to include blocked rows deliberately if needed.
- Require or strongly encourage anchors for legacy exact block-list entries.
- Consider splitting block references into:
  - `block_patterns`: raw regex hazards
  - `block_exact`: exact-value pseudo-analytes
- Ensure block flags can supersede lower-priority warning flags, or run block pattern detection before warning-only lists.
- Preserve tests for stop-word word-boundary safety, e.g. `na` should not hit `Naphthalene`.

## Acceptance criteria

- [ ] Reference-list semantics are documented in code comments and/or app help text.
- [ ] Broad legacy terms are not active as unanchored block regex by default.
- [ ] `BLOCK:` behavior is either enforced as skip/exclusion or renamed so it does not imply exclusion.
- [ ] Block flags have clear priority over warning-only reference matches.
- [ ] Tests cover:
  - stop-word literal/word-boundary behavior
  - block-pattern regex behavior
  - anchored exact block terms
  - block-vs-warning precedence
  - curation skip/override behavior for blocked rows

## Sub-issues
- [ ] #34 Harden reference-list matching with explicit regex/literal pattern modes

- [ ] #33 Add reference-list tooltips explaining stop words, block patterns, strip terms, and functional categories

## Notes

This came out of reviewing why some reference-list chips are lined out/inactive and how users should decide between Stop Words, Block Patterns, and Strip Terms.
