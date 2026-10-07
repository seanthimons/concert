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
