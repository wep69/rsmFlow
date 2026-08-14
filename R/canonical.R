#' Canonical analysis of a fitted second-order response surface
#'
#' The quadratic form is recovered around the centre of the declared region,
#' using scale-aware finite differences. This is algebraically equivalent to
#' canonical analysis of a quadratic polynomial while being more stable than
#' evaluating natural-unit factors at arbitrary values such as -1, 0, and 1.
# internal core
.rf_canonical_lm <- function(object, tol = 1e-7) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  if (object$order != 2L) .rf_stop("Canonical analysis requires a second-order model.")
  k <- length(object$factors)
  center <- (object$bounds$lower + object$bounds$upper) / 2
  span <- pmax(object$bounds$upper - object$bounds$lower, 1)
  # A small but scale-aware step reduces cancellation in natural units while
  # remaining exact to numerical precision for a true quadratic polynomial.
  h <- pmax(span * 1e-3, sqrt(.Machine$double.eps) * pmax(abs(center), 1))
  f0 <- .rf_predict_scalar(object, center)
  g <- numeric(k)
  B <- matrix(0, k, k)

  for (i in seq_len(k)) {
    ep <- em <- center
    ep[i] <- ep[i] + h[i]
    em[i] <- em[i] - h[i]
    fp <- .rf_predict_scalar(object, ep)
    fm <- .rf_predict_scalar(object, em)
    g[i] <- (fp - fm) / (2 * h[i])
    # Hessian diagonal is 2 * B_ii for f(x) = b0 + b'x + x'Bx.
    B[i, i] <- (fp + fm - 2 * f0) / (2 * h[i]^2)
  }
  if (k > 1L) {
    for (i in seq_len(k - 1L)) for (j in (i + 1L):k) {
      pp <- pm <- mp <- mm <- center
      pp[i] <- pp[i] + h[i]; pp[j] <- pp[j] + h[j]
      pm[i] <- pm[i] + h[i]; pm[j] <- pm[j] - h[j]
      mp[i] <- mp[i] - h[i]; mp[j] <- mp[j] + h[j]
      mm[i] <- mm[i] - h[i]; mm[j] <- mm[j] - h[j]
      # Mixed second derivative = 2 * B_ij.
      Bij <- (.rf_predict_scalar(object, pp) - .rf_predict_scalar(object, pm) -
              .rf_predict_scalar(object, mp) + .rf_predict_scalar(object, mm)) /
             (8 * h[i] * h[j])
      B[i, j] <- B[j, i] <- Bij
    }
  }

  dimnames(B) <- list(object$factors, object$factors)
  ev <- eigen(B, symmetric = TRUE)
  rownames(ev$vectors) <- object$factors
  scale_B <- max(abs(ev$values), 1)
  flat_tol <- tol * scale_B
  singular <- min(abs(ev$values)) <= flat_tol
  # At centre c, gradient g = b + 2Bc; hence x_s = c - 1/2 B^-1 g.
  xs <- if (singular) rep(NA_real_, k) else as.numeric(center - 0.5 * solve(B, g))
  names(xs) <- object$factors
  pred <- if (all(is.finite(xs))) .rf_predict_scalar(object, xs) else NA_real_
  nature <- if (all(ev$values < -flat_tol)) "maximum" else if (all(ev$values > flat_tol)) "minimum" else if (any(ev$values > flat_tol) && any(ev$values < -flat_tol)) "saddle" else "ridge/flat"
  inside <- if (all(is.finite(xs))) all(xs >= object$bounds$lower & xs <= object$bounds$upper) else FALSE
  out <- list(
    stationary_point = xs,
    predicted_response = pred,
    B = B,
    gradient_at_center = setNames(g, object$factors),
    center = setNames(center, object$factors),
    eigenvalues = ev$values,
    eigenvectors = ev$vectors,
    nature = nature,
    singular_or_flat = singular,
    inside_region = inside,
    warning = if (!inside && all(is.finite(xs))) "Stationary point lies outside the declared experimental region." else if (nature == "saddle") "The stationary point is a saddle and must not be reported as an optimum." else if (singular) "One or more canonical curvatures are near zero; use ridge/bounded optimization rather than a unique stationary optimum." else NULL
  )
  class(out) <- "rsmFlow_canonical"
  out
}

#' Steepest ascent or descent path for a first-order local approximation
#' @export
rsm_steepest <- function(object, direction = c("ascent", "descent"), step = 0.1,
                         n_steps = 10, start = NULL, standardized = TRUE) {
  direction <- match.arg(direction)
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  k <- length(object$factors)
  if (is.null(start)) start <- (object$bounds$lower + object$bounds$upper)/2
  eps <- pmax((object$bounds$upper - object$bounds$lower) * 1e-5, 1e-7)
  grad <- numeric(k)
  for (j in seq_len(k)) {
    xp <- xm <- start; xp[j] <- xp[j] + eps[j]; xm[j] <- xm[j] - eps[j]
    grad[j] <- (.rf_predict_scalar(object, xp) - .rf_predict_scalar(object, xm))/(2*eps[j])
  }
  if (direction == "descent") grad <- -grad
  half <- (object$bounds$upper - object$bounds$lower)/2
  grad_work <- if (standardized) grad * half else grad
  if (sqrt(sum(grad_work^2)) < .Machine$double.eps) .rf_stop("Gradient is approximately zero at the starting point.")
  d <- grad_work/sqrt(sum(grad_work^2))
  scale_vec <- if (standardized) half else rep(1, k)
  pts <- t(vapply(0:n_steps, function(s) start + s * step * d * scale_vec, numeric(k)))
  for (j in seq_len(k)) pts[,j] <- pmin(pmax(pts[,j], object$bounds$lower[j]), object$bounds$upper[j])
  out <- as.data.frame(pts); names(out) <- object$factors
  out$step <- 0:n_steps
  out$predicted <- apply(pts, 1, function(z) .rf_predict_scalar(object, z))
  out
}

#' Ridge analysis within the bounded experimental region
#' @export
rsm_ridge <- function(object, radii = seq(0.1, 1, by = 0.1), goal = c("max", "min"),
                      center = NULL, n_starts = 20, seed = 123) {
  goal <- match.arg(goal)
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  set.seed(seed)
  k <- length(object$factors)
  if (is.null(center)) center <- (object$bounds$lower + object$bounds$upper)/2
  half <- (object$bounds$upper - object$bounds$lower)/2
  rows <- lapply(radii, function(r) {
    best <- NULL
    for (s in seq_len(n_starts)) {
      u <- stats::rnorm(k); u <- u/sqrt(sum(u^2))
      z0 <- center + half * r * u
      fn <- function(theta) {
        u <- theta/sqrt(sum(theta^2) + 1e-15)
        x <- center + half * r * u
        val <- .rf_predict_scalar(object, x)
        if (goal == "max") -val else val
      }
      op <- stats::optim(u, fn, method = "BFGS")
      u2 <- op$par/sqrt(sum(op$par^2) + 1e-15)
      x <- center + half * r * u2
      val <- .rf_predict_scalar(object, x)
      if (is.null(best) || (goal == "max" && val > best$val) || (goal == "min" && val < best$val)) best <- list(x = x, val = val)
    }
    c(radius = r, setNames(best$x, object$factors), predicted = best$val)
  })
  as.data.frame(do.call(rbind, rows), check.names = FALSE)
}
