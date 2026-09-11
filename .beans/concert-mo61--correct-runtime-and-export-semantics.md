---
# concert-mo61
title: Correct runtime and export semantics
status: completed
type: task
priority: normal
created_at: 2026-09-10T21:17:24Z
updated_at: 2026-09-10T21:29:22Z
parent: concert-psba
blocked_by:
    - concert-ux6k
---

Dependency: concert-ux6k. Acceptance: canonical media and preserved media_original in the unchanged 56-column ToxVal schema; conversion receives category only; repeat runs and media-only data retain rows and originals. Verification: test-media-published.R passed 35 assertions including runtime rerun equality and aqueous/solid conversion with no guessing for unavailable routes.
