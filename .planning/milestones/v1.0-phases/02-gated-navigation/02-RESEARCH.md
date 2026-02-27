# Phase 2: Gated Navigation - Research

**Researched:** 2026-02-26
**Domain:** R Shiny conditional tab visibility with bslib
**Confidence:** HIGH

## Summary

Phase 2 requires hiding tabs until workflow prerequisites are met (Upload -> Tag Columns -> Run Curation -> Review Results). The bslib package provides `nav_panel_hidden()` for initially hidden tabs and `nav_show()`/`nav_hide()` for dynamic visibility control. Combined with Shiny's `reactiveValues` state tracking and `observeEvent` for state transitions, this is a well-supported pattern.

The current app uses `navset_underline()` with `nav_panel()` for all 6 tabs. The migration path is: change downstream tabs (Tag Columns, Run Curation, Review Results) to `nav_panel_hidden()`, add reactive observers that call `nav_show()`/`nav_hide()` based on workflow state, and add a confirmation modal for re-upload scenarios.

**Primary recommendation:** Use bslib's native `nav_panel_hidden()` + `nav_show()`/`nav_hide()` for tab gating. Track workflow state via existing `reactiveValues` data store. Use `shinyjs::addClass()`/`shinyjs::removeClass()` with CSS keyframe animation for the tab pulse effect.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Re-uploading a new file triggers a **confirmation modal** warning that all progress will be lost; if dismissed, the re-upload is cancelled
- If confirmed, full reset: clear tags, curation results, and hide all downstream tabs (clean slate)
- Changing tags **silently hides all downstream tabs** (Run Curation + Review Results) — no modal needed since user is actively editing
- Strict cascade: any tag change invalidates everything downstream; user must re-apply tags to unlock Run Curation, then re-run curation to unlock Review Results
- Tabs appear **silently** when prerequisites are met — no toast notifications
- Newly unlocked tabs get a **brief highlight/pulse** (~1 second) to draw the user's eye
- **Exception:** After curation completes, **auto-switch to Review Results** tab (user was actively waiting)
- On app startup, **only the Upload tab is visible** — all other tabs (including Data Preview, Detection Info, Raw Data) appear as the user progresses
- **No inline hints** about next steps — the tab appearing is guidance enough
- Locked tabs are **completely hidden** (not greyed-out/disabled) — nav only shows available tabs
- If user somehow lands on a locked tab (deep link/bookmark), show a **locked message** explaining what's needed
- Upload tab stays focused on uploading only — no workflow state summary

### Claude's Discretion
- Exact highlight/pulse animation style and duration (should fit Flatly theme)
- Locked-tab message wording and styling
- Technical approach for hiding/showing tabs (shinyjs, nav_panel_hidden, etc.)
- How to handle edge cases with Shiny's tab navigation internals

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TAB-02 | Tag Columns tab hidden until data uploaded and detected | `nav_panel_hidden()` + `nav_show()` triggered by `data_store$clean` becoming non-NULL |
| TAB-03 | Run Curation tab hidden until at least one column tagged | `nav_panel_hidden()` + `nav_show()` triggered by `data_store$column_tags` having length > 0 |
| TAB-04 | Review Results tab hidden until curation completes | `nav_panel_hidden()` + `nav_show()` triggered by `data_store$curation_status == "completed"` |
| UX-01 | Tabs start hidden using nav_panel_hidden() (no flash on startup) | bslib `nav_panel_hidden()` renders tabs with `display:none` server-side — no FOUC |
| UX-02 | Back navigation works — completed tabs remain accessible | `nav_show()` is additive — once shown, tabs stay visible until explicitly hidden via `nav_hide()` |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bslib | 0.9+ | `nav_panel_hidden()`, `nav_show()`, `nav_hide()`, `nav_select()` | Native tab visibility control, already in use |
| shiny | 1.9+ | `showModal()`, `modalDialog()`, `observeEvent()`, `reactiveValues()` | Core framework, already in use |
| shinyjs | 2.1+ | `addClass()`, `removeClass()`, `runjs()` for pulse animation | Already loaded, provides CSS class manipulation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none additional) | - | - | All needed libraries already in project |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `nav_panel_hidden()` | `shinyjs::show()`/`hide()` on tab elements | shinyjs targets DOM elements directly, but bslib's nav functions are purpose-built for tab control and handle internal bookkeeping (active tab state, accessibility attributes) |
| `nav_panel_hidden()` | `conditionalPanel` wrapping tabs | conditionalPanel works client-side via JS conditions, but doesn't integrate with bslib's nav state management |
| CSS keyframe pulse | shinyjs `anim` parameter | shinyjs animations are show/hide transitions, not attention-drawing pulses on already-visible elements |

