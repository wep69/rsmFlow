#' @export
print.rsmFlow_fit <- function(x, ...) {
  cat("rsmFlow response-surface fit\n")
  cat("Response:", x$response, "\nFactors:", paste(x$factors, collapse = ", "), "\nOrder:", x$order, "\nEstimator:", x$estimator, "\n")
  invisible(x)
}

#' @export
summary.rsmFlow_fit <- function(object, ...) {
  cat("rsmFlow fit summary\n\n")
  print(summary(object$model))
  cat("\nDesign audit\n")
  print(rsm_design_audit(object))
  invisible(object)
}

#' @export
print.rsmFlow_design_audit <- function(x, ...) {
  cat("Design status:", x$status, "\n")
  cat("Rank:", x$rank, "/", x$parameters, " | condition number (scaled/raw):", signif(x$condition_number_scaled, 5), "/", signif(x$condition_number_raw, 5), "\n")
  cat("Maximum absolute model-term correlation:", signif(x$orthogonality$max_abs_correlation, 5), "\n")
  if (length(x$notes)) cat(paste0("- ", x$notes, collapse = "\n"), "\n")
  invisible(x)
}

#' @export
print.rsmFlow_canonical <- function(x, ...) {
  cat("Canonical analysis\nNature:", x$nature, "\n")
  cat("Stationary point:\n"); print(x$stationary_point)
  cat("Predicted response:", x$predicted_response, "\nInside region:", x$inside_region, "\n")
  if (!is.null(x$warning)) cat("Warning:", x$warning, "\n")
  invisible(x)
}

#' @export
print.rsmFlow_optimum <- function(x, ...) {
  cat("rsmFlow optimum\nGoal:", x$goal, " | method:", x$method, "\n")
  print(x$solution)
  cat("Predicted response:", x$predicted, "\n")
  invisible(x)
}

#' @export
plot.rsmFlow_fit <- function(x, ...) rsm_plot(x, ...)

#' @export
print.rsmFlow_glm <- function(x, ...) {
  cat("rsmFlow generalized response-surface fit\n")
  cat("Response:",x$response,"\nFactors:",paste(x$factors,collapse=", "),"\nOrder:",x$order,
      "\nFamily:",stats::family(x$model)$family,"\nLink:",stats::family(x$model)$link,"\nEngine:",x$engine,"\n")
  invisible(x)
}

#' @export
summary.rsmFlow_glm <- function(object, ...) {
  cat("rsmFlow GLM response-surface summary\n\n")
  print(summary(object$model))
  cat("\nDispersion diagnostic\n")
  print(rsm_glm_dispersion(object))
  invisible(object)
}

#' @export
print.rsmFlow_nonlinear <- function(x, ...) {
  cat("rsmFlow nonlinear two-factor surface\n")
  cat("Response:",x$response,"\nFactors:",paste(x$factors,collapse=", "),"\nModel:",x$model_name,"\nEngine:",x$engine,"\nStart search:",x$start_search$engine,"\n")
  invisible(x)
}

#' @export
summary.rsmFlow_nonlinear <- function(object, ...) {
  cat("rsmFlow nonlinear response-surface summary\n\n")
  print(summary(object$model))
  cat("\nNonlinear diagnostics\n")
  d<-rsm_nonlinear_diagnostics(object)
  print(d[c("converged","engine","model","RSS","RMSE","AIC","BIC","jacobian_condition","start_engine")])
  if(!is.null(d$warning))cat("Warning:",d$warning,"\n")
  invisible(object)
}

#' @export
plot.rsmFlow_glm <- function(x, ...) rsm_plot(x, ...)
#' @export
plot.rsmFlow_nonlinear <- function(x, ...) rsm_plot(x, ...)
