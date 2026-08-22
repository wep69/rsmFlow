# Generalized response-surface models --------------------------------------

.rf_glm_family <- function(family) {
  if (inherits(family, "family")) return(list(kind = "glm", family = family, spec = family))
  if (is.function(family)) {
    f <- family()
    if (inherits(f, "family")) return(list(kind = "glm", family = f, spec = family))
  }
  if (!is.character(family) || length(family) != 1L) .rf_stop("family must be a family object/function or supported character string.")
  key <- tolower(gsub("[ .-]", "_", family))
  if (key %in% c("negative_binomial", "negativebinomial", "nb", "nbinom")) return(list(kind = "nb", family = NULL, spec = "negative_binomial"))
  fun <- switch(key,
                gaussian = stats::gaussian,
                poisson = stats::poisson,
                quasipoisson = stats::quasipoisson,
                binomial = stats::binomial,
                quasibinomial = stats::quasibinomial,
                gamma = stats::Gamma,
                inverse_gaussian = stats::inverse.gaussian,
                inversegaussian = stats::inverse.gaussian,
                NULL)
  if (is.null(fun)) .rf_stop("Unsupported GLM family: ", family)
  list(kind = "glm", family = fun(), spec = key)
}

#' Fit a generalized response-surface model for two quantitative factors
#'
#' Fits a first- or second-order response surface on the linear-predictor scale
#' using stats::glm(), or MASS::glm.nb() for negative-binomial responses.
#' Optimization and plotting use the response scale by default.
#'
#' @param data Data frame.
#' @param response Response column name. Binomial responses may use the standard
#'   forms accepted by glm() when supplied through formula workflows; this helper
#'   expects a named column for the common scalar-response case.
#' @param factors Exactly two quantitative factor names.
#' @param order Polynomial order, 1 or 2.
#' @param block Optional additive block factor.
#' @param family GLM family object/function or one of gaussian, poisson,
#'   quasipoisson, binomial, quasibinomial, Gamma, inverse_gaussian, or
#'   negative_binomial.
#' @param bounds Optional experimental/optimization bounds.
#' @param weights Optional prior weights.
#' @param offset Optional observation-level link-scale offset. It is encoded as an explicit offset term so the same semantics work for glm and glm.nb.
#' @param offset_reference Link-scale offset used for new prediction/optimization points when offset= was supplied; 0 corresponds to unit exposure for a log offset.
#' @param na.action Missing-value action.
#' @param ... Additional arguments passed to glm() or glm.nb().
#' @export
rsm_glm_fit <- function(data, response, factors, order = 2, block = NULL,
                        family = stats::gaussian(), bounds = NULL,
                        weights = NULL, offset = NULL, offset_reference = 0,
                        na.action = stats::na.omit, ...) {
  if (!is.data.frame(data)) data <- as.data.frame(data)
  if (length(factors) != 2L) .rf_stop("rsm_glm_fit() currently targets exactly two quantitative factors.")
  if (!response %in% names(data)) .rf_stop("Response column not found: ", response)
  .rf_assert_numeric_factors(data, factors)
  if (!is.null(block) && !block %in% names(data)) .rf_stop("Block column not found: ", block)
  if (!is.null(block) && !is.factor(data[[block]])) data[[block]] <- factor(data[[block]])
  ff <- .rf_glm_family(family)
  fit_data <- data
  offset_used <- !is.null(offset)
  if (offset_used) {
    if (!is.numeric(offset) || length(offset) != nrow(fit_data) || any(!is.finite(offset)))
      .rf_stop("offset must be a finite numeric vector with one value per input row.")
    fit_data$.rsmFlow_offset <- as.numeric(offset)
  }
  form <- .rf_surface_formula(response, factors, order, block)
  if (offset_used) {
    fenv <- new.env(parent=environment(form)); fenv$offset <- stats::offset
    form <- stats::as.formula(paste(deparse(form), "+ offset(.rsmFlow_offset)"), env = fenv)
  }
  if (ff$kind == "nb") {
    if (!requireNamespace("MASS", quietly = TRUE)) .rf_stop("Package 'MASS' is required for negative-binomial RSM.")
    model <- MASS::glm.nb(form, data = fit_data, weights = weights,
                          na.action = na.action, model = TRUE, x = TRUE, y = TRUE, ...)
    fam_obj <- stats::family(model)
  } else {
    model <- stats::glm(form, family = ff$family, data = fit_data, weights = weights,
                        na.action = na.action, model = TRUE, x = TRUE, y = TRUE, ...)
    fam_obj <- stats::family(model)
  }
  model_data <- model$model
  prior_w <- tryCatch(as.numeric(stats::weights(model, type = "prior")),
                      error = function(e) rep(1, nrow(model_data)))
  if (length(prior_w) == nrow(model_data)) model_data$.rsmFlow_prior_weight <- prior_w
  if (offset_used) {
    off_used <- tryCatch(as.numeric(stats::model.offset(model$model)), error=function(e) NULL)
    if (!is.null(off_used) && length(off_used) == nrow(model_data)) model_data$.rsmFlow_offset <- off_used
  }
  out <- list(call = match.call(), data = model_data, response = response,
              factors = factors, order = as.integer(order), block = block,
              family = fam_obj, family_spec = ff$spec, model = model,
              formula = form, bounds = .rf_bounds(data, factors, bounds),
              prior_weights = prior_w, offset_used = offset_used,
              offset_reference = as.numeric(offset_reference)[1],
              engine = if (ff$kind == "nb") "MASS::glm.nb" else "stats::glm",
              created = Sys.time())
  class(out) <- c("rsmFlow_glm", "rsmFlow_model")
  out
}

