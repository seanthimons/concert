# Feature Research: Multi-Step Curation Workflow UIs

**Domain:** Multi-step data curation workflow in Shiny applications
**Researched:** 2026-02-26
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or unprofessional.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Visual progress indicator** | Users need to know where they are in the workflow (step 2 of 3) | LOW | Progress steppers are vital UI elements per WAI UX guidance; communicate total steps and current position. Use numeric or segmented bar. |
| **Completion state feedback** | Users need confirmation that a step is done before moving on | LOW | Checkmarks, status badges ("Complete" not "Pending"), or color-coding for finished steps. Phase labels show ✓ for completion. |
| **Gated navigation enforcement** | Prevents confusion from accessing empty/incomplete states | MEDIUM | Use `hideTab()`/`showTab()` in Shiny or conditionalPanel to disable tabs until prerequisites met. Standard pattern in multi-step forms. |
| **Clear step labels** | Users must understand what each step does | LOW | Descriptive tab/step names (not "Step 1, Step 2"). Use action-oriented labels: "Tag Columns", "Run Curation", "Review Results". |
| **Empty state messaging** | Users need to understand why content isn't available yet | LOW | When tab is unlocked but no data exists, show helpful message: "Complete column tagging to enable curation" with icon/illustration. |
| **Error state visibility** | Users must see validation failures immediately | MEDIUM | Inline validation messages appear next to problem fields. Don't wait until end of workflow to show errors from earlier steps. |
| **Action button state management** | Buttons disabled when prerequisites not met | LOW | Use `shinyjs::disable()` or reactive `disabled` attribute. Visual feedback (reduced opacity, greyed out) indicates why button unavailable. |
| **Data persistence across steps** | Users expect their work saved as they navigate tabs | MEDIUM | Use `reactiveValues()` data store pattern (already in ChemReg). Work persists when switching tabs. |
| **Back navigation allowed** | Users need ability to review/edit previous steps | LOW | Tabs remain accessible after completion. Don't force linear-only navigation after step complete. Allow revisiting earlier tabs. |
| **Responsive layout** | Multi-step workflows often have lengthy forms/tables | LOW | Use full available space per step instead of cramming into cards. `fillable = TRUE` for bslib layouts. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued by users.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Smart preview row calculation** | Automatically adjusts preview size based on file size/complexity | LOW | ChemReg already has this in `calculate_smart_preview_rows()`. Users appreciate not having to manually tune preview settings. |
| **Step validation summary** | Shows what's missing before allowing next step | MEDIUM | Summary at top of step: "2 columns still need tags" or "All 8 columns tagged ✓". Reduces confusion about why can't proceed. |
| **Inline help/tooltips** | Context-sensitive guidance without leaving workflow | LOW | Use `bslib::tooltip()` or `shinyjs` hover effects. Explain tagging options, validation rules, etc. without modal dialogs interrupting flow. |
| **Auto-save indicators** | Reassure users their work is saved | LOW | Small "Saved" indicator or timestamp after changes applied. Reduces anxiety about losing work during long workflows. |
| **Keyboard shortcuts** | Power users navigate faster | MEDIUM | Tab to move between fields, Enter to submit, Esc to cancel modals. Accessibility benefit as well. Requires `shinyjs` custom JavaScript. |
| **Undo/reset step** | Allows resetting a step without restarting entire workflow | MEDIUM | "Clear all tags" or "Reset curation" button. Use `showModal()` confirmation before destructive action. Saves re-uploading file. |
| **Export at any stage** | Download partial results even if workflow incomplete | MEDIUM | "Export current state" button available after step 1 complete. Useful for iterative refinement or troubleshooting. |
| **Batch operations** | Apply same action to multiple items at once | MEDIUM | "Tag all as Chemical Name" dropdown or "Select all untagged columns". Reduces repetitive clicking for large datasets. |
| **Real-time validation preview** | Show validation results as user types/selects | HIGH | Live preview of how tagging affects curation (e.g., "12 CAS numbers will be validated"). Requires reactive programming complexity. |
| **Progress persistence across sessions** | Resume workflow after browser close/refresh | HIGH | Store workflow state in browser localStorage or server-side session. Requires serialization logic and session management. Complex but high value. |

### Anti-Features (Commonly Requested, Often Problematic)

