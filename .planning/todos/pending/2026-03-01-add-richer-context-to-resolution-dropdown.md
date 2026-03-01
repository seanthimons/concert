---
created: 2026-03-01T16:51:04.697Z
title: Add richer context to resolution dropdown
area: ui
files:
  - app.R
  - R/consensus.R
---

## Problem

The per-row resolution dropdown for disagree rows currently shows only the DTXSID value per source column. Users need more information to make informed resolution decisions — specifically preferredName, rank, and EPA QC level for each option. Without this context, users can't meaningfully choose between competing DTXSIDs.

## Solution

Enhance `get_resolution_options()` return value or the dropdown rendering to include:
- preferredName (chemical name associated with the DTXSID)
- rank (search result ranking)
- EPA QC level (quality confidence)

Options: enrich the `<select>` option text, or replace dropdown with a popover/modal showing a comparison table of all source column results for that row.
