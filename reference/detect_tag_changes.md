# Detect Changes Between Tag Sets

Compares two tag sets and returns TRUE if they differ. Used for cascade
reset logic to determine if downstream state should be invalidated.

## Usage

``` r
detect_tag_changes(old_tags, new_tags)
```

## Arguments

- old_tags:

  Named list of previous tags (can be NULL for first apply)

- new_tags:

  Named list of new tags

## Value

Logical: TRUE if tags changed, FALSE if identical

## Details

Per D-10/D-11, this enables independent cascade resets. The function
handles:

- NULL old_tags (first application, always returns TRUE)

- Different number of tags

- Different column names

- Different tag values

## Examples

``` r
# First apply (NULL -> new) - returns TRUE
detect_tag_changes(NULL, list(col1 = "Name"))
#> [1] TRUE

# Same tags - returns FALSE
detect_tag_changes(list(col1 = "Name"), list(col1 = "Name"))
#> [1] FALSE

# Changed value - returns TRUE
detect_tag_changes(list(col1 = "Name"), list(col1 = "CASRN"))
#> [1] TRUE
```
