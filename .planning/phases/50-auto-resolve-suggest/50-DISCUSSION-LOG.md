# Phase 50: Auto-Resolve & Suggest - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 50-auto-resolve-suggest
**Areas discussed:** Resolution thresholds, Suggestion UX, Auto-resolution tracking, Override flow

---

## Resolution Thresholds

### Auto-resolve threshold

| Option | Description | Selected |
|--------|-------------|----------|
| >= 0.95 (Recommended) | Very high bar -- only near-exact synonym matches auto-resolve. Minimizes false positives. | :heavy_check_mark: |
| >= 0.90 | Slightly more permissive -- catches more cases but increases risk of incorrect auto-resolution. | |
| You decide | Let Claude pick based on testing with real scoring data. | |

**User's choice:** >= 0.95
**Notes:** None

### Suggestion threshold

| Option | Description | Selected |
|--------|-------------|----------|
| >= 0.70 (Recommended) | Moderate confidence -- suggests when there's a reasonable JW match but not confident enough to auto-resolve. | :heavy_check_mark: |
| >= 0.60 | More permissive -- surfaces suggestions for weaker matches. More helpful but noisier. | |
| >= 0.80 | Higher bar -- only suggests when fairly confident. Fewer suggestions, higher quality. | |
| You decide | Let Claude pick based on score distribution in real data. | |

**User's choice:** >= 0.70
**Notes:** None

### Score gap requirement

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, require gap >= 0.15 (Recommended) | Auto-resolve only when the best candidate clearly beats the runner-up. | :heavy_check_mark: |
| No gap required | Auto-resolve based on absolute score alone. Simpler logic. | |
| You decide | Let Claude decide the gap threshold. | |

**User's choice:** Yes, require gap >= 0.15
**Notes:** None

---

## Suggestion UX

### Suggestion indicator location

| Option | Description | Selected |
|--------|-------------|----------|
| Inline badge in table (Recommended) | Small colored badge in the table row. | |
| Inside comparison modal only | Suggestion only visible when user clicks Compare. | |
| Both table and modal | Badge in table + highlighted suggestion in modal. | |

**User's choice:** Custom -- Table shows a status chip (filterable like ERROR/DISAGREE), suggestion detail is inside comparison modal.
**Notes:** User specifically requested a filterable status chip pattern, not just a badge. Suggestion acceptance happens in the modal.

### One-click accept

| Option | Description | Selected |
|--------|-------------|----------|
| Accept button in table row (Recommended) | Small accept button next to suggestion badge. | |
| Accept button in modal | User opens modal, sees highlighted candidate, clicks accept. | :heavy_check_mark: |
| You decide | Let Claude pick. | |

**User's choice:** Accept button in modal
**Notes:** User preferred modal-based acceptance to keep the table clean.

### Status chip labels

| Option | Description | Selected |
|--------|-------------|----------|
| SUGGESTED (Recommended) | Clear and distinct from DISAGREE. Filterable. | :heavy_check_mark: |
| MATCH? | Shorter, implies uncertainty. | |
| You decide | Let Claude pick. | |

**User's choice:** SUGGESTED
**Notes:** None

### Auto-resolved chip label

| Option | Description | Selected |
|--------|-------------|----------|
| AUTO-RESOLVED (Recommended) | Explicit label distinguishing from manual resolution. Filterable. | :heavy_check_mark: |
| RESOLVED | Simpler but doesn't distinguish auto from manual. | |
| You decide | Let Claude pick. | |

**User's choice:** AUTO-RESOLVED
**Notes:** None

### Bulk accept suggestions

**User-initiated discussion:** User asked whether bulk accept should exist, similar to the priority chain.

| Option | Description | Selected |
|--------|-------------|----------|
| All SUGGESTED rows (Recommended) | Accept every SUGGESTED row. Threshold decision already made at classification time. | :heavy_check_mark: |
| Only above a higher cutoff | More conservative, adds another threshold. | |
| You decide | Let Claude pick. | |

**User's choice:** All SUGGESTED rows
**Notes:** User raised this idea proactively. Natural fit following apply_priority_chain() pattern.

---

## Auto-resolution Tracking

### Audit trail mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| New columns on resolution_state (Recommended) | .resolution_method and .resolution_reason columns. Follows .pinned/.manual_entry pattern. | :heavy_check_mark: |
| Separate audit tibble | Detailed event log separate from main data frame. | |
| You decide | Let Claude pick. | |

**User's choice:** New columns on resolution_state
**Notes:** None

### Export inclusion

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, as columns (Recommended) | resolution_method and resolution_reason in exported data sheet. | :heavy_check_mark: |
| Yes, as a separate sheet | New 'Resolution Audit' sheet. | |
| You decide | Let Claude pick. | |

**User's choice:** Yes, as columns
**Notes:** None

---

## Override Flow

### Override auto-resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Open modal, pick different candidate (Recommended) | Compare button opens modal with auto-resolved candidate highlighted, user picks different one. | :heavy_check_mark: |
| Revert to DISAGREE first | Two-step: revert then resolve. | |
| You decide | Let Claude pick. | |

**User's choice:** Open modal, pick different candidate
**Notes:** None

### Reject suggestion

| Option | Description | Selected |
|--------|-------------|----------|
| Stays SUGGESTED until resolved (Recommended) | Row keeps SUGGESTED status. User must manually resolve or leave unresolved. | :heavy_check_mark: |
| Reverts to DISAGREE | Loses information that a suggestion existed. | |
| You decide | Let Claude pick. | |

**User's choice:** Stays SUGGESTED until resolved
**Notes:** None

---

## Claude's Discretion

- Chip colors for AUTO-RESOLVED and SUGGESTED
- "Accept All Suggestions" button placement
- Internal function naming and file placement
- Whether auto-resolution runs as part of compute_similarity_scores() or separately
- Prototype script structure and test case selection

## Deferred Ideas

None -- discussion stayed within phase scope.
