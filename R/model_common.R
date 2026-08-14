# Common model abstraction -------------------------------------------------

.rf_model_supported <- function(object) {
  inherits(object, c("rsmFlow_fit", "rsmFlow_glm", "rsmFlow_nonlinear", "rsmFlow_surrogate"))
}

.rf_model_kind <- function(object) {
  if (inherits(object, "rsmFlow_glm")) return("glm")
  if (inherits(object, "rsmFlow_nonlinear")) return("nonlinear")
  if (inherits(object, "rsmFlow_surrogate")) return("surrogate")
  if (inherits(object, "rsmFlow_fit")) return("gaussian_rsm")
  "unknown"
}

.rf_model_data <- function(object) object$data
.rf_model_factors <- function(object) object$factors
.rf_model_response <- function(object) object$response
.rf_model_bounds <- function(object) object$bounds

.rf_make_newdata <- function(object, x) {
  if (is.data.frame(x)) {
    nd <- x
  } else {
    xv <- as.numeric(x)
    if (length(xv) != length(object$factors)) .rf_stop("x must contain one value per factor.")
    nd <- as.data.frame(as.list(xv), check.names = FALSE)
    names(nd) <- object$factors
  }
  if (!is.null(object$block) && !object$block %in% names(nd)) {
    b <- object$data[[object$block]]
    if (is.factor(b)) nd[[object$block]] <- factor(levels(b)[1], levels = levels(b))
    else nd[[object$block]] <- b[which(!is.na(b))[1]]
  }
  if (inherits(object,"rsmFlow_glm") && isTRUE(object$offset_used) && !".rsmFlow_offset" %in% names(nd))
    nd$.rsmFlow_offset <- object$offset_reference %||% 0
  nd
}

.rf_predict_mean <- function(object, newdata, se.fit = FALSE, scale = c("response", "link"), level = 0.95) {
  scale <- match.arg(scale)
  if (!.rf_model_supported(object)) .rf_stop("Unsupported rsmFlow model object.")
  if (scale == "link" && !inherits(object, "rsmFlow_glm"))
    .rf_stop("scale = 'link' is available only for GLM response surfaces; other engines are predicted on the response scale.")
  nd <- .rf_make_newdata(object, newdata)

  if (inherits(object, "rsmFlow_glm")) {
    type <- if (scale == "response") "response" else "link"
    p <- stats::predict(object$model, newdata = nd, type = type, se.fit = se.fit)
    if (se.fit) return(list(fit = as.numeric(p$fit), se.fit = as.numeric(p$se.fit), scale = scale))
    return(as.numeric(p))
  }
  if (inherits(object, "rsmFlow_nonlinear")) {
    p <- predict(object, newdata = nd, se.fit = se.fit, level = level)
    if (se.fit) return(p)
    return(as.numeric(p))
  }
  if (inherits(object, "rsmFlow_surrogate")) {
    p <- predict(object, newdata = nd, se.fit = se.fit)
    if (se.fit) return(p)
    return(as.numeric(p))
  }
  p <- stats::predict(object$model, newdata = nd, se.fit = se.fit)
  if (se.fit) return(list(fit = as.numeric(p$fit), se.fit = as.numeric(p$se.fit), scale = "response"))
  as.numeric(p)
}

.rf_predict_scalar <- function(object, x, se.fit = FALSE, scale = "response") {
  p <- .rf_predict_mean(object, .rf_make_newdata(object, x), se.fit = se.fit, scale = scale)
  if (se.fit) return(list(fit = as.numeric(p$fit)[1], se.fit = as.numeric(p$se.fit)[1]))
  as.numeric(p)[1]
}

.rf_fitted_values <- function(object, scale = "response") {
  if (inherits(object, "rsmFlow_glm")) return(as.numeric(stats::fitted(object$model)))
  if (inherits(object, "rsmFlow_nonlinear")) return(as.numeric(stats::fitted(object$model)))
  if (inherits(object, "rsmFlow_surrogate")) return(.rf_predict_mean(object, object$data[, object$factors, drop = FALSE]))
  as.numeric(stats::fitted(object$model))
}

