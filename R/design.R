#' Generate a response-surface design
#'
#' Generates CCD, Box-Behnken, D-optimal, I-optimal-like candidate designs, or
#' wraps a custom quantitative-factor design. Mixture designs are deliberately
#' excluded from rsmFlow.
#' @export
rsm_design <- function(factors, type = c("ccd", "ccd_circumscribed", "ccd_face", "ccd_inscribed", "bbd", "d_optimal", "i_optimal", "custom"),
                       levels = NULL, n0 = 4, alpha = "rotatable", runs = NULL,
                       candidates = NULL, data = NULL, randomize = TRUE, seed = NULL) {
  if (identical(type[1], "mixture")) .rf_stop("Mixture experiments are outside the scope of rsmFlow.")
  type <- match.arg(type)
  if (!is.null(seed)) set.seed(seed)
  if (length(factors) < 2L) .rf_stop("Use at least two quantitative factors.")

  if (type == "custom") {
    if (is.null(data)) .rf_stop("Provide data= for a custom design.")
    .rf_assert_numeric_factors(data, factors)
    out <- data
  } else if (type %in% c("ccd", "ccd_circumscribed", "ccd_face", "ccd_inscribed", "bbd")) {
    if (!requireNamespace("rsm", quietly = TRUE)) .rf_stop("Package 'rsm' is required for CCD/BBD generation.")
    k <- length(factors)
    if (type == "bbd") des <- rsm::bbd(k, n0 = n0, randomize = randomize) else {
      alpha_use <- if (type == "ccd_face") "faces" else alpha
      des <- rsm::ccd(k, n0 = n0, alpha = alpha_use, randomize = randomize)
    }
    out <- as.data.frame(des)
    xcols <- grep("^x[0-9]+$", names(out), value = TRUE)
    if (length(xcols) < k) xcols <- names(out)[seq_len(k)]
    names(out)[match(xcols[seq_len(k)], names(out))] <- factors
    if (type == "ccd_inscribed") {
      maxabs <- max(abs(as.matrix(out[, factors, drop = FALSE])), na.rm = TRUE)
      if (is.finite(maxabs) && maxabs > 0) out[, factors] <- out[, factors, drop = FALSE] / maxabs
    }
    keep <- unique(c(factors, intersect(c("Block", "block", "run.order", "std.order"), names(out))))
    out <- out[, keep, drop = FALSE]
  } else {
    if (is.null(candidates)) {
      if (is.null(levels)) levels <- rep(list(seq(-1, 1, length.out = 5)), length(factors))
      if (!is.list(levels)) levels <- rep(list(levels), length(factors))
      candidates <- expand.grid(levels, KEEP.OUT.ATTRS = FALSE)
      names(candidates) <- factors
    }
    .rf_assert_numeric_factors(candidates, factors)
    if (is.null(runs)) runs <- max(2L * length(factors) + 1L, min(nrow(candidates), 3L * length(factors) + 6L))
    if (!requireNamespace("AlgDesign", quietly = TRUE)) {
      .rf_warn("Package 'AlgDesign' not installed; using greedy information-based selection instead of AlgDesign::optFederov().")
      tmp <- list(data = candidates[seq_len(min(nrow(candidates), length(factors) + 1L)), , drop = FALSE], factors = factors)
      class(tmp) <- "rsmFlow_design_seed"
      out <- .rf_greedy_design(candidates, factors, runs, objective = if (type == "d_optimal") "D" else "I")
    } else {
      form2 <- .rf_surface_formula(".y", factors, order = 2)
      form <- stats::formula(stats::delete.response(stats::terms(form2)))
      opt <- AlgDesign::optFederov(form, data = candidates, nTrials = runs, criterion = if (type == "d_optimal") "D" else "I", approximate = FALSE)
      out <- opt$design[, factors, drop = FALSE]
    }
  }
  attr(out, "rsmFlow_design_type") <- type
  attr(out, "rsmFlow_factors") <- factors
  class(out) <- c("rsmFlow_design", class(out))
  out
}

.rf_greedy_design <- function(candidates, factors, runs, objective = "D") {
  form <- .rf_surface_formula(".y", factors, 2)
  candidates$.y <- 0
  Xall <- stats::model.matrix(form, candidates)
  p <- ncol(Xall)
  sel <- unique(c(seq_len(min(p, nrow(candidates))), sample(seq_len(nrow(candidates)), min(p, nrow(candidates)))))
  sel <- sel[seq_len(min(length(sel), runs))]
  while (length(sel) < runs) {
    rem <- setdiff(seq_len(nrow(candidates)), sel)
    scores <- vapply(rem, function(i) {
      X <- Xall[c(sel, i), , drop = FALSE]
      XtX <- crossprod(X) + diag(1e-10, ncol(X))
      if (objective == "D") as.numeric(determinant(XtX, logarithm = TRUE)$modulus) else -sum(diag(solve(XtX)))
    }, numeric(1))
    sel <- c(sel, rem[which.max(scores)])
  }
  candidates[sel, factors, drop = FALSE]
}