#' @export
predict.rsmFlow_glm <- function(object, newdata = NULL, type = c("response", "link"),
                                se.fit = FALSE, ...) {
  type <- match.arg(type)
  if (is.null(newdata)) newdata <- object$data else newdata <- .rf_make_newdata(object,newdata)
  stats::predict(object$model, newdata = newdata, type = type, se.fit = se.fit, ...)
}

#' Dispersion diagnostics for generalized response surfaces
#' @export
rsm_glm_dispersion <- function(object) {
  if (!inherits(object, "rsmFlow_glm")) .rf_stop("object must be an rsmFlow_glm.")
  pearson <- stats::residuals(object$model, type = "pearson")
  df <- stats::df.residual(object$model)
  ratio <- if (df > 0) sum(pearson^2, na.rm = TRUE) / df else NA_real_
  fam <- stats::family(object$model)$family
  fixed <- fam %in% c("poisson", "binomial") && !inherits(object$model, "negbin")
  list(family = fam, link = stats::family(object$model)$link,
       pearson_dispersion = ratio,
       residual_deviance = stats::deviance(object$model),
       df_residual = df,
       dispersion_fixed_by_family = fixed,
       interpretation = if (is.finite(ratio) && ratio > 1.5 && fam %in% c("poisson", "binomial"))
         "Substantial extra-Poisson/binomial variation may be present; compare scientifically plausible overdispersed alternatives rather than switching models automatically."
       else "Interpret dispersion jointly with residual diagnostics and the data-generating process.")
}

#' Diagnostics for generalized response-surface models
#' @export
rsm_glm_diagnostics <- function(object) {
  if (!inherits(object, "rsmFlow_glm")) .rf_stop("object must be an rsmFlow_glm.")
  m <- object$model
  fam <- stats::family(m)$family
  quasi <- grepl("^quasi", fam)
  aic <- if (quasi) NA_real_ else tryCatch(stats::AIC(m), error = function(e) NA_real_)
  list(
    family = fam, link = stats::family(m)$link,
    deviance_residuals = as.numeric(stats::residuals(m, type = "deviance")),
    pearson_residuals = as.numeric(stats::residuals(m, type = "pearson")),
    fitted = as.numeric(stats::fitted(m)),
    leverage = tryCatch(as.numeric(stats::hatvalues(m)), error = function(e) rep(NA_real_, nrow(object$data))),
    cooks_distance = tryCatch(as.numeric(stats::cooks.distance(m)), error = function(e) rep(NA_real_, nrow(object$data))),
    null_deviance = m$null.deviance, residual_deviance = m$deviance,
    df_null = m$df.null, df_residual = m$df.residual,
    AIC = aic,
    BIC = if (quasi) NA_real_ else tryCatch(stats::BIC(m), error = function(e) NA_real_),
    AIC_comparable = !quasi,
    dispersion = rsm_glm_dispersion(object)
  )
}