Features to explicitly NOT build or defer indefinitely.

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| **Next/Previous buttons instead of tabs** | Feels like "standard wizard" | Hides workflow structure; users can't see what's coming; harder to jump back | Use visible tabs with gating. Users want to see all steps upfront (24% abandon forms due to lack of clarity on completion). |
| **Auto-advance to next tab** | Reduces clicks | Disorienting; users lose control; may want to review current step | Let users explicitly navigate. Show completion checkmark but keep them on current tab until they choose to move. |
| **Modal wizards (popup flow)** | Saves screen space | Traps users; can't reference other parts of app; feels claustrophobic for multi-step workflows | Keep workflow in main page. Use full screen space per step. Modals better for single confirmations, not multi-step processes. |
| **Mandatory linear progression** | Forces "correct" order | Frustrates users who want to skip ahead or review; assumes one-size-fits-all workflow | Gate only essential prerequisites (can't curate without tags), but allow revisiting completed steps. |
| **Real-time everything** | Feels responsive | Creates complexity without value; unnecessary API calls; confusing intermediate states | Use debounced validation (300-500ms) or on-blur. Submit/apply button for intentional actions. |
| **Drag-and-drop for all interactions** | Looks modern | Harder to implement, worse accessibility, not mobile-friendly, overkill for simple tag assignment | Use dropdown selects or radio buttons. Simpler, more accessible, familiar pattern. |
| **Sub-tabs within steps** | More organization | Adds cognitive load; users lose track of nesting level; violates "3-7 steps optimal" guidance | Keep steps flat. If step too complex for one tab, split into separate top-level tabs. |
| **Persistent disabled buttons** | Shows what's coming | Confuses users (why grey? what's wrong? how to fix?); no feedback; bad accessibility | Hide buttons until prerequisites met OR show enabled with validation message on click explaining requirements. |

## Feature Dependencies

```
[File Upload]
    └──requires──> [Data Detection]
                       └──requires──> [Data Preview Available]
                                          └──enables──> [Tag Columns Tab]

[Tag Columns Complete] (at least 1 tag applied)
    └──enables──> [Run Curation Tab]
                      └──requires──> [API Key Available]

[Curation Complete]
    └──enables──> [Review Results Tab]
                      └──enhances──> [Export Options]

[Preview Settings] ──enhances──> [Data Preview]

[Detection Mode Switch] ──invalidates──> [Existing Tags]
                            └──requires──> [Confirmation Modal]

[Clear Tags Action] ──conflicts──> [Run Curation]
                         └──requires──> [Reset Curation State]
```

### Dependency Notes

- **Tag Columns requires Data Preview:** Can't tag columns until frontmatter detection identifies headers. Tab stays hidden until detection complete.
- **Run Curation requires Tag Columns:** Need at least one column tagged (Chemical Name or CASRN) to run validation. Show validation message if try to run without tags.
- **Curation requires API Key:** ComptoxR needs `ctx_api_key` environment variable. Check on app start; show warning in sidebar if missing.
- **Detection Mode Switch resets tags:** If user changes from automatic to manual (or changes manual row), existing tags may no longer align with columns. Warn and confirm before applying.
- **Export enhances with Review:** Basic export available after tagging (tagged columns only), but full report with statistics only available after curation complete.

## MVP Definition

### Launch With (Current Iteration — Breaking Tabs)

Minimum features to make gated tab workflow functional and better than current single-tab approach.

- [x] **Three separate top-level tabs** — Tag Columns, Run Curation, Review Results (replaces stacked cards)
- [x] **Tab gating via hideTab/showTab** — Tabs appear only when prerequisites met
- [x] **Completion state indicators** — Visual checkmark or "Complete" badge on finished tabs
- [x] **Empty state messaging** — Helpful message in locked tabs explaining how to unlock
- [x] **Action button disabling** — "Run Curation" button disabled until tags applied
- [x] **Data store persistence** — Existing reactiveValues pattern maintains state across tabs
- [x] **Full-width layouts** — Each tab uses available space (remove card stacking)
- [x] **Dropdown column tagging** — Keep existing simple dropdown approach (Option A from decisions)
- [x] **Error notifications** — Use existing `showNotification()` for validation failures
- [x] **Back navigation** — Allow returning to Tag Columns to modify tags

### Add After Validation (Post-Launch Polish — v1.1)

Features to add once core tab-gating workflow is stable and tested.

- [ ] **Progress indicator header** — Numeric "Step 2 of 3" or segmented progress bar above tabs
- [ ] **Step validation summary** — Count of tagged/untagged columns; count of matched/unmatched chemicals
- [ ] **Auto-save indicators** — Timestamp or "Saved" label after tag changes applied
- [ ] **Clear tags confirmation** — Modal dialog: "Are you sure? This will reset curation results."
- [ ] **Inline help tooltips** — Explain tag types (Chemical Name vs CASRN) and curation behavior
- [ ] **Keyboard navigation** — Tab key navigation, Enter to submit forms
- [ ] **Export partial results** — Download tagged data before running curation

