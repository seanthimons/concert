---
# concert-wdr0
title: Install local CRAN check toolchain for release validation
status: todo
type: task
priority: high
tags:
    - cran
created_at: 2026-06-26T15:17:07Z
updated_at: 2026-06-26T15:17:07Z
parent: concert-a2ae
---

Local R CMD check --as-cran currently fails before package-only validation can be fully clean:

- ERROR/WARNING: pdflatex is not available, so the PDF manual cannot be built locally.
- NOTE: pandoc is not available, so README.md and NEWS.md cannot be checked locally.

CI now installs pandoc and TinyTeX, but local Windows release validation still needs the same toolchain or equivalent documented setup.

Acceptance criteria:
- Local release-validation setup includes pandoc and a LaTeX distribution with pdflatex.
- R CMD check --as-cran can build the PDF manual locally.
- README.md and NEWS.md checks run locally without the missing-pandoc NOTE.
- The setup is documented or scripted so future release checks are reproducible.
