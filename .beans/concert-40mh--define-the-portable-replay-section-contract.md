---
# concert-40mh
title: Define the portable replay-section contract
status: completed
type: task
priority: normal
tags:
    - wayfinder:grilling
created_at: 2026-08-06T17:22:30Z
updated_at: 2026-08-06T20:36:13Z
parent: concert-urn9
---

## Question

Which existing state objects qualify as portable replay sections; what are their canonical object names, schemas, dependency closure, and applied-state requirements; and how must snippets and the final replay share rendering so they cannot drift?

## Resolution

A portable replay section is an applied, durable input object that `curate_headless()` can consume without Shiny session state.

The qualifying sections and canonical objects are:

- Column Setup: named-list `tag_map`; integer-or-`NULL` `header_row`.
- Cleaning References: `reference_list_snapshot`, whose named entries contain `default_hash` and an overrides tibble; logical `activate_all_references`.
- Dataset Context: normalized `site_alias_map` tibble. `site_manifest` remains derived and full-replay-only.
- Harmonization: `unit_map_snapshot` and `media_map_snapshot`, each a `default_hash` plus overrides tibble; `corrections`, a `pattern`/`replacement` tibble.

Paths, run settings, derived objects, and baseline-dependent `review_overrides` remain full-replay-only.

Each section emits only the definitions it owns. Dependencies are satisfied by composing sections in workspace order, not by copying prerequisite or derived definitions into multiple snippets.

Only applied state is exportable:

- Column Setup becomes exportable after Apply Tags.
- Cleaning Reference edits are authoritative immediately because that editor has no draft layer.
- Dataset Context becomes exportable after Apply.
- Harmonization becomes exportable only after a successful run with the current maps; absent or stale results disable export.
- Empty checkpoints are disabled.

Four small owner-specific render functions are the shared seam. Checkpoint controls call them directly, and `generate_concert_script()` composes the same rendered output. Do not add a registry, generic section selector, replay DSL, or parser.
