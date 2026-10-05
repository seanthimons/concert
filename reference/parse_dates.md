# Parse mixed-format date strings into structured ISO-8601 output

Converts a character vector of date strings in mixed formats into a
standardised 5-column tibble. Handles ISO, MDY, DMY, SAS (dBY), YYYYMMDD
compact, year-only, and month-year formats via
lubridate::parse_date_time() with train=FALSE (required for
heterogeneous columns).

## Usage

``` r
parse_dates(raw_dates, orig_row_id = seq_along(raw_dates))
```

## Arguments

- raw_dates:

  Character vector of date strings to parse.

- orig_row_id:

  Integer vector of row IDs corresponding to each element of raw_dates.
  Defaults to seq_along(raw_dates) for direct column processing.

## Value

A tibble with 5 columns:

- orig_row_id:

  Integer row position for join-by-position merge.

- raw_date:

  Original input string, preserved for audit.

- parsed_date:

  ISO-8601 "YYYY-MM-DD" string, or NA_character\_ if unparseable.

- date_year:

  Integer year extracted from parsed_date, or NA_integer\_.

- date_flag:

  One of: "" (clean), "partial", "inferred_format", "ambiguous",
  "unparseable".
