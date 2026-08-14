#' Launch the optional rsmFlow teaching/research Shiny interface
#' @export
run_rsm_app <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) .rf_stop("Package 'shiny' is required to launch the optional app.")
  app <- system.file("shiny", "app.R", package = "rsmFlow")
  if (!nzchar(app)) .rf_stop("Shiny app was not installed with the package.")
  shiny::runApp(app)
}
