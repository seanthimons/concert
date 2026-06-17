---
# concert-xxph
title: Harden reference-list matching with explicit regex/literal pattern modes
status: todo
type: task
priority: high
tags:
    - source:github
    - github:issue
    - complexity:medium
    - impact:high
    - priority:high
    - reference-lists
created_at: 2026-06-17T00:52:07Z
updated_at: 2026-06-17T00:52:07Z
parent: concert-06o2
---

GitHub: #34 https://github.com/seanthimons/concert/issues/34

Imported from GitHub issue #34 during todo sync on 2026-06-17.

---

Parent: #32

## Summary

Harden the stop-word, block-pattern, and strip-term reference lists so pattern intent is explicit instead of inferred from naked strings. Where a list entry is meant to behave as a regex, store and validate it as a regex pattern. Where it is meant to be literal text, preserve literal matching and escape it deliberately.

## Problem

The current reference-list data model mostly stores a single `term` string plus `source` and `active`. That forces the cleaning code to infer matching semantics from list type or from the contents of the term itself.

Current behavior observed in `R/cleaning_pipeline.R`:

- `flag_reference_matches()` treats `block pattern` entries as regex patterns.
- `flag_reference_matches()` treats stop words / functional categories as escaped literal terms wrapped with word boundaries.
- `strip_reference_terms()` tries to guess whether a term is regex by scanning for metacharacters, otherwise escapes it and wraps it in word boundaries.

That is brittle. The big risk is that legacy/default entries that look like plain English strings can become unsafe unanchored regex/substrings in the block list. Example class of failure: a naked block term like `alcohol` can match inside a legitimate chemical name such as `benzyl alcohol` unless the intended pattern is made explicit.

## Proposed approach

Do not blindly convert every reference entry to regex. That would make the system more dangerous, not safer.

Instead, add explicit pattern semantics to the reference-list schema and matching helpers.

Recommended schema addition:

```r
term          # existing display/source term
pattern       # optional compiled/matching pattern; defaults from term when absent
match_mode    # one of: literal_exact, literal_word, regex
active        # existing
source        # existing
notes         # optional migration / review notes
```

Suggested defaults for backward compatibility:

- Stop words: default `match_mode = "literal_word"`
- Strip terms: default `match_mode = "literal_word"`, with selected entries migrated to `regex` where context-aware stripping is needed
- Block patterns: default should be reviewed carefully; either:
  - preserve legacy behavior as `regex` but flag risky unanchored naked strings for review, or
  - migrate obvious naked literals to `literal_exact` / anchored regex patterns

## Implementation notes

- Add a shared helper to compile/reference-match patterns from `term`, `pattern`, and `match_mode`.
- Replace the current `strip_reference_terms()` regex-metacharacter heuristic with explicit `match_mode` logic.
- Keep old RDS/user sidecar files readable by deriving default `match_mode` when the column is absent.
- Add validation for:
  - invalid regex syntax
  - empty/NA patterns
  - very short unanchored regexes
  - unanchored block regexes that are likely to over-match
  - regex patterns that match too broadly on a small fixture corpus
- Surface validation warnings in the reference-list UI before activation.
- Preserve exported config compatibility by including the new columns when present and tolerating their absence on import.

## Candidate files

- `R/cleaning_pipeline.R`
  - `strip_reference_terms()`
  - `flag_reference_matches()`
- `R/cleaning_reference.R`
  - reference-list loading / merging / default cache behavior
- `R/config_import.R`
  - imported reference-list schema compatibility
- `R/export_helpers.R`
  - exported Reference Lists sheet
- `R/mod_clean_data.R`
  - UI editing/activation and validation display
- `inst/extdata/reference_cache/`
  - bundled default RDS caches may need migration/rebuild

## Acceptance criteria

- [ ] Reference-list entries support explicit `match_mode` / pattern semantics without breaking existing cache files or user sidecars.
- [ ] Stop words, block patterns, and strip terms no longer rely on regex metacharacter guessing to determine behavior.
- [ ] Block patterns are audited for unsafe naked strings and migrated, anchored, or left inactive with review notes.
- [ ] Strip terms that need context-aware behavior are represented as explicit regex patterns, not heuristic naked strings.
- [ ] Invalid regex patterns are caught before the cleaning pipeline runs.
- [ ] Tests cover literal exact, literal word-boundary, regex, invalid regex, and over-broad block-pattern cases.
- [ ] Import/export preserves the new pattern semantics while remaining backward compatible with older exports.

## Relationship to existing work

This is a hardening implementation issue under #32. Issue #33 covers UI explanations/tooltips; this issue covers the underlying schema, matching, validation, and migration work.