## Architecture Patterns

### Current Tab Structure (from app.R)
```
navset_underline(id = "main_tabs")
├── nav_panel("Data Preview", value = "data_preview")
├── nav_panel("Detection Info", value = "detection_info")
├── nav_panel("Raw Data", value = "raw_data")
├── nav_panel("Tag Columns", value = "tag_columns")
├── nav_panel("Run Curation", value = "run_curation_tab")
└── nav_panel("Review Results", value = "review_results")
```

### Target Tab Structure
```
navset_underline(id = "main_tabs")
├── nav_panel("Data Preview", value = "data_preview")           # Always visible (upload landing)
├── nav_panel_hidden("Detection Info", value = "detection_info") # Show after upload
├── nav_panel_hidden("Raw Data", value = "raw_data")            # Show after upload
├── nav_panel_hidden("Tag Columns", value = "tag_columns")      # Show after upload+detection
├── nav_panel_hidden("Run Curation", value = "run_curation_tab")# Show after tags applied
└── nav_panel_hidden("Review Results", value = "review_results")# Show after curation
```

### Pattern 1: nav_panel_hidden + nav_show/nav_hide
**What:** Declare tabs as hidden in UI, show/hide programmatically in server
**When to use:** When tabs should be invisible until a condition is met
**Example:**
```r
# UI
navset_underline(
  id = "main_tabs",
  nav_panel("Upload", value = "upload", "Upload content"),
  nav_panel_hidden(value = "tag_columns", "Tag content")
)

# Server
observeEvent(data_store$clean, {
  if (!is.null(data_store$clean)) {
    nav_show("main_tabs", target = "tag_columns")
  }
})
```
Source: Context7 /rstudio/bslib — Programmatic Tab Control

### Pattern 2: Confirmation Modal for Re-Upload
**What:** Intercept file upload, show modal, only process if confirmed
**When to use:** When re-uploading would destroy downstream state
**Example:**
```r
observeEvent(input$file_upload, {
  if (!is.null(data_store$clean)) {
    # Data already exists — confirm before replacing
    showModal(modalDialog(
      title = "Replace Current Data?",
      "Your column tags and curation results will be cleared.",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_reupload", "Replace Data", class = "btn-danger")
      )
    ))
  } else {
    # First upload — process directly
    process_upload()
  }
})
```
Source: Context7 /rstudio/shiny — Modal Dialog patterns

### Pattern 3: Cascade Reset on State Change
**What:** When upstream state changes, invalidate all downstream state and hide downstream tabs
**When to use:** Strict workflow gating where any change cascades
**Example:**
```r
# When tags change, hide downstream tabs
observeEvent(data_store$column_tags, {
  nav_hide("main_tabs", target = "run_curation_tab")
  nav_hide("main_tabs", target = "review_results")
  data_store$curation_results <- NULL
  data_store$curation_status <- NULL
}, ignoreNULL = TRUE, ignoreInit = TRUE)
```

### Pattern 4: CSS Pulse Animation for New Tabs
**What:** Briefly highlight newly visible tabs with a CSS animation
**When to use:** Drawing user attention to newly unlocked tabs
**Example:**
```r
# CSS (in UI head)
tags$style("
  @keyframes tab-pulse {
    0% { background-color: transparent; }
    50% { background-color: rgba(0, 123, 255, 0.15); }
    100% { background-color: transparent; }
  }
  .tab-pulse .nav-link {
    animation: tab-pulse 0.5s ease-in-out 2;
  }
")

# Server — after nav_show, add pulse class, remove after animation
observeEvent(data_store$clean, {
  nav_show("main_tabs", target = "tag_columns")
  # Add pulse via shinyjs
  shinyjs::runjs("
    var tab = document.querySelector('[data-value=\"tag_columns\"]');
    if (tab) {
      tab.closest('li').classList.add('tab-pulse');
      setTimeout(function() {
        tab.closest('li').classList.remove('tab-pulse');
      }, 1200);
    }
  ")
})
```
Source: shinyjs runjs documentation (Context7 /daattali/shinyjs)

