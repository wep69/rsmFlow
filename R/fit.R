#' Fit a hierarchical response-surface model
#'
#' @param data Data frame.
#' @param response Numeric response column name.
#' @param factors Two or more quantitative factor names.
#' @param order Polynomial order, 1 or 2.
#' @param block Optional block column included additively.
#' @param estimator OLS or robust regression (MASS::rlm, optional).
#' @param weights Optional prior weights for weighted least squares.
#' @param bounds Optional optimization/design region.
#' @param coding Optional coding metadata with center and scale.
#' @param na.action Missing-value action.
#' @param engine Model class: classical Gaussian polynomial RSM, GLM-RSM, or nonlinear surface.
#' @param family GLM family when \code{engine = "glm"}.
#' @param nonlinear_model Built-in nonlinear two-factor model name.
#' @param nonlinear_formula Optional custom nonlinear formula.
#' @param nonlinear_start Named numeric starting vector or \code{"ga"}, \code{"multistart"}, \code{"auto"}.
#' @param nonlinear_start_bounds Named lower/upper parameter bounds for automatic starts.
#' @param nonlinear_engine Nonlinear backend: \code{nlsLM}, \code{nls}, or Tier-3 \code{gnls}.
#' @param ... Additional arguments forwarded to the selected engine.
#' @export
rsm_fit <- function(data, response, factors, order = 2, block = NULL,
                    estimator = c("ols", "wls_power", "robust"), weights = NULL,
                    bounds = NULL, coding = NULL, na.action = stats::na.omit,
                    engine = c("lm", "glm", "nonlinear"), family = NULL,
                    nonlinear_model = "mitscherlich2_product", nonlinear_formula = NULL,
                    nonlinear_start = "ga", nonlinear_start_bounds = NULL,
                    nonlinear_engine = "nlsLM", ...) {
  engine <- match.arg(engine)
  if (engine == "glm") {
    if (is.null(family)) family <- stats::gaussian()
    return(rsm_glm_fit(data, response, factors, order=order, block=block, family=family,
                       bounds=bounds, weights=weights, na.action=na.action, ...))
  }
  if (engine == "nonlinear") {
    return(rsm_nonlinear_fit(data, response, factors, model=nonlinear_model,
                             formula=nonlinear_formula, start=nonlinear_start,
                             start_bounds=nonlinear_start_bounds, engine=nonlinear_engine,
                             bounds=bounds, weights=weights, ...))
  }
  estimator <- match.arg(estimator)
  if (!is.data.frame(data)) data <- as.data.frame(data)
  if (!response %in% names(data)) .rf_stop("Response column not found: ", response)
  if (!is.numeric(data[[response]])) .rf_stop("Response must be numeric.")
  if (length(factors) < 2L) .rf_stop("At least two quantitative factors are required.")
  .rf_assert_numeric_factors(data, factors)
  if (!is.null(block) && !block %in% names(data)) .rf_stop("Block column not found: ", block)
  if (!is.null(block) && !is.factor(data[[block]])) data[[block]] <- factor(data[[block]])
  formula <- .rf_surface_formula(response, factors, order, block)

  variance_model <- NULL
  if (estimator == "robust") {
    if (!requireNamespace("MASS", quietly = TRUE)) .rf_stop("Package 'MASS' is required for estimator='robust'.")
    model <- MASS::rlm(formula, data = data, weights = weights, na.action = na.action, model = TRUE, x.ret = TRUE)
  } else if (estimator == "wls_power") {
    if (!is.null(weights)) .rf_stop("Do not supply weights= together with estimator='wls_power'.")
    initial <- stats::lm(formula, data=data, na.action=na.action, model=TRUE, x=TRUE, y=TRUE)
    e <- stats::residuals(initial); fv <- stats::fitted(initial)
    eps <- max(.Machine$double.eps, stats::median(abs(e),na.rm=TRUE)^2 * 1e-8)
    variance_model <- stats::lm(log(e^2 + eps) ~ log(abs(fv) + sqrt(eps)))
    logv <- stats::predict(variance_model)
    w <- exp(-logv); w <- w/mean(w)
    model <- stats::lm(formula, data=initial$model, weights=w, na.action=na.action, model=TRUE, x=TRUE, y=TRUE)
  } else {
    model <- stats::lm(formula, data = data, weights = weights, na.action = na.action, model = TRUE, x = TRUE, y = TRUE)
  }

  b <- .rf_bounds(model$model, factors, bounds)
  out <- list(
    call = match.call(), data = model$model, response = response, factors = factors,
    order = as.integer(order), block = block, estimator = estimator, model = model,
    formula = formula, bounds = b, coding = coding, variance_model = variance_model,
    hierarchy = TRUE, created = Sys.time()
  )
  class(out) <- "rsmFlow_fit"
  out
}