### Future Consideration (v2+ or Different Project)

Features to defer until product-market fit established or significant user requests.

- [ ] **Batch tagging operations** — "Tag all numeric columns as CASRN" quick action
- [ ] **Undo/reset individual steps** — Reset just tagging or just curation without re-uploading
- [ ] **Real-time validation preview** — Live count of CAS numbers detected while tagging
- [ ] **Progress persistence across sessions** — Resume workflow after browser refresh (requires session storage)
- [ ] **Custom tag types** — User-defined tags beyond Chemical Name/CASRN/Other
- [ ] **Multi-file batch processing** — Upload and process multiple inventories in single session
- [ ] **Skeleton loading screens** — Animated placeholder UI during curation API calls
- [ ] **Mobile-responsive workflow** — Optimize for tablet/phone (currently desktop-focused)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Three separate tabs | HIGH | LOW | P1 |
| Tab gating (hide/show) | HIGH | MEDIUM | P1 |
| Completion indicators | MEDIUM | LOW | P1 |
| Empty state messages | MEDIUM | LOW | P1 |
| Button disabled states | HIGH | LOW | P1 |
| Full-width tab layouts | MEDIUM | LOW | P1 |
| Progress indicator header | MEDIUM | LOW | P2 |
| Validation summary | HIGH | MEDIUM | P2 |
| Auto-save indicators | LOW | LOW | P2 |
| Clear tags confirmation | MEDIUM | LOW | P2 |
| Inline help tooltips | MEDIUM | LOW | P2 |
| Keyboard shortcuts | LOW | MEDIUM | P2 |
| Export partial results | MEDIUM | MEDIUM | P2 |
| Batch tagging operations | MEDIUM | MEDIUM | P3 |
| Undo/reset steps | MEDIUM | MEDIUM | P3 |
| Real-time preview | MEDIUM | HIGH | P3 |
| Session persistence | HIGH | HIGH | P3 |
| Custom tag types | LOW | MEDIUM | P3 |
| Skeleton loaders | LOW | MEDIUM | P3 |

**Priority key:**
- **P1**: Must have for launch — core gated workflow functionality
- **P2**: Should have, add when time permits — UX polish and user feedback improvements
- **P3**: Nice to have, future consideration — advanced features or high complexity

## Workflow UX Patterns: Tabs vs Steppers vs Wizards

### When to Use Tabs (CHOSEN for ChemReg)

**Best for:** Non-sequential or semi-sequential content where users may need to jump between sections.

**Advantages:**
- All steps visible at once (reduces cognitive load)
- Users can see progress and what's coming
- Easy to return to previous steps
- Familiar pattern in data applications
- Works well with gating (show/hide tabs dynamically)

**Shiny Implementation:** `navset_tab()` or `page_navbar()` with `nav_panel()`, controlled via `hideTab()`/`showTab()`

**Why for ChemReg:** Users need to see the full workflow (upload → tag → curate → review). May want to jump back to tagging after seeing curation results. Tabs provide visibility and flexibility while still allowing gating.

### When to Use Steppers (NOT CHOSEN)

**Best for:** Strictly linear processes with clear beginning/middle/end where each step builds on previous.

**Advantages:**
- Clear linear progression
- Progress bar built-in
- Strong visual "you are here" indicator

**Disadvantages:**
- Harder to jump back to earlier steps
- Can feel rigid
- More complex to implement in Shiny (requires custom UI)

### When to Use Modal Wizards (NOT CHOSEN)

**Best for:** Single quick task (3-5 steps max) that interrupts main workflow temporarily.

**Advantages:**
- Focused attention
- Clear start/end
- Useful for onboarding or one-time setup

