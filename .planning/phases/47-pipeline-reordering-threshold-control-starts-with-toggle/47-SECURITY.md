---
phase: 47
slug: pipeline-reordering-threshold-control-starts-with-toggle
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-07
---

# Phase 47 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| User input -> pipeline params | wqx_threshold (numeric 0.50-1.00) and starts_with (boolean) enter from UI slider/checkbox | Numeric + boolean, low sensitivity |
| Browser -> Shiny server | Slider/numeric/checkbox values cross from client to server | Numeric + boolean, low sensitivity |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-47-01 | Tampering | wqx_threshold value | accept | Server-side slider enforces min=0.50, max=1.00; even out-of-range values only affect match sensitivity, no injection surface. match_wqx() uses it in a numeric comparison only. | closed |
| T-47-02 | Denial of Service | starts_with=TRUE with large name list | accept | Pre-existing behavior unchanged; toggle merely gates existing functionality. API rate limits already in place for CompTox. | closed |
| T-47-03 | Tampering | wqx_threshold slider input | accept | Server-side Shiny slider enforces min/max bounds (0.50-1.00). Even a crafted value outside bounds would only affect match sensitivity — no code injection or data corruption path. The numeric input has an additional bounds guard in the observeEvent handler. | closed |
| T-47-04 | Information Disclosure | Notification text | accept | Notification shows only aggregate counts (n_exact, n_wqx, etc.), no PII or sensitive chemical identity data. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-47-01 | T-47-01 | Threshold is used only in numeric similarity comparison within match_wqx(); no injection or escalation path. Out-of-range values degrade match quality but cause no harm. | Plan author | 2026-05-06 |
| AR-47-02 | T-47-02 | Toggle gates pre-existing starts-with behavior; no new API surface or load amplification. CompTox rate limits remain enforced. | Plan author | 2026-05-06 |
| AR-47-03 | T-47-03 | Shiny slider widget enforces bounds server-side. Numeric sync observer includes explicit bounds guard (val >= 0.50 && val <= 1.00). No code execution path from this input. | Plan author | 2026-05-06 |
| AR-47-04 | T-47-04 | Notification displays only aggregate integer counts per search tier. No chemical names, CAS numbers, or user-identifiable data exposed. | Plan author | 2026-05-06 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-07 | 4 | 4 | 0 | gsd-secure-phase |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-07
