---
# concert-cthb
title: Manual header row validation missing
status: completed
type: bug
priority: normal
created_at: 2026-04-23T20:27:11Z
updated_at: 2026-07-03T19:26:01Z
parent: concert-d6hb
---



Manual header row input has hardcoded max 100 but files can exceed. GitHub #10



## Summary of Changes

`R/mod_file_upload.R`: removed the hardcoded `max = 100` from the manual header-row
`numericInput` (the real ceiling is per-file and unknown at UI build time). Added
server-side validation in the detection-mode observer that notifies the user when the
requested header row exceeds the uploaded file length (`nrow(data_store$raw)`).
