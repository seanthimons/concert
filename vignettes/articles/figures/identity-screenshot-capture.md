# Source identity screenshot capture

Captured 2026-10-07 from CONCERT 0.5.3 at `http://127.0.0.1:63322/`, using the
T3 collaborative browser against the actual full application. The entry point
was `inst/examples/identity-review-app.R`; external services were mocked only
inside that R process. Registry authority labels describe the production service;
the displayed responses and chemical identities in these captures are synthetic.
No pilot assignments were loaded or modified.

The source session came from a three-row CSV upload with Chemical Name and
Source DTXSID tags. Inventory A has a current registered-mixture decision;
inventory B has the same chemical name but no correspondence decision. The third
source ID has a mocked missing registry record. The session survived re-curation
and workbook resume before these captures. Draft fields were entered for the
documentation and closed without saving an additional decision.

Viewport: 1400 × 1000 CSS pixels. Saved screenshots are 1280 × 914 pixels after
the preview tool's image scaling. PNGs were copied unchanged from saved browser
snapshots. No UI controls were hidden or rearranged for these screenshots.
The review table's normal Columns shown control selected source context and
identity decision columns for readability.

| File | Content |
| --- | --- |
| identity-01-review.png | Lookup summary and review controls; the separate table capture shows all source rows. |
| identity-02-override-evidence.png | Override title, source evidence, saved status and row flags; modal scroll 0. |
| identity-03-override-scope.png | Ordinary overrides, source correspondence introduction and selector; modal scroll 850. |
| identity-04-override-decision.png | Inspected evidence, action, scope, conflict, ID and correspondence checkbox; modal scroll 1700. |
| identity-05-override-result.png | Reason, reference, Save, current result and Close; modal scrolled to its end, approximately 2663. |
| identity-06-source-table.png | All three source rows and their individual decisions. |
| identity-07-tags.png | Applied Name/Source DTXSID roles and metadata-ignore configuration. |
| identity-08-resume.png | Entire workbook-import confirmation dialog and all three actions. |
| identity-09-preflight-top.png | Current pre-flight title, cleaning choices and harmonization choices; modal scroll 0. |
| identity-10-preflight-bottom.png | Remaining harmonization choices, all search settings and the run/cancel footer; modal scroll approximately 694. |

The long Override dialog had approximately 3663 pixels of scroll content and a
1000-pixel visible region. The four scroll intervals overlap and cover its entire
height. The bottom capture was checked against the modal footer bounds: its
bottom was at approximately 971 within the 1000-pixel viewport. Reason/reference
examples fit their visible textareas. Snapshotting after a close animation was
discarded and repeated after the modal had disappeared.

The current pre-flight dialog used the CSV fixture with Name, CASRN and Source
DTXSID tagged. It had approximately 1694 pixels of scroll content; captures at
0 and the maximum scroll position (approximately 694) cover the entire dialog
with overlap. Its footer bottom was approximately 971 within the viewport.
The dialog was cancelled without executing cleaning. The earlier source-review
session was restored from the workbook saved before this temporary upload.

To refresh: run the mock full-app entry point, upload the synthetic example,
follow `inst/examples/identity-review-app-README.md`, and use browser snapshots
after each view settles. Inspect each PNG before replacing it. For a long dialog,
measure its scroll height, take overlapping captures from the top to the maximum
scroll position, and verify the bottom actions are visible. Preserve normal app
layout and caption synthetic evidence explicitly. The older SSWQS images 01–09
belong to the earlier dataset walkthrough and are labelled accordingly there.
