---
# concert-hfnw
title: Detection mode switch fails silently with no data
status: completed
type: bug
priority: normal
created_at: 2026-04-23T20:27:11Z
updated_at: 2026-07-03T19:26:01Z
parent: concert-d6hb
---



Switching detection mode before upload silently returns. No feedback. GitHub #9



## Summary of Changes

`R/mod_file_upload.R`: the detection-mode `observeEvent` used a bare `req(data_store$raw)`,
which silently aborted when no file was uploaded. Replaced it with an explicit NULL guard
that calls `notify_user("Upload a file before changing header-detection settings.")`, and
added `ignoreInit = TRUE` so the observer does not toast on app startup.