**Disadvantages:**
- Traps users (can't reference other content)
- Claustrophobic for lengthy workflows
- Bad for accessibility
- Not suitable for data-heavy processes

**Why NOT for ChemReg:** Multi-step data curation requires seeing data tables, switching between preview and results, and potentially long processing times. Modal would feel constraining.

## Shiny-Specific Implementation Notes

### Tab Gating Pattern (HIGH Confidence — Context7 verified)

```r
# In server function:

# Initially hide gated tabs
hideTab(inputId = "main_tabs", target = "run_curation")
hideTab(inputId = "main_tabs", target = "review_results")

# Show Run Curation tab when tags applied
observeEvent(data_store$column_tags, {
  if (any(!is.na(data_store$column_tags))) {
    showTab(inputId = "main_tabs", target = "run_curation", select = FALSE)
  }
})

# Show Review Results tab when curation complete
observeEvent(data_store$curation_results, {
  if (!is.null(data_store$curation_results)) {
    showTab(inputId = "main_tabs", target = "review_results", select = TRUE)
  }
})
```

### Button State Management (HIGH Confidence — Context7 verified)

```r
# Disable button until ready
observe({
  if (is.null(data_store$column_tags) || all(is.na(data_store$column_tags))) {
    shinyjs::disable("run_curation_btn")
  } else {
    shinyjs::enable("run_curation_btn")
  }
})
```

### Validation Messaging (HIGH Confidence — Context7 verified)

```r
# Use validate() for reactive outputs
output$curation_table <- renderDT({
  validate(
    need(!is.null(data_store$curation_results),
         "Complete curation to view results")
  )
  datatable(data_store$curation_results)
})

# Use showNotification() for user actions
observeEvent(input$run_curation_btn, {
  if (!has_api_key()) {
    showNotification(
      "ComptoxR API key not found. Set ctx_api_key environment variable.",
      type = "error",
      duration = 10
    )
    return()
  }
  # ... proceed with curation
})
```

### Completion Indicators (MEDIUM Confidence — general UX pattern)

```r
# Add checkmark icon to completed tabs programmatically
observe({
  if (!is.null(data_store$column_tags) && any(!is.na(data_store$column_tags))) {
    # Update tab label to include checkmark
    # Note: Requires custom JS or bslib nav_panel title update
    # Simpler: Show status badge within tab content
  }
})

# Within tab content:
uiOutput("tagging_status")

output$tagging_status <- renderUI({
  if (!is.null(data_store$column_tags) && any(!is.na(data_store$column_tags))) {
    span(
      class = "badge bg-success",
      bsicons::bs_icon("check-circle"),
      "Tagging Complete"
    )
  }
})
```

### Empty State Pattern (LOW Confidence — best practice, not Shiny-specific)

```r
# Within locked tab content:
div(
  class = "text-center py-5",
  bsicons::bs_icon("lock", size = "3em", class = "text-muted mb-3"),
  h4("Column Tagging Required"),
  p("Complete column tagging in the previous tab to enable curation."),
  actionButton("goto_tagging", "Go to Tag Columns", class = "btn-primary")
)

# Button handler to switch tabs
observeEvent(input$goto_tagging, {
  updateTabsetPanel(session, "main_tabs", selected = "tag_columns")
})
```

## Complexity Analysis

### Low Complexity (1-2 hours implementation)
- Three separate tabs replacing cards
- Tab hiding/showing with `hideTab()`/`showTab()`
- Button enable/disable with `shinyjs`
- Empty state HTML/CSS
- Validation messages with `validate()`/`need()`
- Full-width layouts (`fillable = TRUE`)

### Medium Complexity (3-6 hours implementation)
- Tab gating logic with multiple prerequisites
- Reactive state management for completion tracking
- Confirmation modals for destructive actions
- Validation summary calculations
- Inline help tooltips with `bslib::tooltip()`

### High Complexity (1-2 days implementation)
- Real-time validation preview (requires reactive pipeline)
- Session persistence across browser refresh (localStorage + serialization)
- Keyboard navigation (custom JavaScript)
- Skeleton loading screens (custom CSS animations)
- Progress indicator synchronization (track state across multiple reactives)

## Testing Considerations

### Must Test (P1 Features)
- Tab visibility changes correctly based on prerequisites
- Button states update when data changes
- Navigation between tabs preserves data
- Error messages appear inline near problem areas
- Empty states display when expected
- Completion indicators appear after step done

### Should Test (P2 Features)
- Progress indicator shows correct step
- Validation summary counts accurate
- Tooltips appear on hover/focus
- Confirmation modals prevent accidental data loss
- Export works at each stage

### Nice to Test (P3 Features)
- Keyboard shortcuts work across browsers
- Session persistence survives refresh
- Real-time preview performs well with large datasets

## Accessibility Requirements (WCAG Compliance)

- **Tab navigation:** Use proper ARIA roles (`role="tablist"`, `role="tab"`, `role="tabpanel"`)
- **Disabled states:** Use `aria-disabled="true"` not just visual styling
- **Validation messages:** Associate with fields using `aria-describedby`
- **Progress indicators:** Announce to screen readers with `aria-live="polite"`
- **Keyboard navigation:** All interactive elements reachable via Tab key
- **Focus management:** When showing tab, move focus to tab content
- **Color not sole indicator:** Use icons + text + color for completion states

## Sources

### High Confidence (Context7 + Official Docs)
- [Shiny Tab Control](https://context7.com/rstudio/shiny) — `hideTab()`, `showTab()`, `conditionalPanel()`
- [bslib Navigation](https://context7.com/rstudio/bslib) — `navset_tab()`, `nav_panel()`, `nav_panel_hidden()`
- [Shiny Validation](https://context7.com/rstudio/shiny) — `validate()`, `need()`, `req()`
- [Shiny Notifications](https://context7.com/rstudio/shiny) — `showNotification()`, `showModal()`

### Medium Confidence (Official Docs + Community)
- [Wizard UI Pattern](https://www.eleken.co/blog-posts/wizard-ui-pattern-explained) — When to use wizards vs tabs
- [Multi-Step Form Best Practices](https://www.webstacks.com/blog/multi-step-form) — 3-7 steps optimal, progress indicators, validation timing
- [Nielsen Norman Group: Wizards](https://www.nngroup.com/articles/wizards/) — Design recommendations for multi-step flows
- [Mastering Shiny: Dynamic UI](https://mastering-shiny.org/action-dynamic.html) — Conditional UI patterns
- [Shiny Official: Tabs](https://shiny.posit.co/r/reference/shiny/1.7.0/showtab.html) — `showTab()` documentation

### Medium Confidence (UX Research + Design Systems)
- [Progress Indicator Design](https://lollypop.design/blog/2025/november/progress-indicator-design/) — Best practices for steppers and progress bars
- [PatternFly: Progress Stepper](https://www.patternfly.org/components/progress-stepper/design-guidelines/) — When to use steppers
- [UXPin: Progress Trackers](https://www.uxpin.com/studio/blog/design-progress-trackers/) — User expectations for multi-step flows
- [UserGuiding: Progress Indicators](https://userguiding.com/blog/progress-trackers-and-indicators) — WAI accessibility guidance

### Medium Confidence (Validation UX)
- [Inline Validation UX](https://blog.logrocket.com/ux-design/ux-form-validation-inline-after-submission/) — Timing: late validation (on-blur) performs better
- [NN/G: Form Error Guidelines](https://www.nngroup.com/articles/errors-forms-design-guidelines/) — Error message placement and messaging
- [Smashing Magazine: Inline Validation](https://www.smashingmagazine.com/2022/09/inline-validation-web-forms-ux/) — Debounce 300-500ms for format rules
- [Accessible Form Validation](https://blog.pope.tech/2025/09/30/accessible-form-validation-with-examples-and-code/) — ARIA attributes and live regions

### Medium Confidence (Button States + Visual Feedback)
- [NN/G: Button States](https://www.nngroup.com/articles/button-states-communicate-interaction/) — Visual indicators for enabled/disabled/processing
- [Button State Design](https://www.mockplus.com/blog/post/button-state-design) — 5 states: enabled, disabled, hover, focus, pressed
- [Disabled Button UX](https://www.smashingmagazine.com/2024/05/hidden-vs-disabled-ux/) — Hidden vs disabled debate; when to use each

### Medium Confidence (Tabs vs Wizards)
- [Tabbed Navigation UX](https://blog.logrocket.com/ux-design/tabs-ux-best-practices/) — When to use tabs vs other patterns
- [Stepper UI Examples](https://www.eleken.co/blog-posts/stepper-ui-examples) — Use cases for steppers in linear workflows
- [Progressive Form vs Wizard](https://medium.com/patternfly/comparing-web-forms-a-progressive-form-vs-a-wizard-110eefc584e7) — All steps on one page vs separate pages

### Low Confidence (Dashboard + Data Quality)
- [Dashboard UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-data-dashboards) — General dashboard design (not Shiny-specific)
- [Data Quality Dashboards](https://atlan.com/know/data-quality-dashboards/) — Quality metrics and monitoring (enterprise scale, not single-user workflows)
- [Smashing Magazine: Real-Time Dashboards](https://www.smashingmagazine.com/2025/09/ux-strategies-real-time-dashboards/) — Dashboard interactivity patterns

### Low Confidence (Skeleton Loaders)
- [Skeleton Loading Design](https://blog.logrocket.com/ux-design/skeleton-loading-screen-design/) — General pattern explanation
- [Shiny Loading Skeleton GitHub](https://github.com/nanxstats/shiny-loading-skeleton) — Community template, not official
- [shinyMobile: f7Skeleton](https://rinterface.github.io/shinyMobile/reference/f7Skeleton.html) — Mobile-specific, different use case than desktop workflow

---
*Feature research for: ChemReg multi-step curation workflow*
*Researched: 2026-02-26*