#' Code quantitative factors to centered/scaled coordinates
#' @export
rsm_code <- function(data, factors, center = NULL, scale = NULL) {
  .rf_assert_numeric_factors(data, factors)
  if (is.null(center)) center <- vapply(data[factors], function(x) mean(range(x, na.rm = TRUE)), numeric(1))
  if (is.null(scale)) scale <- vapply(data[factors], function(x) diff(range(x, na.rm = TRUE))/2, numeric(1))
  if (any(scale == 0)) .rf_stop("Cannot code a factor with zero range.")
  out <- data
  for (j in seq_along(factors)) out[[factors[j]]] <- (data[[factors[j]]] - center[j]) / scale[j]
  attr(out, "rsmFlow_coding") <- list(center = setNames(center, factors), scale = setNames(scale, factors))
  out
}

#' Decode coded factors to natural units
#' @export
rsm_decode <- function(data, coding) {
  if (is.null(coding$center) || is.null(coding$scale)) .rf_stop("coding must contain center and scale.")
  factors <- names(coding$center)
  out <- data
  for (j in factors) out[[j]] <- data[[j]] * coding$scale[[j]] + coding$center[[j]]
  out
}

#' Evaluate orthogonality of a quantitative design
#' @export
rsm_orthogonality <- function(x, factors = NULL, order = 2) {
  if (inherits(x, "rsmFlow_fit")) {
    X <- stats::model.matrix(x$model)
  } else {
    if (is.null(factors)) factors <- attr(x, "rsmFlow_factors")
    if (is.null(factors)) .rf_stop("Supply factors= for a raw design.")
    tmp <- x; tmp$.y <- 0
    X <- stats::model.matrix(.rf_surface_formula(".y", factors, order), tmp)
  }
  X <- X[, colnames(X) != "(Intercept)", drop = FALSE]
  Xs <- scale(X)
  Xs <- Xs[, apply(Xs, 2, function(z) all(is.finite(z))), drop = FALSE]
  C <- if (ncol(Xs) > 1L) stats::cor(Xs) else matrix(1, 1, 1)
  off <- if (ncol(C) > 1L) C[upper.tri(C)] else 0
  list(max_abs_correlation = max(abs(off), na.rm = TRUE), mean_abs_correlation = mean(abs(off), na.rm = TRUE), correlation = C)
}

#' Approximate rotatability using prediction-variance variation on spheres
#' @export
rsm_rotatability <- function(x, radii = c(0.5, 1), points = 500, seed = 123) {
  if (!inherits(x, "rsmFlow_fit")) .rf_stop("rsm_rotatability() currently requires an rsmFlow_fit object.")
  set.seed(seed)
  k <- length(x$factors)
  b <- x$bounds
  center <- (b$lower + b$upper)/2
  half <- (b$upper - b$lower)/2
  info <- solve(crossprod(stats::model.matrix(x$model)))
  rows <- lapply(radii, function(r) {
    Z <- matrix(stats::rnorm(points * k), nrow = points)
    Z <- Z / sqrt(rowSums(Z^2)) * r
    P <- sweep(sweep(Z, 2, half, "*"), 2, center, "+")
    nd <- as.data.frame(P); names(nd) <- x$factors
    if (!is.null(x$block)) nd[[x$block]] <- x$data[[x$block]][1]
    Xm <- .rf_model_matrix_for(x, nd)
    pv <- rowSums((Xm %*% info) * Xm)
    data.frame(radius = r, mean_spv = mean(pv), cv_spv = stats::sd(pv)/mean(pv), max_min_ratio = max(pv)/min(pv))
  })
  do.call(rbind, rows)
}

#' Prediction variance over a design region
#' @export
rsm_prediction_variance <- function(object, newdata = NULL, n = 25, scaled = TRUE) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  if (is.null(newdata)) newdata <- .rf_design_grid(object$bounds, n = n)
  if (!is.null(object$block) && !object$block %in% names(newdata)) newdata[[object$block]] <- object$data[[object$block]][1]
  X <- stats::model.matrix(object$model)
  XtXi <- solve(crossprod(X))
  Xn <- .rf_model_matrix_for(object, newdata)
  v <- rowSums((Xn %*% XtXi) * Xn)
  if (!scaled) v <- v * summary(object$model)$sigma^2
  out <- newdata[, object$factors, drop = FALSE]
  out$prediction_variance <- v
  out
}

#' Compare candidate response-surface designs
#' @export
rsm_compare_designs <- function(..., factors = NULL, order = 2) {
  designs <- list(...)
  if (!length(designs)) .rf_stop("Provide at least one design.")
  if (is.null(names(designs))) names(designs) <- paste0("design", seq_along(designs))
  do.call(rbind, lapply(seq_along(designs), function(i) {
    d <- designs[[i]]
    f <- factors %||% attr(d, "rsmFlow_factors")
    if (is.null(f)) .rf_stop("Supply factors= when designs do not carry rsmFlow metadata.")
    d$.y <- 0
    X <- stats::model.matrix(.rf_surface_formula(".y", f, order), d)
    r <- qr(X)$rank; p <- ncol(X)
    o <- rsm_orthogonality(d, f, order)
    XtX <- crossprod(scale(X[, -1, drop = FALSE], center = TRUE, scale = TRUE))
    ev <- eigen(XtX + diag(1e-12, ncol(XtX)), symmetric = TRUE, only.values = TRUE)$values
    data.frame(design = names(designs)[i], runs = nrow(d), parameters = p, rank = r,
               estimable = r == p, condition_number = kappa(X),
               max_abs_term_correlation = o$max_abs_correlation,
               min_information_eigenvalue = min(ev), stringsAsFactors = FALSE)
  }))
}

