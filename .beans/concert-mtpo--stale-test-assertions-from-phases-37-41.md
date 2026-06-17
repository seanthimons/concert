---
# concert-mtpo
title: Stale test assertions from Phases 37-41
status: todo
type: bug
priority: low
created_at: 2026-05-06T22:12:52Z
updated_at: 2026-05-08T14:01:03Z
parent: concert-dtco
---

test-cleaning-reference.R and test-reference-provenance.R have stale key-count assertions from Phases 37-41. Tests fail on count mismatches but the underlying functionality is correct. Was Phase 47 in v2.1 roadmap but never started. Fix: update assertions to match current reference list counts.
