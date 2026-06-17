---
# concert-ieha
title: Handle hardness-dependent dissolved metals criteria
status: todo
type: task
priority: high
tags:
    - criteria
    - github:issue
    - aquatic-life
    - dissolved-metals
    - hardness
created_at: 2026-05-26T20:20:25Z
updated_at: 2026-06-17T00:54:47Z
---


## Problem

Freshwater aquatic life criteria for dissolved metals can be hardness dependent. CONCERT needs to handle these values without silently treating them as static benchmark numbers.

The immediate risk is that Appendix A conversion factors for dissolved metals and Appendix B hardness-dependent freshwater dissolved-metals criteria parameters are parsed/crosswalked incorrectly, causing criteria maximum concentration (CMC/acute) and criterion continuous concentration (CCC/chronic) calculations to use the wrong basis or to fail without clear user guidance.

## Source concepts to understand

- Appendix A: conversion factors for dissolved metals.
  - Used to convert total recoverable criteria to dissolved criteria where appropriate.
  - May differ by metal and by acute/chronic endpoint.
- Appendix B: parameters for calculating freshwater dissolved metals criteria that are hardness dependent.
  - Criteria may need to be calculated from hardness rather than ingested as a single fixed numeric value.
  - CMC and CCC should remain distinct calculation targets.

## Implementation questions

1. How should CONCERT detect and route hardness-dependent dissolved metals criteria?
2. Should the pre/post-flight layer detect when a hardness field already exists in the uploaded data file?
3. If hardness is absent, should CONCERT warn/remind the user that the benchmark cannot be defensibly calculated without hardness?
4. Should CONCERT offer a workflow to fill hardness using an average hardness for a geographic area, then move the record into the criteria-calculation path?
5. How should Appendix A conversion factors and Appendix B hardness parameters be represented so they are auditable and not collapsed into static benchmark tables?

## Proposed behavior options

### Option 1: detect hardness in file

During post-flight/preflight checks, detect whether the incoming data includes a usable hardness column/value for the relevant sample/location/time grain.

If present:
- validate units and numeric range;
- normalize to the expected calculation unit, likely mg/L as CaCO3 unless source requires otherwise;
- route hardness-dependent dissolved metals to calculation rather than static lookup;
- preserve CMC and CCC as separate calculated outputs.

### Option 2: prompt/remind for average area hardness

If hardness is missing:
- warn that dissolved-metals freshwater criteria are hardness dependent;
- offer/remind user to provide an average hardness value for the relevant area if appropriate for screening;
- clearly label any area-average hardness calculation as estimated/screening-grade;
- then route to the calculation workflow.

### Option 3: pull hardness-supporting data from Freshwater Explorer

If user/sample hardness is absent but spatial context is available:
- investigate pulling supporting data from Freshwater Explorer via the alkalinity layer;
- assess whether alkalinity can support a defensible area-level hardness estimate or related screening proxy;
- require the output to identify this as a derived/spatially-sourced support value, not measured sample hardness;
- preserve provenance: Freshwater Explorer layer, query geometry/area, date/version if available, and transformation/assumption used to support hardness criteria calculation.

## Acceptance criteria

- Identify which CONCERT benchmark tables/functions currently ingest aquatic life dissolved metals criteria.
- Document how Appendix A conversion factors are represented and whether they are endpoint-specific.
- Document how Appendix B hardness parameters map to CMC and CCC calculations.
- Add or design a post-flight check that detects hardness columns/values in uploaded data.
- Add or design a warning path when hardness-dependent metals criteria are requested but hardness is absent.
- Evaluate Freshwater Explorer alkalinity-layer access as a possible spatial support source for area-level hardness estimation/proxy workflows.
- Ensure CMC and CCC are preserved as separate fields/calculation outputs.
- Add tests/fixtures for at least one hardness-dependent dissolved metal with both CMC and CCC paths.
- Do not silently substitute a default hardness value. User-provided or explicitly configured area-average hardness must be traceable in output metadata.

## Notes

This is related to aquatic life criteria curation and water-quality benchmark crosswalking. The important thing is to avoid treating hardness-dependent dissolved metals as ordinary fixed thresholds.



## GitHub

- GitHub #36: https://github.com/seanthimons/concert/issues/36