#' Lack-of-fit assessment for replicated generalized response surfaces
#' @export
rsm_glm_lack_of_fit <- function(object) {
  if (!inherits(object, "rsmFlow_glm")) .rf_stop("object must be an rsmFlow_glm.")
  dat <- object$data
  key_parts <- lapply(dat[object$factors], function(z) signif(z, 12))
  dat$.rsmFlow_cell <- factor(do.call(paste, c(key_parts, sep = "\r")))
  rhs <- if (is.null(object$block)) ".rsmFlow_cell" else paste0("`", object$block, "` + .rsmFlow_cell")
  if (isTRUE(object$offset_used)) rhs <- paste0(rhs, " + offset(.rsmFlow_offset)")
  ffull <- stats::as.formula(paste0("`", object$response, "` ~ ", rhs), env=environment(object$formula))
  # Add weights to data frame to avoid environment lookup issues
  has_w <- ".rsmFlow_prior_weight" %in% names(dat)
  if (has_w) {
    dat$.rsmFlow_lof_w <- dat[[".rsmFlow_prior_weight"]]
  }
  if (inherits(object$model, "negbin")) {
    full <- if (has_w) MASS::glm.nb(ffull, data = dat, weights = .rsmFlow_lof_w) else MASS::glm.nb(ffull, data = dat)
  } else {
    full <- if (has_w) stats::glm(ffull, family = stats::family(object$model), data = dat, weights = .rsmFlow_lof_w) else stats::glm(ffull, family = stats::family(object$model), data = dat)
  }
  ddev <- stats::deviance(object$model) - stats::deviance(full)
  ddf <- stats::df.residual(object$model) - stats::df.residual(full)
  if (ddf <= 0) return(list(available = FALSE, reason = "Replicated cell-means reference leaves no lack-of-fit degrees of freedom."))
  fam <- stats::family(object$model)$family
  if (grepl("^quasi", fam)) {
    disp <- rsm_glm_dispersion(object)$pearson_dispersion
    F <- (ddev / ddf) / disp
    p <- stats::pf(F, ddf, stats::df.residual(full), lower.tail = FALSE)
    test <- "scaled deviance F approximation"
    statistic <- F
  } else {
    p <- stats::pchisq(max(ddev, 0), ddf, lower.tail = FALSE)
    test <- "deviance chi-square approximation"
    statistic <- ddev
  }
  list(available = TRUE, delta_deviance = ddev, df = ddf,
       statistic = statistic, p.value = p, method = test,
       reference = if (is.null(object$block)) "cell-means GLM" else "block + cell-means GLM")
}

#' Canonical analysis for a two-factor second-order GLM response surface
#'
#' The stationary candidate is obtained from the quadratic linear predictor,
#' but maximum/minimum/saddle classification is verified numerically on the
#' response scale.
#' @export
rsm_glm_canonical <- function(object, tol = 1e-7) {
  if (!inherits(object, "rsmFlow_glm")) .rf_stop("object must be an rsmFlow_glm.")
  if (object$order != 2L) .rf_stop("Canonical analysis requires order = 2.")
  f1 <- object$factors[1]; f2 <- object$factors[2]
  cf <- stats::coef(object$model); nm <- names(cf)
  get_exact <- function(candidates, default = 0) {
    ix <- match(candidates, nm, nomatch = 0L); ix <- ix[ix > 0L]
    if (!length(ix)) default else unname(cf[ix[1]])
  }
  b1 <- get_exact(c(f1, paste0("`",f1,"`")))
  b2 <- get_exact(c(f2, paste0("`",f2,"`")))
  q1 <- get_exact(c(paste0("I(",f1,"^2)"),paste0("I(`",f1,"`^2)")))
  q2 <- get_exact(c(paste0("I(",f2,"^2)"),paste0("I(`",f2,"`^2)")))
  i12 <- get_exact(c(paste0(f1,":",f2),paste0(f2,":",f1),paste0("`",f1,"`:`",f2,"`"),paste0("`",f2,"`:`",f1,"`")))
  B <- matrix(c(q1, i12/2, i12/2, q2), 2, 2, byrow = TRUE)
  b <- c(b1, b2)
  if (qr(B)$rank < 2L) .rf_stop("Quadratic form is singular; use bounded/ridge optimization instead of a unique stationary point.")
  xs <- as.numeric(-0.5 * solve(B, b)); names(xs) <- object$factors
  fun <- function(x) .rf_predict_scalar(object, x, scale = "response")
  H <- .rf_numeric_hessian(fun, xs)
  cl <- .rf_classify_hessian(H, tol)
  inside <- all(xs >= object$bounds$lower & xs <= object$bounds$upper)
  out <- list(stationary_point = xs, predicted_response = fun(xs),
              nature = cl$nature, response_hessian = H,
              eigenvalues = cl$eigenvalues, eigenvectors = cl$eigenvectors,
              linear_predictor_B = B, inside_region = inside,
              family = stats::family(object$model)$family,
              link = stats::family(object$model)$link,
              warning = if (!inside) "Stationary point lies outside the declared experimental region; use bounded optimization for operational decisions." else NULL)
  class(out) <- "rsmFlow_canonical"
  out
}
