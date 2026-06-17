---
# concert-62nv
title: Fallback resolution path when DTXSID/WQX lookup yields no match
status: todo
type: feature
priority: normal
tags:
    - github:issue
created_at: 2026-05-11T21:19:20Z
updated_at: 2026-06-17T01:14:59Z
parent: concert-vwkd
---

When curation finds no Resolution for DTXSID or WQX, there is currently no recovery path. We need a way to:

1. Offer a secondary query against WQX or DTX ID directly
2. Or allow the user to mark the record as 'bad' / unresolvable

**Canonical example:** TPH-ORO with no CASRN â€” it has no CAS number to anchor a CompTox lookup, and the name alone doesn't resolve. The pipeline currently leaves these in limbo with no actionable next step.

**Acceptance criteria:**
- [ ] Detect rows where primary resolution (DTXSID + WQX) returned no match
- [ ] Offer fallback query options (direct WQX search, direct DTXSID search)
- [ ] Allow marking unresolvable records as 'bad' with a reason
- [ ] Works in both Shiny UI and headless mode



## GitHub

- GitHub #39: https://github.com/seanthimons/concert/issues/39
