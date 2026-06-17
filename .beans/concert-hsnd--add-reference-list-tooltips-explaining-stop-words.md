---
# concert-hsnd
title: Add reference-list tooltips explaining stop words, block patterns, strip terms, and functional categories
status: completed
type: task
priority: normal
tags:
    - source:github
    - github:issue
    - complexity:low
    - impact:medium
    - priority:medium
    - area:ui
    - reference-lists
created_at: 2026-06-17T00:52:07Z
updated_at: 2026-06-17T16:52:33Z
parent: concert-06o2
---

GitHub: #33 https://github.com/seanthimons/concert/issues/33

Imported from GitHub issue #33 during todo sync on 2026-06-17.

---

Parent: #32

## Summary

Add small tooltip/help markers to the reference-list editor UI so users understand what each list is for before they activate/deactivate entries.

This should cover at least:

- Functional Categories
- Stop Words
- Block Patterns
- Strip Terms

## Motivation

The current page presents these as editable chip lists, but the operational distinction is not obvious:

- **Stop Words** warn on ambiguous/generic terms.
- **Block Patterns** are raw regex patterns intended for hard invalid/redacted/not-searchable values.
- **Strip Terms** mutate names by deleting removable text.
- **Functional Categories** warn on category/function language rather than specific chemical identities.

Without inline help, users can accidentally activate broad regex block terms and create false positives.

## Proposed UI behavior

Add an info/tooltip marker near each accordion title or immediately above each chip editor.

Suggested tooltip copy:

### Functional Categories

"Terms that indicate product function or use category rather than a specific chemical identity. Matches create warning flags for curator review."

### Stop Words

"Literal words/phrases that suggest the name is generic, ambiguous, placeholder-like, or not a specific analyte. These create warning flags; they do not rewrite the name."

### Block Patterns

"Regex patterns for hard invalid, redacted, or not-searchable values. These create BLOCK flags. Use anchors like ^alcohol$ for exact-value blocking; unanchored regex can match inside valid chemical names."

### Strip Terms

"Words or regex patterns to remove from names when deletion preserves the intended chemical identity, e.g. pure acetone -> acetone. These modify the name field."

## Acceptance criteria

- [x] Tooltip/help marker exists for Functional Categories.
- [x] Tooltip/help marker exists for Stop Words.
- [x] Tooltip/help marker exists for Block Patterns.
- [x] Tooltip/help marker exists for Strip Terms.
- [x] Block Patterns tooltip explicitly warns that entries are regex and should be anchored for exact matches.
- [x] Stop Words tooltip explains warning semantics and literal/word-boundary intent.
- [x] Strip Terms tooltip explains that the rule mutates/rewrites the name field.
- [x] UI tests or snapshot coverage are added if the project has a suitable Shiny UI testing path; otherwise add a lightweight helper/unit test for generated tooltip content.

## Suggested implementation area

- `R/mod_clean_data.R`
  - reference editor accordion around `output$reference_editors_section`
  - chip renderers around `output$chip_func_cats`, `output$chip_stop_words`, `output$chip_block_patterns`, `output$chip_strip_terms`
