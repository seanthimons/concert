# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Curation UI Iteration

**Shipped:** 2026-02-27
**Phases:** 2 | **Plans:** 2 | **Sessions:** ~3

### What Was Built
- Split single Curation tab into 3 top-level tabs (Tag Columns, Run Curation, Review Results)
- Gated tab visibility with cascade reset and re-upload confirmation modal
- Full-width layouts replacing nested card containers
- CSS pulse animation on newly unlocked tabs

### What Worked
- Small, focused phases (1 plan each) kept execution clean
- Auto-advance pipeline (discuss → plan → execute) completed both phases efficiently
- Keeping business logic untouched (R/curation.R, R/data_detection.R) reduced risk

### What Was Inefficient
- `nav_panel_hidden()` was used by the auto-advance executor but doesn't support title args — required a manual bugfix after Phase 2 completed
- REQUIREMENTS.md traceability table wasn't updated during Phase 1 execution — all 11 Phase 1 requirements showed as "Pending" at milestone completion
- Phase 2 executor used `nav_panel_hidden` despite research showing it works differently — the research-to-implementation gap caused the tab title bug

### Patterns Established
- `nav_panel()` + `session$onFlushed()` hide is the correct pattern for gated tabs that need titles in bslib
- Cascade reset pattern: tag changes silently hide all downstream tabs; re-upload shows confirmation modal
- `show_tab_with_pulse()` helper for animated tab reveals

### Key Lessons
1. Always verify bslib function signatures (title vs value as first arg) — `nav_panel_hidden()` and `nav_panel()` have different APIs
2. Update traceability tables during plan execution, not just at milestone completion
3. Auto-advance pipelines need post-execution verification to catch API misuse bugs

### Cost Observations
- Model mix: primarily sonnet for execution, opus for discussion
- Sessions: ~3 (project setup, Phase 1+2 auto-advance, bugfix + milestone completion)
- Notable: Both phases completed in a single auto-advance chain

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~3 | 2 | First milestone — established GSD workflow |

### Top Lessons (Verified Across Milestones)

1. (Pending — need multiple milestones to verify cross-cutting lessons)
