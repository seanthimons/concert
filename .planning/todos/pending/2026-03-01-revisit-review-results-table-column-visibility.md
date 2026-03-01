---
created: 2026-03-01T16:51:04.697Z
title: Revisit Review Results table column visibility
area: ui
files:
  - app.R
---

## Problem

After running the pipeline on messy real-world data, the current condensed table view (hiding dtxsid_*, preferredName_*, rank_*, source_tier_* columns) may not show enough information for users to understand results. User flagged this during UAT Test 8 — wants to change column visibility behavior after seeing how it works with messy data.

## Solution

TBD — user wants to revisit after working with real data. Options include:
- Show more columns by default
- Add a toggle to show/hide audit columns
- Configurable column selection
- Expandable row detail view
