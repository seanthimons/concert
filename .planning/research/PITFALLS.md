# Pitfalls Research

**Domain:** Shiny Multi-Tab Gated Workflows
**Researched:** 2026-02-26
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Tab Initialization Timing Race Conditions

**What goes wrong:**
When using `nav_hide()` or `hideTab()` to gate tabs on app startup, tabs are briefly visible before the hide command executes. During this loading time (before the hideTab instruction gets run), users can see and click on tabs that should be hidden, especially if those tabs contain many widgets, uiOutputs, plots, or images that slow down initial page render.

**Why it happens:**
Server-side `nav_hide()` and `hideTab()` commands only execute after the initial UI has been sent to the client and the Shiny session has started. The time gap between DOM rendering and server commands executing creates this visibility window.

**How to avoid:**
1. Use `nav_panel_hidden()` for tabs that should start hidden, then programmatically show them with `nav_show()` when conditions are met
2. For legacy `tabsetPanel()`, use CSS to hide tabs initially: add custom CSS that hides specific tabs by default
3. Use `tabsetPanel(type = "hidden")` with separate UI controls for navigation instead of visible tabs

**Warning signs:**
- Users report clicking on tabs they "shouldn't be able to access"
- Tabs briefly flash during app initialization
- Console shows server code executing after user interactions
- Large tab content causes longer initialization delays

**Phase to address:**
Phase 1 (Foundation/Architecture) — Set up proper tab hiding pattern from the start to avoid refactoring reactivity chains later.

---

### Pitfall 2: Reactive State Flicker During Input Updates

**What goes wrong:**
When switching tabs or changing inputs that affect tab visibility, outputs briefly flicker showing stale/incorrect data because `updateTabsetPanel()`, `updateSelectInput()`, and similar update functions only take effect after all outputs and observers have run. This creates a temporary inconsistent state where you might have "dataset B" displayed with "variable from dataset A".

**Why it happens:**
Shiny's reactive flush cycle processes all outputs and observers before updating client-side inputs. During this window, downstream reactives and outputs read the old input value and render, then immediately re-render when the update completes.

**How to avoid:**
1. **ALWAYS use `freezeReactiveValue()` when programmatically updating inputs:**
   ```r
   observeEvent(input$dataset_switch, {
     freezeReactiveValue(input, "variable_select")
     updateSelectInput(session, "variable_select", choices = new_vars)
   })
   ```
2. Use `req()` to prevent outputs from rendering during transition states
3. Consider using `isolate()` to prevent unnecessary reactive dependencies during updates

**Warning signs:**
- Outputs flash/flicker when changing tabs
- Brief error messages appear then disappear
- Users see "impossible" data combinations for a split second
- Multiple rapid re-renders in browser developer tools

**Phase to address:**
Phase 1 (Foundation/Architecture) — Implement `freezeReactiveValue()` pattern for all programmatic input updates from the start.

---

### Pitfall 3: Infinite Reactive Loops with Gated Navigation

**What goes wrong:**
An observer that controls tab visibility takes a reactive dependency on a value while also modifying that same value, creating an infinite loop. For example, an observer that watches `input$data_ready` and shows a tab, but the tab's content modifies `input$data_ready`, causing the observer to fire again indefinitely.

**Why it happens:**
Shiny's reactive graph automatically creates dependencies when observers read reactive values. Without explicit control, reading and writing the same reactive value creates a feedback loop. This is particularly common in gated workflows where tab visibility depends on state that tabs themselves can modify.

**How to avoid:**
1. Use `isolate()` to read reactive values without taking dependencies:
   ```r
   observeEvent(input$tags_applied, {
     # Read current tab without creating dependency
     current_data <- isolate(data_store$clean)
     nav_show("main_tabs", "run_curation")
   })
   ```
2. Prefer `observeEvent()` over `observe()` for explicit event-driven updates
3. Use `reactiveVal()` or `reactiveValues()` for state management instead of circular input dependencies
4. Separate "trigger" reactives from "state storage" reactives

**Warning signs:**
- App becomes unresponsive or freezes
- Console shows repeated execution of the same observer
- Browser developer tools show rapid WebSocket messages
- CPU usage spikes on server

**Phase to address:**
Phase 1 (Foundation/Architecture) — Design reactive graph with clear data flow direction before implementing gating logic.

---

### Pitfall 4: Lost Reactive State When Switching Tabs

**What goes wrong:**
Reactive values or computed data are lost or reset when users switch between tabs. For example, a user tags columns in the "Tag Columns" tab, switches to "Detection Info" to check something, then returns to find their tags reset or the UI state cleared.

