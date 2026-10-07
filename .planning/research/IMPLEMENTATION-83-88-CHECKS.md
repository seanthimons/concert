# Implementation verification

2026-10-07, branch fix/82-wqx-identifier-review. R 4.6.1 runs the R 4.5.1
lockfile dependency versions. `renv::restore()` attempted all 156 locked packages;
optional documentation/graphics packages failed for missing system headers
(fontconfig/freetype and libgit2 among them). A focused restore installed 141
runtime/development packages into the user library. pkgload, testthat, roxygen2,
ComptoxR and Shiny load successfully with `Rscript --vanilla`. Lockfile unchanged.
Use pkgload rather than devtools until optional dependencies are installed.

Focused baseline: consensus, curate-iterate, export-review, pubchem-fallback
passed (one expected pinned-row warning). Additive accepted policy: identity-review,
export-review, toxval-mapper, toxval-export-parity passed. No pilot identities
validated or assignments rewritten. No service requests or DSSTox download.

Compatibility decision: retain map_to_toxval_schema() lookup default; accepted
mode is explicit and preserves measurement rows with NA IDs when blocked.
Curated Data retains provisional consensus, adds derived policy fields; Accepted
Identities is an additive sheet/view. Queue completion is not identity acceptance.

The full package suite was attempted. Additive sheet-count fixtures were updated,
then export/import including the new safe sheet passed. Five unrelated failures
were reproduced on detached original research commit c689178: test-cas-pipeline
uses unavailable `expect_na()`, and media-artifacts/media-persistence reject the
pinned table-manifest.json hash. These are existing baseline limitations and are
not changed by this identity work. Several existing optional tests skip for
missing credentials, or known large-sheet memory limits. Full-suite green cannot
be claimed until those independent fixtures are repaired.

#88 focused package tests passed (154 assertions). #83 focused consensus,
iteration, export-review and review-resolution passed (351 expectations),
including actual generated replay and workbook reimport under deterministic
service/pipeline mocks. #83 and #88 made no Shiny changes.
