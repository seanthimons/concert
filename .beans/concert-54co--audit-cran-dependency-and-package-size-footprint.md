---
# concert-54co
title: Audit CRAN dependency and package size footprint
status: todo
type: task
priority: normal
tags:
    - cran
created_at: 2026-06-26T15:17:14Z
updated_at: 2026-06-26T15:17:14Z
parent: concert-a2ae
---

R CMD check --as-cran reports a large dependency and installed-size footprint:

- INFO: Imports includes 33 non-default packages.
- Installed size is about 24.5 MB, with extdata about 19.8 MB.
- Tarball size is about 6.3 MB.

This is not the current CRAN submission blocker, but it is a likely reviewer question and a good hardening pass before submission.

Acceptance criteria:
- Review each strong dependency and move any optional-only packages to Suggests without changing exported behavior.
- Review extdata contents for files that can be compressed, slimmed, generated, or moved out of the package.
- Keep required runtime behavior intact and document why any large assets or strong dependencies remain.
- R CMD check --as-cran remains clean after any dependency or data changes.