**Why it happens:**
Outputs in non-visible tabs stop executing (Shiny's optimization). If state is stored only in UI outputs (`renderUI`, `renderText`) or temporary reactive expressions instead of persistent `reactiveValues()`, it's lost when the tab becomes invisible. Additionally, using `uiOutput()` to render tab content on-demand can re-initialize state each time.

**How to avoid:**
1. **Store all workflow state in `reactiveValues()` or `reactiveVal()` objects:**
   ```r
   curation_state <- reactiveValues(
     tags_applied = FALSE,
     column_tags = list(),
     curation_results = NULL
   )
   ```
2. Never rely on input values alone for state — copy them to reactive values
3. Use persistent storage patterns (reactiveValues in global scope, not inside observers)
4. For UI-heavy state, prefer static UI with conditional visibility over `renderUI()`

**Warning signs:**
- Users complain about "losing their work" when navigating
- Input values reset unexpectedly
- Tab content re-initializes when revisited
- Progress indicators restart from zero

**Phase to address:**
Phase 1 (Foundation/Architecture) — Design central state management with `reactiveValues()` before building tab-specific logic.

---

### Pitfall 5: Wrong Tab ID References with nav_show/nav_hide

**What goes wrong:**
`nav_show()`, `nav_hide()`, `nav_select()` fail silently or throw cryptic errors because the `id` parameter refers to the wrong element. For `nav_*` functions, the `id` must be the **container's id** (the `navset_*` id), not the individual tab's value. The `target` parameter specifies which tab to affect.

**Why it happens:**
The API is counterintuitive — developers naturally think `nav_show(id = "my_tab")` will show `my_tab`, but it actually needs `nav_show(id = "tab_container", target = "my_tab")`. Legacy Shiny's `showTab()` uses different parameter names (`inputId` vs `id`, `target` vs `select`), causing confusion when migrating to bslib.

**How to avoid:**
1. **Remember: `id` = container, `target` = specific tab:**
   ```r
   # WRONG
   nav_show(id = "curation_tab")

   # CORRECT
   nav_show(id = "main_tabs", target = "curation_tab")
   ```
2. Set container `id` explicitly on `navset_card_tab()` or `page_navbar()`
3. Set `value` parameter on each `nav_panel()` for reliable targeting
4. Test tab manipulation functions interactively before embedding in observers

**Warning signs:**
- `nav_show()` / `nav_hide()` have no effect
- Console errors: "could not find nav container with id..."
- Functions work in some contexts but not others
- Different behavior between `navset_card_tab()` and `navbarPage()`

**Phase to address:**
Phase 1 (Foundation/Architecture) — Document tab structure and ID scheme before implementing gating logic.

---

### Pitfall 6: Observer Execution on Hidden Tab Content

**What goes wrong:**
Observers and reactive expressions in hidden tabs continue executing even when tabs are not visible, wasting computational resources and potentially causing side effects (API calls, database writes, file operations) when users aren't viewing the results.

**Why it happens:**
Shiny's tab visibility optimization only applies to **outputs** (`renderPlot`, `renderTable`, etc.). Observers (`observe()`, `observeEvent()`) and non-output reactives (`reactive()`, `eventReactive()`) run regardless of tab visibility unless explicitly controlled.

**How to avoid:**
1. Use `req(input$main_tabs == "target_tab")` at the start of observers that should only run when tab is active
2. Scope expensive operations inside outputs when possible (they auto-suspend)
3. Use `conditionalPanel()` for UI that triggers observers
4. Consider `bindEvent()` pattern (Shiny 1.6+) to control when reactives execute:
   ```r
   expensive_data <- reactive({
     req(input$main_tabs == "data_tab")
     # expensive computation
   }) %>% bindEvent(input$run_button)
   ```

**Warning signs:**
- API rate limits hit even when users aren't on API-dependent tabs
- Database queries execute continuously in background
- High server CPU usage when users are idle on other tabs
- Logs show operations for tabs user never visited

**Phase to address:**
Phase 2 (Implementation) — Add tab-aware guards to observers during initial development.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `conditionalPanel()` instead of `nav_hide()`/`nav_show()` | Easier to implement, no server-side logic | Tabs always visible in DOM, users can inspect/hack via browser console, no programmatic control | Never for security-sensitive gating; acceptable for simple UI convenience |
| Storing state in `input$` values only | Simpler mental model, fewer reactive objects | State lost on tab switches, no programmatic state manipulation, hard to debug | Never for multi-tab workflows; acceptable for single-screen apps |
| Using `updateTabsetPanel(selected = ...)` without `freezeReactiveValue()` | Fewer lines of code, faster initial development | Output flicker, race conditions, poor UX | Never; always use `freezeReactiveValue()` |
| Relying on `renderUI()` for entire tab content | Dynamic, flexible UI generation | State resets on re-render, timing issues with bslib initialization, poor performance | Use sparingly for truly dynamic content; prefer static UI with `conditionalPanel` or visibility toggles |
| Using `observe()` instead of `observeEvent()` | Less verbose, auto-detects dependencies | Hard to reason about, prone to infinite loops, executes on ANY dependency change | Never for gating logic; acceptable only for simple logging/debugging |
| Sharing `reactiveValues()` across modules without clear ownership | Easy state sharing between components | Mutation from many sources, hard to debug, unclear data flow | Acceptable for MVP; refactor to explicit state management pattern before production |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **bslib + DT (DataTables)** | Putting `DTOutput()` inside `renderUI()` on gated tabs | Use static `DTOutput()` with `req()` in `renderDT()` to prevent rendering until tab is accessible |
| **bslib + shinyjs** | Mixing `shinyjs::hide()` with `nav_hide()` | Use only `nav_hide()` for nav panels; reserve `shinyjs` for non-nav elements |
| **bslib + conditionalPanel** | Using JavaScript conditions with reactive values | Use `output.` prefix for server-side conditionals: `condition = "output.tags_applied"` |
| **navset_card_tab + sidebar** | Expecting sidebar to change per-tab | Use `layout()` with tab-specific sidebars, or `conditionalPanel()` inside global sidebar |
| **nav_panel + uiOutput** | Wrapping entire tab in `uiOutput()` | Use static structure with targeted `uiOutput()` for dynamic pieces only |
| **page_navbar + modules** | Passing wrong namespace context to nav_* functions | Call `nav_show(session, ...)` with module session object, not parent session |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| **Rendering all tabs on load** | Slow initial page load, high memory usage | Use `nav_panel_hidden()` for tabs not needed immediately; lazy-load data when tab accessed | >3 tabs with large datasets or complex visualizations |
| **Observers firing for all tabs** | High CPU usage when user idles on one tab | Add `req(input$main_tabs == "target")` guards in observers | >5 active observers across multiple tabs |
| **Re-executing detection on tab switches** | Noticeable delay when switching tabs | Cache results in `reactiveValues()`, not in tab-scoped reactives | Data processing >500ms |
| **Rendering entire dataset in hidden tabs** | Memory usage grows as user visits tabs | Use `DT::renderDataTable()` instead of `renderTable()` for large data; add `req()` guards | Datasets >10k rows across multiple tabs |
| **Multiple reactive chains for same computation** | Redundant API calls or data processing | Create shared `reactive()` at app level, consumed by multiple tabs | >2 tabs using same data source |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Using `conditionalPanel()` alone for access control | Users can bypass via browser console; sensitive data sent to client even when hidden | Use server-side `nav_hide()` + `req()` guards; never rely on client-side hiding for security |
| Storing sensitive state in input values | Input values visible in browser dev tools and WebSocket traffic | Use `reactiveValues()` on server; never store credentials or PII in `input$` |
| Not validating state before showing tabs | Users can manipulate URL or session state to access gated tabs prematurely | Always check prerequisites with `req()` in observers AND in render functions |
| Rendering sensitive data in hidden tabs | Data sent to client even if tab hidden; accessible via DOM inspection | Only render sensitive content after `req(input$main_tabs == "target")` check |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| **No feedback when gate conditions unmet** | Users click disabled tabs, nothing happens, confusion | Show locked icon + tooltip explaining requirements |
| **Losing work when tab switching** | Frustration, re-entering data, abandonment | Store all form state in `reactiveValues()`, persist across navigation |
| **No indication of workflow progress** | Users unsure which tab to visit next | Add visual indicators (checkmarks, progress bar) to show completed steps |
| **Tabs appear then immediately hide** | Jarring flash, feels broken | Use `nav_panel_hidden()` + `nav_show()` pattern instead of late `nav_hide()` |
| **No validation feedback before gating** | Users try to proceed, hit silent gate, confusion | Show validation errors inline BEFORE hiding "next step" button/tab |
| **Gated tabs visible but disabled** | Users click, nothing happens, unclear why | Use `nav_hide()` instead of `shinyjs::disable()` to remove from view entirely |

---

## "Looks Done But Isn't" Checklist

- [ ] **Tab gating:** Often missing edge case handling — verify state validation on EVERY tab access, not just button clicks
- [ ] **State persistence:** Often missing reactiveValues initialization — verify state survives tab switches, app reload (if needed)
- [ ] **Input freeze:** Often missing `freezeReactiveValue()` on updates — verify no output flicker when changing tabs or updating inputs
- [ ] **Observer guards:** Often missing tab-awareness — verify observers don't fire for hidden tabs unless intended
- [ ] **Error handling:** Often missing `req()` / `validate()` on gated content — verify graceful failure when prerequisites unmet
- [ ] **Module namespacing:** Often missing session scoping — verify `nav_*` functions use correct session in modules
- [ ] **Tab IDs:** Often mixing `id` vs `value` — verify container `id` and panel `value` set explicitly and documented
- [ ] **Progress indicators:** Often reset on tab switch — verify progress stored in `reactiveValues()`, not UI state

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| **Initialization race condition** | LOW | Wrap startup `nav_hide()` in `shinyjs::delay()`, or refactor to use `nav_panel_hidden()` |
| **Reactive flicker** | LOW | Add `freezeReactiveValue()` calls before all `update*()` functions |
| **Infinite loop** | LOW | Add `isolate()` to one side of the circular dependency; use browser's "stop script" to regain control |
| **Lost state** | MEDIUM | Refactor to use `reactiveValues()` for all state; may require re-testing all tab transitions |
| **Wrong tab IDs** | LOW | Check documentation, fix `id` vs `target` parameters; test interactively before re-deploying |
| **Observer waste** | MEDIUM | Add `req(input$tabs == "x")` guards to each observer; benchmark to verify improvement |
| **Security bypass** | HIGH | Refactor all access control to server-side; audit all `conditionalPanel()` usage; may require architecture changes |
| **renderUI() timing issues** | MEDIUM to HIGH | Replace `renderUI()` with static UI + `conditionalPanel()` or visibility toggles; may affect layout significantly |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Tab initialization race | Phase 1: Foundation | Test app startup with network throttling; no tabs should flash |
| Reactive flicker | Phase 1: Foundation | Verify `freezeReactiveValue()` before all `update*()` calls; no visual flicker on tab change |
| Infinite loops | Phase 1: Foundation | Code review all observers for read+write of same reactive; test with `options(shiny.reactlog=TRUE)` |
| Lost state | Phase 1: Foundation | Switch between all tab combinations; verify state persists (automated tests recommended) |
| Wrong tab IDs | Phase 1: Foundation | Test all `nav_*()` calls interactively; document tab ID structure |
| Observer waste | Phase 2: Implementation | Profile app with `profvis`; verify observers only fire when tab active |
| Security bypass | Phase 1: Foundation + Phase 3: Testing | Attempt to bypass gating via browser console; verify server-side guards prevent access |
| UX feedback gaps | Phase 2: Implementation + Phase 3: Polish | User testing; verify all gated states have clear feedback |

---

## Sources

### Official Documentation (HIGH confidence)
- [bslib Navigation Containers](https://rstudio.github.io/bslib/reference/navset.html)
- [bslib Dynamic Nav Updates](https://rstudio.github.io/bslib/reference/nav_select.html)
- [Shiny hideTab/showTab](https://shiny.posit.co/r/reference/shiny/latest/showtab.html)
- [Shiny freezeReactiveValue](https://shiny.posit.co/r/reference/shiny/1.7.0/freezereactivevalue.html)
- [Context7: bslib Tab Control](https://context7.com/rstudio/bslib/llms.txt)

### Community Resources (MEDIUM confidence)
- [Mastering Shiny: Reactive Building Blocks](https://mastering-shiny.org/reactivity-objects.html)
- [Mastering Shiny: Dynamic UI](https://mastering-shiny.org/action-dynamic.html)
- [Engineering Production-Grade Shiny Apps: Common Caveats](https://engineering-shiny.org/common-app-caveats.html)
- [Dean Attali: Advanced Shiny Tips](https://deanattali.com/blog/advanced-shiny-tips/)
- [shinyjs Issue #43: Tab Hiding Timing](https://github.com/daattali/shinyjs/issues/43)

### GitHub Issues & Discussions (MEDIUM confidence)
- [Shiny #2865: Request to freeze observers on input updates](https://github.com/rstudio/shiny/issues/2865)
- [Shiny #3068: updateTabsetPanel fails silently with multiple selected values](https://github.com/rstudio/shiny/issues/3068)
- [bslib #585: Sidebar navigation patterns](https://github.com/rstudio/bslib/issues/585)
- [bslib #938: Conditional card discussion](https://github.com/rstudio/bslib/discussions/938)

### Technical Articles (MEDIUM confidence)
- [ArData: Share Reactive Among Modules](https://www.ardata.fr/en/post/2019/04/26/share-reactive-among-shiny-modules/)
- [ThinkR: Communication Between Modules](https://rtask.thinkr.fr/communication-between-modules-and-its-whims/)
- [Datanovia: Shiny Reactive Values Guide](https://www.datanovia.com/learn/tools/shiny-apps/server-logic/reactive-values.html)

---

*Pitfalls research for: Shiny tab refactoring and gated workflows for ChemReg chemical inventory app*
*Researched: 2026-02-26*
