# Project Research Summary

**Project:** ChemReg Multi-Tab Gated Curation Workflow
**Domain:** R Shiny multi-step workflow UI with gated tab navigation
**Researched:** 2026-02-26
**Confidence:** HIGH

## Executive Summary

ChemReg is transforming from a single "Curation" tab with stacked cards into a multi-tab workflow where users progress through: Tag Columns → Run Curation → Review Results. Research confirms **bslib's native `nav_panel_hidden()` + `nav_show()` pattern** is the recommended approach for gated navigation. This pattern provides clean API, preserves module state, and ensures accessibility without requiring custom CSS/JS hacks. All required dependencies (bslib 0.9.0, shinyjs 2.1.0) are already installed.

The recommended approach separates concerns cleanly: UI layer (bslib nav functions), reactive state layer (central reactiveValues store), and business logic layer (pure functions in R/curation.R). This architecture enables testability, prevents common pitfalls like lost state on tab switching, and maintains the existing data_store pattern. The critical insight is to **start tabs hidden** rather than showing then hiding (eliminates initialization race conditions), use `freezeReactiveValue()` on all programmatic input updates (prevents flicker), and store all workflow state in reactiveValues (prevents state loss).

Key risks center on **reactive timing issues**: initialization race conditions, reactive flicker during updates, infinite observer loops, and lost state during tab switching. All are preventable through proper patterns established in Phase 1 (foundation). The architecture research provides clear build order: Extract UI → Implement Gating → Polish, with each phase taking 1-2 hours and building on stable foundations.

## Key Findings

### Recommended Stack

**Core approach:** Use bslib's native navigation functions rather than legacy patterns or third-party frameworks. The stack is lightweight, well-documented, and already present in the project dependencies.

**Core technologies:**
- **bslib 0.9.0**: Navigation framework with native `nav_show()`/`nav_hide()` functions for programmatic tab control. Provides Bootstrap 5.3.1 foundation, proper accessibility with ARIA roles, and state preservation across visibility changes.
- **shinyjs 2.1.0**: Complements bslib for enabling/disabling UI elements within tabs. Essential for form validation (disable "Run Curation" button until tags applied) and progressive disclosure.
- **shiny ≥1.12.1**: Core reactive framework already in use. Provides `reactiveValues()` for state management, `freezeReactiveValue()` for preventing flicker, and `observe()` patterns for tab gating.

**Key insight:** The `nav_panel_hidden()` + `nav_show()` pattern is superior to alternatives because it preserves module state (unlike `nav_insert()`/`nav_remove()`), avoids div-wrapping hacks that break accessibility, and provides direct clean API designed specifically for this use case. The alternative shinymgr package is heavyweight overkill (requires SQLite, renv, shinydashboard) for single-app tab gating.

### Expected Features

Research identified clear table stakes vs. differentiators for multi-step workflow UIs. ChemReg's existing functionality (reactive data store, smart preview calculation) already covers several differentiators.

**Must have (table stakes):**
- Gated navigation enforcement (tabs appear only when prerequisites met)
- Completion state feedback (visual indicators that step is done)
- Clear step labels (action-oriented: "Tag Columns" not "Step 1")
- Empty state messaging (helpful explanation why content unavailable)
- Action button state management (disabled when prerequisites unmet)
- Data persistence across steps (reactiveValues pattern already in place)
- Back navigation allowed (users can revisit earlier tabs)

**Should have (competitive advantage):**
- Step validation summary ("2 columns still need tags" before proceeding)
- Inline help/tooltips (explain tagging options without leaving workflow)
- Auto-save indicators (reassure users work is saved)
- Undo/reset step (clear tags without restarting entire workflow)
- Export at any stage (download partial results for iterative refinement)

**Defer (v2+ or different project):**
- Real-time validation preview (live count of detected chemicals while tagging)
- Progress persistence across sessions (resume after browser refresh)
- Batch tagging operations ("tag all numeric columns as CASRN")
- Custom tag types (beyond Chemical Name/CASRN/Other)

**Anti-features to explicitly avoid:**
- Next/Previous buttons instead of tabs (hides workflow structure, increases form abandonment)
- Auto-advance to next tab (disorienting, users lose control)
- Modal wizards (claustrophobic for data-heavy workflows)
- Mandatory linear progression (frustrates users who want to review earlier steps)

### Architecture Approach

The recommended architecture maintains ChemReg's existing patterns while adding explicit tab gating. Three-layer separation: UI (bslib navigation), reactive state (single reactiveValues store), and business logic (pure functions). This approach prioritizes testability, state preservation, and clear data flow.

**Major components:**

1. **Hidden Tabs with Reactive Gating** — Start tabs hidden using `nav_panel_hidden()`, reveal conditionally with `nav_show()` based on reactive state flags. Prevents user confusion from empty states, enforces correct workflow order, uses native bslib pattern.

