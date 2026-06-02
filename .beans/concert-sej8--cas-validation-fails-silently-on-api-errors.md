---
# concert-sej8
title: ""
status: completed
type: task
priority: normal
created_at: 2026-05-12T00:01:42Z
updated_at: 2026-05-29T22:26:04Z
---

﻿---
# concert-sej8
title: CAS validation fails silently on API errors
status: scrapped
type: bug
priority: critical
created_at: 2026-04-23T20:27:11Z
updated_at: 2026-05-11T17:37:32Z
parent: concert-dtco
---



as_cas()/is_cas() return NA on API errors without exceptions. Users think curation succeeded. GitHub #4

## Reasons for Scrapping\n\nCAS validation is a local checksum function, not an API call. The premise of this bug (silent API errors) is invalid. DTX resolution is the API-dependent path, and it has separate handling.