#' Augment an imperfect response-surface design
#' @export
rsm_augment <- function(object, n_add = 4, candidates = NULL,
                        objective = c("D", "A", "I", "G", "condition"), grid_n = 9, seed = 123) {
  objective <- match.arg(objective)
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  set.seed(seed)
  if (is.null(candidates)) candidates <- .rf_design_grid(object$bounds, n = grid_n, max_points = 50000)
  X0 <- stats::model.matrix(object$model)
  if (!is.null(object$block) && !object$block %in% names(candidates)) candidates[[object$block]] <- object$data[[object$block]][1]
  Xc <- .rf_model_matrix_for(object, candidates)
  # A separate region grid is used for I/G criteria so augmentation is judged
  # by prediction precision across the declared region, not only at candidates.
  region <- .rf_design_grid(object$bounds, n = min(grid_n, 9), max_points = 10000)
  if (!is.null(object$block) && !object$block %in% names(region)) region[[object$block]] <- object$data[[object$block]][1]
  Xr <- .rf_model_matrix_for(object, region)
  info <- crossprod(X0)
  chosen <- integer(0)
  for (s in seq_len(n_add)) {
    rem <- setdiff(seq_len(nrow(candidates)), chosen)
    score <- vapply(rem, function(i) {
      Inew <- info + tcrossprod(Xc[i, ])
      Ireg <- Inew + diag(1e-10, ncol(Inew))
      if (objective == "D") return(as.numeric(determinant(Ireg, logarithm = TRUE)$modulus))
      inv <- solve(Ireg)
      if (objective == "A") return(-sum(diag(inv)))
      if (objective == "I") return(-mean(rowSums((Xr %*% inv) * Xr)))
      if (objective == "G") return(-max(rowSums((Xr %*% inv) * Xr)))
      Xnew <- rbind(X0, Xc[c(chosen, i), , drop = FALSE])
      Z <- Xnew[, colnames(Xnew) != "(Intercept)", drop = FALSE]
      Z <- scale(Z)
      Z <- Z[, apply(Z, 2, function(z) all(is.finite(z))), drop = FALSE]
      -kappa(cbind(`(Intercept)`=1, Z))
    }, numeric(1))
    pick <- rem[which.max(score)]
    chosen <- c(chosen, pick)
    info <- info + tcrossprod(Xc[pick, ])
  }
  out <- candidates[chosen, object$factors, drop = FALSE]
  attr(out, "objective") <- objective
  out
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Fraction-of-design-space curve for scaled prediction variance
#' @export
rsm_fds <- function(object, n = 20000, seed = 123) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  set.seed(seed)
  region <- .rf_design_grid(object$bounds, n = max(12L, floor(n^(1/length(object$factors)))), max_points = n)
  pv <- rsm_prediction_variance(object, newdata = region, scaled = TRUE)
  spv <- sort(nrow(stats::model.matrix(object$model)) * pv$prediction_variance)
  out <- data.frame(fraction = seq_along(spv)/length(spv), scaled_prediction_variance = spv)
  attr(out, "region_points") <- nrow(region)
  class(out) <- c("rsmFlow_fds", class(out))
  out
}

#' Variance-dispersion summaries over standardized radii
#' @export
rsm_vdg <- function(object, radii = seq(0, 1, length.out = 21), points = 1000, seed = 123) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  X <- stats::model.matrix(object$model)
  if (qr(X)$rank < ncol(X)) .rf_stop("VDG requires a full-rank fitted model matrix.")
  info_inv <- solve(crossprod(X))
  center <- (object$bounds$lower + object$bounds$upper)/2
  half <- (object$bounds$upper - object$bounds$lower)/2
  k <- length(object$factors)
  set.seed(seed)
  rows <- lapply(radii, function(r) {
    if (abs(r) < .Machine$double.eps) {
      P <- matrix(center, nrow = 1)
    } else {
      Z <- matrix(stats::rnorm(points*k), ncol = k)
      Z <- Z / sqrt(rowSums(Z^2))
      P <- sweep(sweep(Z*r, 2, half, "*"), 2, center, "+")
    }
    nd <- as.data.frame(P); names(nd) <- object$factors
    if (!is.null(object$block)) nd[[object$block]] <- object$data[[object$block]][1]
    Xm <- .rf_model_matrix_for(object, nd)
    spv <- nrow(X) * rowSums((Xm %*% info_inv)*Xm)
    data.frame(radius=r, min_spv=min(spv), mean_spv=mean(spv), max_spv=max(spv), sd_spv=stats::sd(spv))
  })
  out <- do.call(rbind, rows)
  class(out) <- c("rsmFlow_vdg", class(out))
  out
}
