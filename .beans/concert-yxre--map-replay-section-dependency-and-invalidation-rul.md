---
# concert-yxre
title: Map replay-section dependency and invalidation rules
status: in-progress
type: task
priority: normal
tags:
    - wayfinder:grilling
created_at: 2026-08-06T17:22:30Z
updated_at: 2026-08-07T18:32:00Z
parent: concert-urn9
---

## Question

For each candidate portable section, which later calculations or exports depend on it, whether editing it requires downstream reruns, and what ordering or warnings must the generated workspace communicate?

Start from the established fact that Dataset Context currently affects export metadata only and does not invalidate chemical cleaning, curation, harmonization, or review results.
