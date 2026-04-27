# Tag Dispatch Helpers
# Phase 33: Extended Column Tagging
#
# Single source of truth for tag type classification (D-03)

#' Classify Tags into Categories
#'
#' Partitions a named list of column tags into chemical, numeric, and metadata
#' categories. This is the single source of truth for tag type membership.
#'
#' @param tags Named list where names are column names and values are tag types
#'   (e.g., list(col1 = "Name", col2 = "Result"))
#'
#' @return Named list with four elements:
#'   \describe{
#'     \item{chemical_tags}{Named list of chemical-related tags (Name, CASRN, Other)}
#'     \item{numeric_tags}{Named list of numeric/measurement tags (Result, Unit, Qualifier, Duration, DurationUnit)}
#'     \item{metadata_tags}{Named list of study metadata tags (Species, ExposureRoute)}
#'     \item{study_type_tags}{Named list of study/contextual tags (StudyDate)}
#'   }
#'
#' @details
#' Tag type membership per design decisions:
#' - D-06: Chemical types = Name, CASRN, Other
#' - D-07: Numeric types = Result, Unit, Qualifier, Duration, DurationUnit
#' - D-08: Metadata types = Species, ExposureRoute
#'
#' @examples
#' tags <- list(col1 = "Name", col2 = "Result", col3 = "Species")
#' result <- classify_tags(tags)
#' result$chemical_tags  # list(col1 = "Name")
#' result$numeric_tags   # list(col2 = "Result")
#' result$metadata_tags  # list(col3 = "Species")
#'
#' @export
classify_tags <- function(tags) {
  # Define type membership vectors (single source of truth per D-03)
  chemical_types <- c("Name", "CASRN", "Other")
  numeric_types <- c("Result", "Unit", "Qualifier", "Duration", "DurationUnit")
  metadata_types <- c("Species", "ExposureRoute")
  study_types <- c("StudyDate")

  # Handle empty input

  if (length(tags) == 0) {
    return(list(
      chemical_tags = list(),
      numeric_tags = list(),
      metadata_tags = list(),
      study_type_tags = list()
    ))
  }

  # Partition tags by type
  tag_values <- unlist(tags, use.names = FALSE)
  tag_names <- names(tags)

  chemical_idx <- which(tag_values %in% chemical_types)
  numeric_idx <- which(tag_values %in% numeric_types)
  metadata_idx <- which(tag_values %in% metadata_types)
  study_type_idx <- which(tag_values %in% study_types)

  # Build output lists preserving names
  chemical_tags <- if (length(chemical_idx) > 0) {
    stats::setNames(as.list(tag_values[chemical_idx]), tag_names[chemical_idx])
  } else {
    list()
  }

  numeric_tags <- if (length(numeric_idx) > 0) {
    stats::setNames(as.list(tag_values[numeric_idx]), tag_names[numeric_idx])
  } else {
    list()
  }

  metadata_tags <- if (length(metadata_idx) > 0) {
    stats::setNames(as.list(tag_values[metadata_idx]), tag_names[metadata_idx])
  } else {
    list()
  }

  study_type_tags <- if (length(study_type_idx) > 0) {
    stats::setNames(as.list(tag_values[study_type_idx]), tag_names[study_type_idx])
  } else {
    list()
  }

  list(
    chemical_tags = chemical_tags,
    numeric_tags = numeric_tags,
    metadata_tags = metadata_tags,
    study_type_tags = study_type_tags
  )
}

#' Validate Tag Pairing Requirements
#'
#' Checks that required tag pairings are satisfied. Currently validates that
#' Result and Unit tags appear together (per D-12/D-13).
#'
#' @param tags Named list where names are column names and values are tag types
#'
#' @return Character warning message if pairing violated, NULL otherwise.
#'   Note: This is a warning, not a blocker (per D-14/D-15).
#'
#' @details
#' Per D-12 and D-13, Result and Unit should be paired for meaningful
#' harmonization. This function returns a warning message if:
#' - Result is tagged without Unit

