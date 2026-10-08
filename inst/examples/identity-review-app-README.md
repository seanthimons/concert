# Test source correspondence in the full application

The illustrated user guide is
[Reviewing a source chemical identity](../../vignettes/articles/source-identity-review.Rmd).
It includes every part of the long Override and pre-flight dialogs.

From the package root, run:

```r
source("inst/examples/identity-review-app.R")
run_identity_review_app()
```

This launches the actual CONCERT application on port 63322. Only external
registry/search/enrichment services are mocked, within this R process. Uploaded
files still use the real detection, tagging, cleaning, curation, review, export
and session-restore modules. The fixture IDs and names are synthetic; acceptance
here tests wiring and does not validate a chemical assignment.

1. Upload `inst/examples/identity-review-upload.csv` using the sidebar.
2. Tag `name` as Chemical Name and `source_dtxsid` as Source DTXSID. Leave
   `source_file` untagged to retain it as source context.
3. For the cleaning workflow, also tag `cas` as CASRN, open Clean Data, and run
   the checked pipeline steps. The deliberately malformed fixture CAS values
   are retained in Raw Data and their cleaning changes appear in the audit.
   Alternatively, leave `cas` untagged and proceed directly to Run Curation.
4. Start Curation and open Review Results. The lookup candidate DTXSID789
   conflicts with the validated source candidate DTXSID123; both remain evidence.
5. Open Override for Mock registered mixture. In Source identity correspondence,
   explicitly choose inventory A, select Record correspondence and Registered
   mixture, choose No remaining conflict, enter DTXSID123, check the correspondence
   box, and provide a reason and supporting reference. Save the source decision.
6. Only inventory A becomes accepted. Inventory B remains provisional. The
   negative fixture DTXSID456 cannot be promoted because its mocked registry
   membership lookup finds no record.
7. Re-run curation; the unchanged decision stays scoped to inventory A. Download
   Excel, upload the exported workbook, and choose Resume Session. Check the
   Accepted Identities sheet and source evidence/decision panel.
8. Use Code to download the replay script. Run it against the original uploaded
   CSV, with the same process-local mocked services when testing synthetic IDs:

```r
devtools::load_all()
source("inst/examples/identity-review-app.R")
with_identity_review_fixture_services(source("path/to/downloaded_replay.R"))
```

The script uses the original input filename relative to the working directory.
Its output path is editable. Applied cleaning choices and immutable review
history travel with the workbook; skipped cleaning remains skipped on replay.
Changed source/lookup evidence or unavailable validation makes prior acceptance
stale and requires another explicit review. Existing flags remain independent.

For production services, launch `concert::run_app()` normally. The mock wrapper
is an explicit development entry point and is not enabled by the normal app.

## WQX continuation fixture

To exercise WQX candidates in the same full application:

```r
source("inst/examples/wqx-review-app.R")
run_wqx_review_app()
```

Upload `inst/examples/wqx-review-upload.csv`, tag `name` as Chemical Name, leave
`source_file` untagged, and proceed directly to Run Curation. The three synthetic
rows exercise fuzzy Arsenick→Arsenic with a dictionary-CAS candidate, DO→Dissolved
oxygen as reviewed name-only vocabulary, and TETRACYCLINES→Tetracycline as a class
whose singular candidate still needs source-scope review. Fixture IDs
DTXSID999000001 and DTXSID999000003 are synthetic service outputs.

Open Override to inspect the WQX input, canonical name, tier, dictionary CAS and
provisional candidates. Explicitly accepting inventory A requires a Substance
scope, No remaining conflict, correspondence confirmation, reason and reference.
For inventory B, VERIFIED can retain reviewed name-only evidence without an ID.
Leave inventory C unresolved or explicitly retain its class scope. Re-run to
check that decisions and evidence persist. This fixture validates application
connections; it does not validate any chemical identity. The same process-local
services can wrap exported replay:

```r
with_wqx_review_fixture_services(source("path/to/downloaded_replay.R"))
```