2. **Reactive State Store with Workflow Flags** — Single `reactiveValues()` object as central state store (already exists as `data_store`). Add `tabs_unlocked` tracking to prevent redundant `nav_show()` calls, use explicit status enums ("idle", "running", "complete") over scattered boolean flags.

3. **Separation of Business Logic from Reactivity** — Keep pure functions (curation API calls, validation) in R/curation.R, called from reactive observers. This makes functions testable without Shiny session, reusable across contexts, and easier to refactor.

4. **Conditional UI with `conditionalPanel`** — Use for fine-grained control within tabs (show/hide elements based on state), not for tab-level control. Provides smooth browser-side animations without server round-trips for simple show/hide logic.

**Data flow:** File Upload → Detection → Clean Data → Tag Columns → [nav_show("run_curation")] → Run Curation → [nav_show("review_results")] → Review Results → Export. State flows through central `data_store` reactiveValues, with observers triggering tab visibility changes at workflow milestones.

### Critical Pitfalls

Research identified six critical pitfalls, all preventable through patterns established during Phase 1 foundation work.

1. **Tab Initialization Timing Race Conditions** — Tabs briefly visible before server-side `hideTab()` executes, allowing users to click gated tabs during startup. **Prevention:** Use `nav_panel_hidden()` from the start instead of showing then hiding. Eliminates the visibility window entirely.

2. **Reactive State Flicker During Input Updates** — Outputs briefly show stale data when switching tabs because `updateTabsetPanel()` takes effect after observer flush cycle. **Prevention:** ALWAYS use `freezeReactiveValue(input, "field_name")` before any `update*()` call. This prevents downstream reactives from seeing old values during transition.

3. **Infinite Reactive Loops with Gated Navigation** — Observer watches reactive value while also modifying it, creating feedback loop. **Prevention:** Use `isolate()` to read values without creating dependencies, prefer `observeEvent()` over `observe()` for explicit triggers, separate "trigger" reactives from "state storage" reactives.

4. **Lost Reactive State When Switching Tabs** — State stored only in UI outputs or temporary reactives is lost when tabs become invisible. **Prevention:** Store ALL workflow state in `reactiveValues()` or `reactiveVal()` objects, never rely on input values alone for state, prefer static UI with conditional visibility over `renderUI()`.

5. **Wrong Tab ID References with nav_show/nav_hide** — Functions fail silently because developers confuse container id vs. tab value. The API requires `nav_show(id = "container_id", target = "tab_value")` where id is the navset container and target is the specific tab. **Prevention:** Document tab structure clearly, set explicit `id` on navset and `value` on each nav_panel, test interactively before embedding in observers.

6. **Observer Execution on Hidden Tab Content** — Observers and reactives in hidden tabs continue executing even when not visible, wasting resources and potentially triggering unwanted side effects. **Prevention:** Use `req(input$main_tabs == "target_tab")` at start of tab-specific observers, scope expensive operations inside outputs (which auto-suspend), use `bindEvent()` to control when reactives execute.

## Implications for Roadmap

Based on research, the work naturally divides into three sequential phases following the architecture's recommended build order. Each phase builds on stable foundations, minimizing rework and ensuring validation at each step.

### Phase 1: Extract UI and Implement Foundation (1-2 hours)

**Rationale:** Separate the monolithic "Curation" tab into three independent tabs while establishing proper state management patterns. This creates stable foundation before adding gating behavior. Architecture research shows this "safe refactor" approach prevents breaking existing functionality while restructuring.

**Delivers:**
- Three separate top-level tabs (Tag Columns, Run Curation, Review Results) replacing stacked cards
- `tabs_unlocked` tracking added to `data_store` reactiveValues
- All tabs visible initially (gating comes in Phase 2)
- Full-width layouts using available space (cards removed)
- Existing functionality preserved (tagging, curation, download)

**Addresses features:**
- Clear step labels (table stakes)
- Full-width responsive layouts (table stakes)
- Data persistence across steps (table stakes, already present)

**Avoids pitfalls:**
- Lost reactive state (by establishing reactiveValues pattern from start)
- Wrong tab ID references (by documenting structure and setting explicit ids)
- Business logic in observers (by maintaining separation from existing R/curation.R)

**Research flags:** Standard refactoring, no additional research needed. Architecture patterns are well-documented in bslib reference.

### Phase 2: Implement Tab Gating Logic (1 hour)

