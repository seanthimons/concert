# Phase 2: Gated Navigation - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement conditional tab visibility based on workflow state. Tabs appear only when prerequisites are met: Upload → Tag Columns → Run Curation → Review Results. Users follow the correct sequence because unavailable steps are hidden. Back-navigation to completed steps works. No flash of hidden tabs on startup.

</domain>

<decisions>
## Implementation Decisions

### State reset behavior
- Re-uploading a new file triggers a **confirmation modal** warning that all progress will be lost; if dismissed, the re-upload is cancelled
- If confirmed, full reset: clear tags, curation results, and hide all downstream tabs (clean slate)
- Changing tags **silently hides all downstream tabs** (Run Curation + Review Results) — no modal needed since user is actively editing
- Strict cascade: any tag change invalidates everything downstream; user must re-apply tags to unlock Run Curation, then re-run curation to unlock Review Results

### Tab unlock signals
- Tabs appear **silently** when prerequisites are met — no toast notifications
- Newly unlocked tabs get a **brief highlight/pulse** (~1 second) to draw the user's eye
- **Exception:** After curation completes, **auto-switch to Review Results** tab (user was actively waiting)
- On app startup, **only the Upload tab is visible** — all other tabs (including Data Preview, Detection Info, Raw Data) appear as the user progresses

### Workflow guidance
- **No inline hints** about next steps — the tab appearing is guidance enough
- Locked tabs are **completely hidden** (not greyed-out/disabled) — nav only shows available tabs
- If user somehow lands on a locked tab (deep link/bookmark), show a **locked message** explaining what's needed (e.g., "Upload data first to access this step")
- Upload tab stays focused on uploading only — no workflow state summary

### Claude's Discretion
- Exact highlight/pulse animation style and duration (should fit Flatly theme)
- Locked-tab message wording and styling
- Technical approach for hiding/showing tabs (shinyjs, nav_panel_hidden, etc.)
- How to handle edge cases with Shiny's tab navigation internals

</decisions>

<specifics>
## Specific Ideas

- Confirmation modal on re-upload should clearly state what will be lost ("Your column tags and curation results will be cleared")
- Auto-switch to Review Results should feel like a natural progression, not jarring
- The brief highlight on new tabs should be subtle — a gentle pulse, not a flashing alert

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-gated-navigation*
*Context gathered: 2026-02-26*