#' @export
predict.rsmFlow_fit <- function(object, newdata = NULL, se.fit = FALSE, interval = "none", level = 0.95, ...) {
  if (is.null(newdata)) newdata <- object$data
  stats::predict(object$model, newdata = newdata, se.fit = se.fit, interval = interval, level = level, ...)
}

#' Decompose residual error into pure error and lack of fit
#'
#' The pure-error reference is obtained from a cell-means model for the unique
#' quantitative-factor settings. When a block is present, the block term is
#' retained in that reference model, so between-block variation is not silently
#' counted as pure error.
# internal core
.rf_lm_lack_of_fit <- function(object) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  if (object$estimator != "ols") .rf_stop("Formal lack-of-fit decomposition is implemented for OLS fits.")
  if (!is.null(object$model$weights)) return(list(available = FALSE, reason = "Formal pure-error/lack-of-fit decomposition is not reported for weighted least-squares fits."))
  dat <- object$data
  # Cell identity is defined only by quantitative factor settings. Significant
  # digits avoid trivial floating-point differences from splitting nominally
  # identical design points.
  key_parts <- lapply(dat[object$factors], function(z) signif(z, 12))
  key <- do.call(paste, c(key_parts, sep = "\r"))
  dat$.rsmFlow_cell <- factor(key)

  # The reference model represents one mean per distinct design point while
  # preserving the same additive blocking structure as the response-surface fit.
  rhs <- if (is.null(object$block)) ".rsmFlow_cell" else paste0("`", object$block, "` + .rsmFlow_cell")
  f_full <- stats::as.formula(paste0("`", object$response, "` ~ ", rhs))
  full <- stats::lm(f_full, data = dat)

  ss_pe <- sum(stats::residuals(full)^2)
  df_pe <- stats::df.residual(full)
  ss_res <- sum(stats::residuals(object$model)^2)
  df_res <- stats::df.residual(object$model)
  df_lof <- df_res - df_pe
  ss_lof <- ss_res - ss_pe

  if (df_pe <= 0L) {
    return(list(available = FALSE, reason = "No residual degrees of freedom remain in the replicated cell-means reference model; pure error is not estimable."))
  }
  if (df_lof <= 0L) {
    return(list(available = FALSE, reason = "The response-surface model has no degrees of freedom beyond pure error for a lack-of-fit test."))
  }
  # Numerical roundoff can make an exactly nested difference slightly negative.
  if (ss_lof < 0 && abs(ss_lof) <= 1e-8 * max(1, ss_res, ss_pe)) ss_lof <- 0
  if (ss_lof < 0) .rf_stop("The pure-error reference model is not numerically nested in the fitted response-surface model. Inspect missing values, weights, or model specification.")

  ms_pe <- ss_pe / df_pe
  ms_lof <- ss_lof / df_lof
  F <- ms_lof / ms_pe
  p <- stats::pf(F, df_lof, df_pe, lower.tail = FALSE)
  list(
    available = TRUE,
    pure_error = c(SS = ss_pe, df = df_pe, MS = ms_pe),
    lack_of_fit = c(SS = ss_lof, df = df_lof, MS = ms_lof, F = F, p.value = p),
    residual = c(SS = ss_res, df = df_res),
    reference = if (is.null(object$block)) "cell-means" else "block + cell-means"
  )
}

#' General model diagnostics for response-surface fits
# internal core
.rf_lm_diagnostics <- function(object) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  m <- object$model
  X <- stats::model.matrix(m)
  X0 <- X[, colnames(X) != "(Intercept)", drop = FALSE]
  vif <- if (ncol(X0) > 1L) vapply(seq_len(ncol(X0)), function(j) {
    z <- X0[, j]; rest <- X0[, -j, drop = FALSE]
    R2 <- summary(stats::lm(z ~ rest))$r.squared
    if (R2 >= 1) Inf else 1/(1 - R2)
  }, numeric(1)) else setNames(1, colnames(X0))
  if (length(vif)) names(vif) <- colnames(X0)
  res <- stats::residuals(m)
  fit <- stats::fitted(m)
  std <- if (inherits(m, "lm")) stats::rstandard(m) else res/stats::sd(res)
  cook <- if (inherits(m, "lm")) stats::cooks.distance(m) else rep(NA_real_, length(res))
  lev <- if (inherits(m, "lm")) stats::hatvalues(m) else rep(NA_real_, length(res))
  Xs0 <- scale(X0)
  Xs0 <- Xs0[, apply(Xs0, 2, function(z) all(is.finite(z))), drop = FALSE]
  Xsfull <- cbind(`(Intercept)` = 1, Xs0)
  list(
    n = length(res), p = ncol(X), rank = qr(X)$rank,
    condition_number_raw = kappa(X),
    condition_number_scaled = kappa(Xsfull),
    vif = vif, residuals = res, fitted = fit, standardized_residuals = std,
    cooks_distance = cook, leverage = lev,
    rmse = sqrt(mean(res^2)), mae = mean(abs(res)),
    r_squared = if (inherits(m, "lm")) summary(m)$r.squared else NA_real_,
    adjusted_r_squared = if (inherits(m, "lm")) summary(m)$adj.r.squared else NA_real_,
    lack_of_fit = if (inherits(m, "lm")) rsm_lack_of_fit(object) else list(available = FALSE)
  )
}

