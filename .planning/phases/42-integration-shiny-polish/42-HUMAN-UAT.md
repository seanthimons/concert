---
status: diagnosed
phase: 42-integration-shiny-polish
source: [42-03-SUMMARY.md]
started: 2026-04-28T00:00:00Z
updated: 2026-04-28T00:00:00Z
---

## Current Test

[UAT complete — 6 gaps diagnosed]

## Tests

### 1. Pre-flight modal opens promptly
expected: Modal appears quickly after clicking Run Pipeline
result: FAILED — noticeable delay on 100k+ row datasets, no loading indicator

### 2. Media editor unmatched rows have guidance
expected: User understands what action is needed for unmatched terms
result: FAILED — 7 unmatched terms shown yellow but no explanatory text

### 3. Post-pipeline completion feedback
expected: Clear indication of which steps ran and their outcomes
result: FAILED — no summary of what happened, especially unclear if harmonization ran

### 4. Media editor row click opens edit modal
expected: Clicking unmatched row opens edit modal
result: FAILED — row click only highlights, does not open modal (BUG)

### 5. Add Media Mapping button works
expected: Button opens blank edit modal for new mapping
result: FAILED — button click does nothing (BUG)

### 6. Unmatched units panel wording
expected: Consistent UX with new unified pipeline
result: FAILED — still references "run harmonization" button which no longer exists

## Summary

total: 6
passed: 0
issues: 6
pending: 0
skipped: 0
blocked: 0

## Gaps

### Gap 1: Pre-flight modal loading indicator
severity: medium
type: ux
description: Wrap pre-check collection in withProgress() or show spinner so user knows something is happening on large datasets

### Gap 2: Media editor unmatched guidance text
severity: medium
type: ux
description: Add explanatory text above the media DT table explaining what unmatched means and what actions are available

### Gap 3: Post-pipeline completion summary
severity: medium
type: ux
description: After pipeline runs, show a summary notification or panel listing which steps ran and their outcomes

### Gap 4: Media editor row click broken
severity: critical
type: bug
description: DT row click JS callback or observeEvent(input$open_media_edit_modal) not firing — edit modal never opens

### Gap 5: Add Media Mapping button broken
severity: critical
type: bug
description: observeEvent(input$add_media_mapping) not firing — button does nothing on click

### Gap 6: Unmatched units panel stale wording
severity: low
type: ux
description: Unmatched units accordion panel still tells user to "run harmonization" — update to reference "Run Pipeline" or remove the instruction
