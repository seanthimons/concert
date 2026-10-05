# Classify Tags into Categories

Partitions a named list of column tags into chemical, numeric, and
metadata categories. This is the single source of truth for tag type
membership.

## Usage

``` r
classify_tags(tags)
```

## Arguments

- tags:

  Named list where names are column names and values are tag types
  (e.g., list(col1 = "Name", col2 = "Result"))

## Value

Named list with four elements:

- chemical_tags:

  Named list of chemical-related tags (Name, CASRN, Other)

- numeric_tags:

  Named list of numeric/measurement tags (Result, Numeric, Unit,
  Qualifier, ReportingLimit, Uncertainty, UncertaintyCoverage, Duration,
  DurationUnit)

- metadata_tags:

  Named list of study metadata tags (Species, ExposureRoute)

- study_type_tags:

  Named list of study/contextual tags (StudyDate)

## Details

Tag type membership per design decisions:

- D-06: Chemical types = Name, CASRN, Other

- D-07: Numeric types = Result, Numeric, Unit, Qualifier,
  ReportingLimit, Uncertainty, UncertaintyCoverage, Duration,
  DurationUnit

- D-08: Metadata types = Species, ExposureRoute

## Examples

``` r
tags <- list(col1 = "Name", col2 = "Result", col3 = "Species")
result <- classify_tags(tags)
result$chemical_tags  # list(col1 = "Name")
#> $col1
#> [1] "Name"
#> 
result$numeric_tags   # list(col2 = "Result")
#> $col2
#> [1] "Result"
#> 
result$metadata_tags  # list(col3 = "Species")
#> $col3
#> [1] "Species"
#> 
```