#' - Unit is tagged without Result
#'
#' The warning is informational and does not block tag application.
#'
#' @examples
#' # Unpaired Result - returns warning
#' validate_tag_pairing(list(col1 = "Result"))
#'
#' # Paired Result/Unit - returns NULL
#' validate_tag_pairing(list(col1 = "Result", col2 = "Unit"))
#'
#' # Non-numeric tags - returns NULL
#' validate_tag_pairing(list(col1 = "Name"))
#'
#' @export
validate_tag_pairing <- function(tags) {
  if (length(tags) == 0) {
    return(NULL)
  }

  tag_values <- unlist(tags, use.names = FALSE)

  has_result <- "Result" %in% tag_values
  has_unit <- "Unit" %in% tag_values

  if (has_result && !has_unit) {
    return("Result tagged without Unit - harmonization may be incomplete")
  }

  if (has_unit && !has_result) {
    return("Unit tagged without Result - harmonization may be incomplete")
  }

  NULL
}

#' Detect Changes Between Tag Sets
#'
#' Compares two tag sets and returns TRUE if they differ. Used for cascade
#' reset logic to determine if downstream state should be invalidated.
#'
#' @param old_tags Named list of previous tags (can be NULL for first apply)
#' @param new_tags Named list of new tags
#'
#' @return Logical: TRUE if tags changed, FALSE if identical
#'
#' @details
#' Per D-10/D-11, this enables independent cascade resets. The function
#' handles:
#' - NULL old_tags (first application, always returns TRUE)
#' - Different number of tags
#' - Different column names
#' - Different tag values
#'
#' @examples
#' # First apply (NULL -> new) - returns TRUE
#' detect_tag_changes(NULL, list(col1 = "Name"))
#'
#' # Same tags - returns FALSE
#' detect_tag_changes(list(col1 = "Name"), list(col1 = "Name"))
#'
#' # Changed value - returns TRUE
#' detect_tag_changes(list(col1 = "Name"), list(col1 = "CASRN"))
#'
#' Check for Required Chemical Tags
#'
#' Validates that both Name and CASRN tags are present, which are required
#' for the cleaning pipeline to operate.
#'
#' @param chemical_tags Named list of chemical tags (output from classify_tags)
#'
#' @return Logical: TRUE if both Name and CASRN are present, FALSE otherwise
#'
#' @details
#' The cleaning pipeline requires both a chemical name column and a CASRN column
#' to perform deduplication and enrichment. This function checks that at least
#' one column is tagged as "Name" and at least one as "CASRN".
#'
#' @examples
#' # Both present - returns TRUE
#' has_required_chemical_tags(list(col1 = "Name", col2 = "CASRN"))
#'
#' # Missing CASRN - returns FALSE
#' has_required_chemical_tags(list(col1 = "Name"))
#'
#' # Empty - returns FALSE
#' has_required_chemical_tags(list())
#'
#' @export
has_required_chemical_tags <- function(chemical_tags) {
  if (length(chemical_tags) == 0) {
    return(FALSE)
  }

  tag_values <- unlist(chemical_tags, use.names = FALSE)
  has_name <- "Name" %in% tag_values
  has_casrn <- "CASRN" %in% tag_values

  has_name && has_casrn
}

#' @export
detect_tag_changes <- function(old_tags, new_tags) {
  # NULL old_tags means first application
  if (is.null(old_tags)) {
    # Only return TRUE if there are actually new tags
    return(length(new_tags) > 0)
  }

  # Different lengths means change
  if (length(old_tags) != length(new_tags)) {
    return(TRUE)
  }

  # Both empty means no change
  if (length(old_tags) == 0 && length(new_tags) == 0) {
    return(FALSE)
  }

  # Check names match
  old_names <- sort(names(old_tags))
  new_names <- sort(names(new_tags))

  if (!identical(old_names, new_names)) {
    return(TRUE)
  }

  # Check values match (compare in same order)
  for (nm in old_names) {
    if (!identical(old_tags[[nm]], new_tags[[nm]])) {
      return(TRUE)
    }
  }

  FALSE
}