### Anti-Patterns to Avoid
- **Using `conditionalPanel` for tab gating:** Works for content within tabs but doesn't hide the tab header itself from the navigation bar
- **Using `shinyjs::hide()` on tab panels directly:** May break bslib's internal tab state tracking; use `nav_hide()` instead
- **Calling `nav_show` without checking current state:** Could trigger unnecessary re-renders; guard with state checks
- **Modifying the DOM `style` attribute directly for hiding:** Conflicts with bslib's own visibility management

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tab visibility | Custom JS to toggle tab display | bslib `nav_show()`/`nav_hide()` | Handles accessibility attributes, active-tab state, ARIA roles |
| Confirmation dialog | Custom overlay div | Shiny `showModal()`/`modalDialog()` | Handles backdrop, keyboard escape, focus management, mobile |
| State cascade | Manual if/else chains resetting each piece | Centralized `observe()` watchers on upstream state | Less error-prone, automatically handles new downstream additions |
| Tab pulse effect | jQuery UI effects or external animation library | CSS `@keyframes` + `shinyjs::runjs()` | Zero dependencies, ~5 lines of CSS, works with Flatly theme |

**Key insight:** bslib's tab functions manage internal state (which tab is active, ARIA attributes, keyboard navigation). Bypassing them with raw DOM manipulation breaks accessibility and may cause inconsistent state.

## Common Pitfalls

### Pitfall 1: Flash of Hidden Tabs on Startup
**What goes wrong:** Tabs briefly appear before server hides them
**Why it happens:** Using `nav_panel()` + server-side `nav_hide()` means tabs render visible, then get hidden after server round-trip
**How to avoid:** Use `nav_panel_hidden()` in UI definition — tabs are born hidden, no round-trip needed
**Warning signs:** Brief flicker of all tabs on page load

### Pitfall 2: File Upload Observer Fires Before Modal Response
**What goes wrong:** File data is processed immediately on upload, before user confirms in modal
**Why it happens:** `observeEvent(input$file_upload, ...)` fires as soon as file is selected
**How to avoid:** Store the uploaded file info temporarily, show modal, only process on confirm. The file data persists in `input$file_upload` until replaced.
**Warning signs:** Data changes before modal appears or user sees both old and new data

### Pitfall 3: nav_hide on Currently Active Tab
**What goes wrong:** Hiding the currently active tab leaves the user on a blank panel
**Why it happens:** `nav_hide()` hides the tab header but may not switch away
**How to avoid:** Before hiding the active tab, use `nav_select()` to switch to an appropriate visible tab first
**Warning signs:** Blank content area with no visible active tab in nav

### Pitfall 4: Observer Cascade Firing on Init
**What goes wrong:** `observeEvent` on `data_store$column_tags` fires at startup when tags are NULL, hiding tabs unnecessarily
**Why it happens:** Default `ignoreNULL = FALSE` and `ignoreInit = FALSE`
**How to avoid:** Set `ignoreNULL = TRUE` and `ignoreInit = TRUE` on cascade observers
**Warning signs:** Console warnings or unexpected tab state on app startup

### Pitfall 5: Re-upload Cancel Doesn't Restore File Input
**What goes wrong:** User cancels re-upload modal but the file input widget already shows the new filename
**Why it happens:** Browser file input updates immediately when file is selected — Shiny can't prevent this
**How to avoid:** On cancel, reset the file input with `shinyjs::reset("file_upload")` to restore previous state. The existing data in `data_store` remains untouched.
**Warning signs:** File input shows new filename but data is from old file

### Pitfall 6: Tag Changes Triggering Cascade During Initial Apply
**What goes wrong:** Setting tags for the first time triggers the "tag change" cascade, hiding tabs that were just about to be shown
**Why it happens:** Observer on `data_store$column_tags` doesn't distinguish first-apply from re-apply
**How to avoid:** Track previous tag state; only cascade-hide if tags were previously set AND are now changing. Or: the cascade observer should be on `input$apply_tags` button specifically, not on the reactive value itself.
**Warning signs:** Run Curation tab briefly appears then disappears on first tag apply

## Code Examples