**Rationale:** Add conditional tab visibility now that structure is stable. Starting tabs hidden prevents initialization race conditions (Pitfall #1). Using `nav_panel_hidden()` + `nav_show()` provides clean API without timing hacks.

**Delivers:**
- Tab 2 (Run Curation) starts hidden, revealed when tags applied
- Tab 3 (Review Results) starts hidden, revealed when curation completes
- User notifications guide workflow ("Tags applied! Proceed to Run Curation.")
- `freezeReactiveValue()` used on all programmatic updates
- State validation before showing tabs

**Addresses features:**
- Gated navigation enforcement (table stakes)
- Completion state feedback (table stakes)
- Empty state messaging (table stakes)
- Action button state management (table stakes)

**Avoids pitfalls:**
- Tab initialization race conditions (using nav_panel_hidden from start)
- Reactive flicker (using freezeReactiveValue on updates)
- Infinite loops (using observeEvent with explicit triggers)
- Observer waste (adding req() guards for tab-specific logic)

**Uses stack:**
- bslib `nav_panel_hidden()`, `nav_show()`
- shinyjs `disable()`/`enable()` for button states
- Shiny `freezeReactiveValue()`, `observeEvent()`, `req()`

**Research flags:** Standard gating pattern, no additional research needed. Stack research verified all functions available and documented implementation.

### Phase 3: UI Polish and Enhancements (1-2 hours)

**Rationale:** With core gating working, use freed-up space for better layouts and add user-facing polish. Features research identified step validation summary and inline help as high-value, medium-complexity additions.

**Delivers:**
- Validation summary ("2 columns still need tags" guidance)
- Layout improvements using bslib `layout_columns()` and `value_box()`
- Inline help tooltips explaining tag types
- Auto-save indicators (timestamp after tag changes)
- Visual completion indicators (checkmarks or status badges)
- Whitespace and typography improvements

**Addresses features:**
- Step validation summary (differentiator)
- Inline help/tooltips (differentiator)
- Auto-save indicators (differentiator)
- Visual progress indicator (table stakes)

**Implements architecture:**
- `conditionalPanel()` for within-tab show/hide
- `bslib::tooltip()` for inline help
- `value_box()` for summary statistics in Review Results

**Research flags:** Standard UI patterns, no additional research needed. Features research provided clear implementation guidance for tooltips and validation summaries.

### Phase 4: Testing and Documentation (Optional - 1 hour)

**Rationale:** Validate all tab gating edge cases and document new workflow patterns. Pitfalls research identified specific failure modes to test.

**Delivers:**
- Test: Tab visibility changes correctly based on prerequisites
- Test: State persists across all tab navigation sequences
- Test: No flicker when switching tabs or updating inputs
- Test: Observers don't fire for hidden tabs unnecessarily
- Documentation: Tab structure (container ids, panel values)
- Documentation: State management patterns (tabs_unlocked usage)

**Avoids pitfalls:**
- Security bypass (verify server-side guards prevent premature access)
- UX feedback gaps (verify all gated states have clear messaging)

**Research flags:** No additional research needed. Pitfalls research provided comprehensive testing checklist.

### Phase Ordering Rationale

**Sequential dependencies:**
1. Phase 1 establishes structure → Phase 2 requires stable tab structure to add gating
2. Phase 2 implements gating → Phase 3 requires working gating to polish UX
3. Phase 3 adds polish → Phase 4 validates complete system

**Why this prevents rework:**
- Extracting UI first (Phase 1) proves structure works before changing behavior
- Implementing gating second (Phase 2) validates pattern before adding complexity
- Polishing last (Phase 3) avoids redoing layouts if gating requires structural changes

**Architecture alignment:**
- Follows architecture's recommended "Extract UI → Implement Gating → Polish" order
- Each phase has clear validation criteria before proceeding
- No parallel work possible (each phase depends on previous completion)

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 1**: UI extraction is standard refactoring, bslib nav patterns well-documented
- **Phase 2**: Tab gating is standard bslib pattern with official examples
- **Phase 3**: UI polish uses standard bslib components (layout_columns, value_box, tooltip)
- **Phase 4**: Testing follows standard Shiny testing patterns

**No phases require deeper research.** All patterns are well-documented in official bslib/Shiny documentation, verified via Context7 and official reference materials.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations verified via Context7 bslib documentation and official RStudio docs. Versions confirmed in CRAN. All dependencies already installed. |
| Features | HIGH | Table stakes identified from multiple UX research sources (NN/g, WAI guidance, form best practices). Differentiators validated against community Shiny patterns. Anti-features confirmed via usability research. |
| Architecture | HIGH | Patterns verified in official bslib documentation with working examples. Build order validated against Posit Community discussions. Reactive patterns standard Shiny best practices. |
| Pitfalls | HIGH | All six critical pitfalls documented in official Shiny/bslib sources or GitHub issues. Prevention strategies tested in community. Recovery costs validated through engineering-shiny resources. |

**Overall confidence:** HIGH

All core recommendations come from official documentation (bslib reference, Shiny guides) or well-established community consensus (Mastering Shiny, Engineering Production-Grade Shiny Apps). No experimental techniques or unproven patterns. The recommended approach (`nav_panel_hidden` + `nav_show`) is explicitly designed for this use case per bslib 0.8.0+ documentation.

### Gaps to Address

**Minor gaps requiring validation during implementation:**

1. **Performance with large datasets:** Research covered general patterns but didn't quantify thresholds. Validate with actual ChemReg data sizes (number of columns to tag, size of curation results). Likely non-issue given DT already handles large tables well, but worth profiling in Phase 3.

2. **CompTox API integration specifics:** Stack research verified ComptoxR package exists and uses ctx_api_key environment variable. Didn't deep-dive on rate limiting behavior or error handling patterns. Validate error states during Phase 2 implementation (what happens if API key invalid, rate limit hit, network timeout). Existing code likely handles this, but document explicitly.

3. **Mobile/tablet responsiveness:** Features research noted tabs are desktop-focused pattern. Current app uses bslib which is responsive by default, but didn't validate tab switching UX on mobile specifically. Test on tablet during Phase 3 polish if mobile users are expected. Defer mobile optimization to v2 if not critical.

**How to handle:**
- Performance: Profile with `profvis` during Phase 3, add `req()` guards if render times >500ms
- API integration: Test error states manually during Phase 2, add explicit error notifications
- Mobile: Test on tablet if users expected, otherwise document as known limitation

**No gaps that block implementation.** All core patterns validated and ready to implement.

## Sources

### Primary (HIGH confidence)

**Official Documentation:**
- [bslib Navigation Containers Reference](https://rstudio.github.io/bslib/reference/navset.html) — navset functions, nav_panel_hidden usage
- [bslib Dynamically Update Nav Containers](https://rstudio.github.io/bslib/reference/nav_select.html) — nav_show, nav_hide, nav_select, nav_insert, nav_remove
- [bslib Navigation Items Reference](https://rstudio.github.io/bslib/reference/nav-items.html) — nav_panel, nav_menu, nav_panel_hidden
- [Context7 /rstudio/bslib](https://context7.com/rstudio/bslib) — Programmatic tab control examples, nav_show/nav_hide patterns
- [Context7 /daattali/shinyjs](https://context7.com/rstudio/shinyjs) — enable, disable, toggleState, show, hide functions
- [Shiny freezeReactiveValue](https://shiny.posit.co/r/reference/shiny/1.7.0/freezereactivevalue.html) — Preventing reactive flicker
- [Shiny hideTab/showTab](https://shiny.posit.co/r/reference/shiny/latest/showtab.html) — Legacy tab control functions

**CRAN Package Pages:**
- [bslib CRAN Package](https://cran.r-project.org/package=bslib) — Version 0.9.0, January 30, 2025
- [shinyjs CRAN Package](https://cran.r-project.org/web/packages/shinyjs/index.html) — Version 2.1.0, January 15, 2026

### Secondary (MEDIUM confidence)

**Community Best Practices:**
- [Posit Community: Dynamically show/hide panels](https://forum.posit.co/t/bslib-page-navbar-dynamically-show-hide-panels/207882) — nav_show/hide vs. nav_insert/remove tradeoffs
- [Mastering Shiny: Reactive Building Blocks](https://mastering-shiny.org/reactivity-objects.html) — reactiveValues patterns
- [Mastering Shiny: Dynamic UI](https://mastering-shiny.org/action-dynamic.html) — conditional UI patterns
- [Engineering Production-Grade Shiny Apps: Common Caveats](https://engineering-shiny.org/common-app-caveats.html) — Pitfall identification
- [Dean Attali: Advanced Shiny Tips](https://deanattali.com/blog/advanced-shiny-tips/) — Best practices

**UX Research:**
- [Nielsen Norman Group: Wizards](https://www.nngroup.com/articles/wizards/) — Multi-step flow design
- [WebStacks: Multi-Step Form Best Practices](https://www.webstacks.com/blog/multi-step-form) — 3-7 steps optimal, progress indicators
- [Progress Indicator Design](https://lollypop.design/blog/2025/november/progress-indicator-design/) — Stepper patterns
- [WAI: Progress Trackers](https://userguiding.com/blog/progress-trackers-and-indicators) — Accessibility guidance

**GitHub Issues:**
- [shinyjs #43: Tab Hiding Timing](https://github.com/daattali/shinyjs/issues/43) — Initialization race conditions
- [Shiny #2865: Request to freeze observers on input updates](https://github.com/rstudio/shiny/issues/2865) — freezeReactiveValue background

### Tertiary (LOW confidence, not used for core recommendations)

- [shinymgr Academic Publication](https://journal.r-project.org/articles/RJ-2024-009/) — Alternative framework (rejected as overkill)
- [Shiny Loading Skeleton GitHub](https://github.com/nanxstats/shiny-loading-skeleton) — Community template (deferred to v2+)

---
*Research completed: 2026-02-26*
*Ready for roadmap: yes*