#' Audit estimability, collinearity, orthogonality and prediction variance
#' @export
rsm_design_audit <- function(object, grid_n = 15, rotatability = TRUE) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  X <- stats::model.matrix(object$model)
  p <- ncol(X); r <- qr(X)$rank
  eig <- eigen(crossprod(X), symmetric = TRUE, only.values = TRUE)$values
  orth <- rsm_orthogonality(object)
  pv <- try(rsm_prediction_variance(object, n = grid_n, scaled = TRUE), silent = TRUE)
  pv_summary <- if (inherits(pv, "try-error")) NULL else c(
    mean = mean(pv$prediction_variance), median = stats::median(pv$prediction_variance),
    max = max(pv$prediction_variance), min = min(pv$prediction_variance),
    q90 = stats::quantile(pv$prediction_variance, .90, names = FALSE)
  )
  fds <- if (inherits(pv, "try-error")) NULL else {
    spv <- nrow(X) * pv$prediction_variance
    stats::quantile(spv, probs = c(.1,.25,.5,.75,.9,.95,.99), names = TRUE)
  }
  Xni <- X[, colnames(X) != "(Intercept)", drop = FALSE]
  Xs <- scale(Xni)
  good <- apply(Xs, 2, function(z) all(is.finite(z)))
  Xs <- Xs[, good, drop = FALSE]
  corr_info <- if (ncol(Xs)) crossprod(Xs)/(nrow(Xs)-1) else matrix(1,1,1)
  corr_info <- corr_info + diag(1e-12, ncol(corr_info))
  iev <- eigen(corr_info, symmetric = TRUE, only.values = TRUE)$values
  information_indices <- c(
    D_correlation_index = exp(as.numeric(determinant(corr_info, logarithm = TRUE)$modulus)/ncol(corr_info)),
    A_correlation_index = ncol(corr_info)/sum(diag(solve(corr_info))),
    E_correlation_index = min(iev),
    G_efficiency_percent = if (is.null(pv_summary)) NA_real_ else 100 * p/(nrow(X) * pv_summary[["max"]]),
    I_average_scaled_prediction_variance = if (is.null(pv_summary)) NA_real_ else nrow(X) * pv_summary[["mean"]]
  )
  exact_alias <- try(stats::alias(object$model)$Complete, silent = TRUE)
  if (inherits(exact_alias, "try-error")) exact_alias <- NULL
  diag <- rsm_diagnostics(object)
  ks <- diag$condition_number_scaled
  status <- if (r < p) "non-estimable" else if (!is.finite(ks) || ks > 1000) "severe instability" else if (ks > 100) "caution" else if (orth$max_abs_correlation > .8) "caution" else "usable"
  out <- list(
    estimable = r == p, rank = r, parameters = p, residual_df = stats::df.residual(object$model),
    condition_number_raw = diag$condition_number_raw, condition_number_scaled = ks, information_eigenvalues = eig,
    orthogonality = orth, vif = diag$vif, prediction_variance = pv_summary, fds = fds,
    information_indices = information_indices,
    rotatability = if (rotatability && r == p) try(rsm_rotatability(object), silent = TRUE) else NULL,
    exact_alias = exact_alias,
    status = status,
    notes = c(
      if (r < p) "The second-order model is not fully estimable from this design." else NULL,
      if (ks > 100) "Scaled model-matrix conditioning is poor; coefficient interpretation may be unstable. Emphasize prediction variance and consider augmentation." else NULL,
      if (orth$max_abs_correlation > .8) "Strong term correlation indicates substantial non-orthogonality." else NULL
    )
  )
  class(out) <- "rsmFlow_design_audit"
  out
}