### Complete Tab Gating Pattern
```r
# UI — tabs start hidden
navset_underline(
  id = "main_tabs",
  nav_panel("Data Preview", value = "data_preview", ...),
  nav_panel_hidden(value = "detection_info", title = "Detection Info", ...),
  nav_panel_hidden(value = "raw_data", title = "Raw Data", ...),
  nav_panel_hidden(value = "tag_columns", title = "Tag Columns", ...),
  nav_panel_hidden(value = "run_curation_tab", title = "Run Curation", ...),
  nav_panel_hidden(value = "review_results", title = "Review Results", ...)
)

# Server — show tabs when prerequisites are met
# After successful upload + detection:
observe({
  req(data_store$clean)
  nav_show("main_tabs", target = "detection_info")
  nav_show("main_tabs", target = "raw_data")
  nav_show("main_tabs", target = "tag_columns")
})

# After tags applied:
observe({
  req(data_store$column_tags)
  if (length(data_store$column_tags) > 0) {
    nav_show("main_tabs", target = "run_curation_tab")
  }
})

# After curation completed:
observe({
  req(data_store$curation_status)
  if (data_store$curation_status == "completed") {
    nav_show("main_tabs", target = "review_results")
    nav_select("main_tabs", "review_results")  # Auto-switch
  }
})
```
Source: Context7 /rstudio/bslib — nav_panel_hidden + nav_show pattern

### Confirmation Modal for Re-Upload
```r
# Temporary storage for pending upload
pending_upload <- reactiveVal(NULL)

observeEvent(input$file_upload, {
  req(input$file_upload)
  if (!is.null(data_store$clean)) {
    # Store pending and show modal
    pending_upload(input$file_upload)
    showModal(modalDialog(
      title = "Replace Current Data?",
      p("Your column tags and curation results will be cleared."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_reupload", "Replace Data", class = "btn-danger")
      )
    ))
  } else {
    process_upload(input$file_upload)
  }
})

observeEvent(input$confirm_reupload, {
  removeModal()
  reset_all_downstream()
  process_upload(pending_upload())
  pending_upload(NULL)
})
```
Source: Context7 /rstudio/shiny — showModal/modalDialog

### Full Reset Function
```r
reset_all_downstream <- function() {
  # Clear all downstream state
  data_store$column_tags <- NULL
  data_store$curation_results <- NULL
  data_store$curation_report <- NULL
  data_store$curation_status <- NULL

  # Hide downstream tabs
  nav_hide("main_tabs", target = "tag_columns")
  nav_hide("main_tabs", target = "run_curation_tab")
  nav_hide("main_tabs", target = "review_results")
  nav_hide("main_tabs", target = "detection_info")
  nav_hide("main_tabs", target = "raw_data")

  # Navigate back to upload
  nav_select("main_tabs", "data_preview")
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `shiny::hideTab()`/`showTab()` | bslib `nav_hide()`/`nav_show()` | bslib 0.5+ (2023) | Purpose-built for bslib layouts, handles internal state |
| `tabsetPanel` + `hideTab` | `navset_underline` + `nav_panel_hidden` | bslib 0.4+ (2023) | Declarative hidden tabs, no startup flash |
| jQuery show/hide on tab elements | bslib nav functions | bslib 0.5+ | Framework-aware, accessibility-correct |

**Deprecated/outdated:**
- `shiny::hideTab()`/`showTab()`: Still works but designed for `tabsetPanel`, not bslib `navset_*` layouts. Use bslib equivalents.

## Open Questions

1. **nav_panel_hidden title/icon rendering**
   - What we know: `nav_panel_hidden()` takes a `value` parameter for identification
   - What's unclear: Whether `title` and `icon` parameters work the same as `nav_panel()` when the panel is later shown via `nav_show()`
   - Recommendation: Test that title and icon appear correctly after `nav_show()`. If not, may need to use `nav_panel()` with immediate `nav_hide()` on session start (but this risks flash — verify).

## Sources

### Primary (HIGH confidence)
- Context7 /rstudio/bslib — nav_panel_hidden, nav_show, nav_hide, nav_select patterns
- Context7 /rstudio/shiny — modalDialog, showModal, observeEvent, reactiveValues patterns
- Context7 /daattali/shinyjs — addClass, removeClass, runjs for CSS animation

### Secondary (MEDIUM confidence)
- Shiny 1.0.4 changelog (Context7) — hideTab/showTab original API (confirms bslib equivalents exist)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project, patterns verified via Context7
- Architecture: HIGH - bslib nav_panel_hidden is purpose-built for this exact use case
- Pitfalls: HIGH - Well-documented observer timing and tab state issues in Shiny

**Research date:** 2026-02-26
**Valid until:** 2026-03-26 (stable R/Shiny ecosystem, low churn)
