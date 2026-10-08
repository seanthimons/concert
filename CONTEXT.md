# CONCERT

CONCERT turns environmental chemistry datasets into curated,
reproducible outputs.

## Language

**Portable replay section**: An applied, durable input object that
[`curate_headless()`](https://seanthimons.github.io/concert/reference/curate_headless.md)
can consume without Shiny session state. *Avoid*: checkpoint payload,
workspace block

**Applied state**: Configuration committed by its owning workflow and
reflected in the current accepted results; draft, empty, and stale
configuration is excluded. *Avoid*: working state, current form values