.rf_residual_values <- function(object, type = NULL) {
  if (inherits(object, "rsmFlow_glm")) {
    if (is.null(type)) type <- "deviance"
    return(as.numeric(stats::residuals(object$model, type = type)))
  }
  if (inherits(object, "rsmFlow_nonlinear")) return(as.numeric(stats::residuals(object$model)))
  if (inherits(object, "rsmFlow_surrogate")) return(object$data[[object$response]] - .rf_fitted_values(object))
  as.numeric(stats::residuals(object$model))
}

.rf_refit_model <- function(object, data, start = NULL, seed = 123) {
  if (inherits(object, "rsmFlow_glm")) {
    fam <- object$family_spec
    w <- if (".rsmFlow_prior_weight" %in% names(data)) data$.rsmFlow_prior_weight else NULL
    off <- if (isTRUE(object$offset_used) && ".rsmFlow_offset" %in% names(data)) data$.rsmFlow_offset else NULL
    return(rsm_glm_fit(data, object$response, object$factors, order = object$order,
                       block = object$block, family = fam, bounds = object$bounds,
                       weights = w, offset = off, offset_reference = object$offset_reference %||% 0,
                       na.action = stats::na.omit))
  }
  if (inherits(object, "rsmFlow_nonlinear")) {
    st <- if (is.null(start)) as.numeric(stats::coef(object$model)) else start
    names(st) <- names(stats::coef(object$model))
    return(rsm_nonlinear_fit(data, object$response, object$factors,
                             model = object$model_name, formula = object$formula,
                             start = st, start_bounds = object$parameter_bounds,
                             engine = object$engine, bounds = object$bounds,
                             variance = object$variance_spec,
                             correlation = object$correlation_spec,
                             seed = seed))
  }
  if (inherits(object, "rsmFlow_fit")) {
    return(rsm_fit(data, object$response, object$factors, object$order,
                   object$block, object$estimator, bounds = object$bounds,
                   coding = object$coding))
  }
  .rf_stop("Automatic refitting is unavailable for this object class.")
}

.rf_numeric_gradient <- function(fun, x, step = NULL) {
  x <- as.numeric(x)
  if (is.null(step)) step <- pmax(abs(x), 1) * 1e-5
  g <- numeric(length(x))
  for (j in seq_along(x)) {
    xp <- xm <- x; xp[j] <- xp[j] + step[j]; xm[j] <- xm[j] - step[j]
    g[j] <- (fun(xp) - fun(xm)) / (2 * step[j])
  }
  g
}

.rf_numeric_hessian <- function(fun, x, step = NULL) {
  x <- as.numeric(x); k <- length(x)
  if (is.null(step)) step <- pmax(abs(x), 1) * 1e-4
  H <- matrix(0, k, k)
  f0 <- fun(x)
  for (i in seq_len(k)) {
    xp <- xm <- x; xp[i] <- xp[i] + step[i]; xm[i] <- xm[i] - step[i]
    H[i, i] <- (fun(xp) - 2 * f0 + fun(xm)) / (step[i]^2)
    if (i < k) for (j in (i + 1L):k) {
      xpp <- xpm <- xmp <- xmm <- x
      xpp[i] <- xpp[i] + step[i]; xpp[j] <- xpp[j] + step[j]
      xpm[i] <- xpm[i] + step[i]; xpm[j] <- xpm[j] - step[j]
      xmp[i] <- xmp[i] - step[i]; xmp[j] <- xmp[j] + step[j]
      xmm[i] <- xmm[i] - step[i]; xmm[j] <- xmm[j] - step[j]
      H[i, j] <- H[j, i] <- (fun(xpp) - fun(xpm) - fun(xmp) + fun(xmm)) / (4 * step[i] * step[j])
    }
  }
  H
}

.rf_classify_hessian <- function(H, tol = 1e-7) {
  ev <- eigen((H + t(H))/2, symmetric = TRUE)
  scl <- max(1, max(abs(ev$values)))
  z <- tol * scl
  nature <- if (all(ev$values < -z)) "maximum" else if (all(ev$values > z)) "minimum" else if (any(ev$values < -z) && any(ev$values > z)) "saddle" else "ridge-flat"
  list(nature = nature, eigenvalues = ev$values, eigenvectors = ev$vectors)
}
