# zzz.R
# Package initialization: register domain-specific units on load
#
# The `units` package (udunits2 engine) lacks chemistry-specific units.
# We register them here so they're available immediately after library(chemreg).
#
# NOTE: Per D-03, `units` is a hard Imports dependency - no requireNamespace()
# guard needed. If units is missing, package installation fails (which is correct).

.onLoad <- function(libname, pkgname) {
  register_chemreg_units()
}

#' Register chemistry and environmental domain units
#'
#' Called automatically on package load. Registers units not in udunits2:
#' - Molarity: M, mM, uM, nM, pM (based on mol/L)
#' - Turbidity: NTU, FTU, JTU (dimensionless, not interconvertible)
#' - Microbial: CFU, MPN (dimensionless counts)
#'
#' @return NULL (called for side effects)
#' @keywords internal
register_chemreg_units <- function() {
  # No requireNamespace() guard needed - units is a hard Imports dependency (D-03).
  # If units is missing, the package won't load at all (correct behavior).

  # Molarity (based on mol/L - udunits2 has mol and L)
  # M = 1 mol/L, mM = 0.001 mol/L, etc.
  tryCatch({
    units::install_unit("M", "mol/L", "molar")
    units::install_unit("mM", "mmol/L", "millimolar")
    units::install_unit("uM", "umol/L", "micromolar")
    units::install_unit("nM", "nmol/L", "nanomolar")
    units::install_unit("pM", "pmol/L", "picomolar")
  }, error = function(e) {
    # Units may already be registered (e.g., package reloaded in same session)
    # This is not an error condition
  })

  # Turbidity (dimensionless - not interconvertible with each other)
  tryCatch({
    units::install_unit("NTU", name = "nephelometric turbidity unit")
    units::install_unit("FTU", name = "formazin turbidity unit")
    units::install_unit("JTU", name = "jackson turbidity unit")
  }, error = function(e) {
    # Already registered or not critical
  })

  # Microbial counts (dimensionless)
  tryCatch({
    units::install_unit("CFU", name = "colony forming unit")
    units::install_unit("MPN", name = "most probable number")
  }, error = function(e) {
    # Already registered or not critical
  })

  invisible(NULL)
}
