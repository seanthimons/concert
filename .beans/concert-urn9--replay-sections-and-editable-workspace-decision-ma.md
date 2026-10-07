---
# concert-urn9
title: Replay Sections and Editable Workspace Decision Map
status: todo
type: epic
priority: normal
tags:
    - wayfinder:map
created_at: 2026-08-06T17:22:07Z
updated_at: 2026-08-06T20:36:41Z
---

## Destination

Produce a decision-complete implementation specification for portable replay snippets at sections that own reusable state, plus an optional editable-workspace view of the final headless replay.

## Notes

Use the grilling, domain-modeling, prototype, and ponytail skills while resolving this map.

Standing preferences:

- Normal replay output remains concise.
- Checkpoints emit paste-ready R object definitions in the exact format consumed by the final headless replay.
- Checkpoints exist only for sections that own independently reusable state.
- Only applied state is exportable; draft or empty checkpoints are disabled with a hint.
- Editable-workspace mode is enabled per Replay modal.
- Unconfigured workspace sections contain minimal commented schema examples.
- Edited snippets are re-injected by placing them in the replay script and running the normal exported CONCERT functions.
- Dataset Context remains independent of downstream chemical processing.
- Reuse existing literal/rendering helpers; do not introduce a replay DSL, parser, or speculative section framework.
- In Beans, `in-progress` is the claim state because the tracker has no assignee field.

## Decisions so far

- [Define the portable replay-section contract](./concert-40mh--define-the-portable-replay-section-contract.md) — Four applied-state configuration sections emit only owned canonical objects through renderer functions shared with the full replay.

## Not yet specified

- Exact dependency warnings and execution ordering after section invalidation rules are mapped.
- Final acceptance matrix after contracts, UX, and compatibility decisions settle.

## Out of scope

- Parsing R snippets back into Shiny state.
- Snippet-file upload or a second configuration format.
- Replay buttons on tabs without independently reusable state.
- Making site aliases rewrite curated data rows.
- Changing the default concise replay into an expanded workspace.
- Fixing [Resuming a session from an in-progress to-finish file should still output all corrections that were outputted against the RAW file.](./concert-496k--resuming-a-session-from-an-in-progress-to-finish-f.md)
- Implementing [Key replay baseline diff by a stable row id instead of row position](./concert-brxw--key-replay-baseline-diff-by-a-stable-row-id-instea.md).
