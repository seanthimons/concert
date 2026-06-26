---
# concert-f9ha
title: Release ComptoxR to a mainstream repository before concert CRAN submission
status: todo
type: task
priority: high
tags:
    - cran
    - blocker
created_at: 2026-06-26T15:16:55Z
updated_at: 2026-06-26T15:17:40Z
parent: concert-a2ae
---

R CMD check --as-cran still reports:

- WARNING: Strong dependencies not in mainstream repositories: ComptoxR

This blocks a true CRAN submission while concert keeps ComptoxR in Imports. CRAN will not accept a strong dependency that is only installable via Remotes/GitHub.

Acceptance criteria:
- ComptoxR is accepted on CRAN or Bioconductor, or concert has an approved alternative that still satisfies CRAN dependency policy.
- DESCRIPTION keeps ComptoxR in Imports with a minimum version matching the accepted release.
- DESCRIPTION has no Remotes entry for ComptoxR.
- CI R-CMD-check can install all strong dependencies from mainstream repositories and pass.
