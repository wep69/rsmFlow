# Internal helpers ---------------------------------------------------------

.rf_stop <- function(...) stop(..., call. = FALSE)
.rf_warn <- function(...) warning(..., call. = FALSE)

.rf_assert_numeric_factors <- function(data, factors) {
  miss <- setdiff(factors, names(data))
  if (length(miss)) .rf_stop("Missing factor columns: ", paste(miss, collapse = ", "))
  bad <- factors[!vapply(data[factors], is.numeric, logical(1))]
  if (length(bad)) .rf_stop("All response-surface factors must be numeric: ", paste(bad, collapse = ", "))
  invisible(TRUE)
}

.rf_bounds <- function(data, factors, bounds = NULL) {
  if (is.null(bounds)) {
    lower <- vapply(data[factors], min, numeric(1), na.rm = TRUE)
    upper <- vapply(data[factors], max, numeric(1), na.rm = TRUE)
    return(list(lower = lower, upper = upper))
  }
  if (is.matrix(bounds) || is.data.frame(bounds)) {
    if (nrow(bounds) != length(factors) || ncol(bounds) != 2L)
      .rf_stop("bounds must have one row per factor and two columns: lower, upper.")
    lower <- as.numeric(bounds[, 1]); upper <- as.numeric(bounds[, 2])
    names(lower) <- names(upper) <- factors
    return(list(lower = lower, upper = upper))
  }
  if (is.list(bounds) && all(c("lower", "upper") %in% names(bounds))) {
    lower <- as.numeric(bounds$lower); upper <- as.numeric(bounds$upper)
    if (length(lower) != length(factors) || length(upper) != length(factors))
      .rf_stop("bounds$lower and bounds$upper must match the number of factors.")
    names(lower) <- names(upper) <- factors
    return(list(lower = lower, upper = upper))
  }
  .rf_stop("Unsupported bounds format.")
}

.rf_surface_formula <- function(response, factors, order = 2L, block = NULL) {
  response_q <- paste0("`", response, "`")
  fq <- paste0("`", factors, "`")
  if (order == 1L) {
    rhs <- paste(fq, collapse = " + ")
  } else if (order == 2L) {
    interaction <- if (length(factors) > 1L) paste0("(", paste(fq, collapse = " + "), ")^2") else fq
    squares <- paste0("I(", fq, "^2)")
    rhs <- paste(c(interaction, squares), collapse = " + ")
  } else {
    .rf_stop("rsmFlow core currently supports order = 1 or 2. Higher-order models are expert extensions.")
  }
  if (!is.null(block)) rhs <- paste0("`", block, "` + ", rhs)
  stats::as.formula(paste(response_q, "~", rhs), env = parent.frame())
}

 .rf_newdata_template <- function(object, x) .rf_make_newdata(object, x)

# .rf_predict_scalar() is implemented in model_common.R for all model classes.

.rf_design_grid <- function(bounds, n = 25L, max_points = 100000L) {
  k <- length(bounds$lower)
  if (k <= 3L && n^k <= max_points) {
    seqs <- Map(seq, bounds$lower, bounds$upper, MoreArgs = list(length.out = n))
    out <- expand.grid(seqs, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    names(out) <- names(bounds$lower)
    return(out)
  }
  N <- min(max_points, max(5000L, n * 1000L))
  out <- sapply(seq_len(k), function(j) stats::runif(N, bounds$lower[j], bounds$upper[j]))
  out <- as.data.frame(out, check.names = FALSE)
  names(out) <- names(bounds$lower)
  out
}

.rf_model_matrix_for <- function(object, newdata) {
  tr <- stats::delete.response(stats::terms(object$model))
  stats::model.matrix(tr, newdata, contrasts.arg = object$model$contrasts)
}

.rf_surface_point <- function(object, values) {
  values <- as.numeric(values)
  names(values) <- object$factors
  values
}

.rf_mvn <- function(n, mu, Sigma) {
  ev <- eigen((Sigma + t(Sigma))/2, symmetric = TRUE)
  vals <- pmax(ev$values, 0)
  A <- ev$vectors %*% diag(sqrt(vals), nrow = length(vals))
  Z <- matrix(stats::rnorm(n * length(mu)), nrow = n)
  sweep(Z %*% t(A), 2, mu, "+")
}
