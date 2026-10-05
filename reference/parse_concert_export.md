# Parse CONCERT Export

Detects if an Excel file is a valid CONCERT export and extracts all
available export sheets. Older exports without Session State still parse
for reference-list and column-tag import.

## Usage

``` r
parse_concert_export(file_path)
```

## Arguments

- file_path:

  Path to Excel file

## Value

List with parsed sheet data frames and has_full_session_state, or NULL
if not a valid CONCERT export
