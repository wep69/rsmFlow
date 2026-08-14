#' Optimize a response surface inside declared bounds
#'
#' @param object An rsmFlow_fit.
#' @param goal max, min, or target.
#' @param method analytic, L-BFGS-B, grid, GA, hybrid, or all.
#' @param target Target response when goal='target'.
# internal legacy implementation retained for cross-checking
.rf_optimize_lm_legacy <- function(object, goal = c("max", "min", "target"),
                         method = c("hybrid", "L-BFGS-B", "GA", "grid", "analytic", "all"),
                         target = NULL, bounds = NULL, seed = 123,
                         grid_n = 31, ga_control = list(popSize = 80, maxiter = 500, run = 100)) {
  goal <- match.arg(goal); method <- match.arg(method)
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  if (goal == "target" && is.null(target)) .rf_stop("target= is required when goal='target'.")
  if (goal == "target" && method == "analytic") .rf_stop("method='analytic' is not defined for target-response optimization; use a bounded numerical method.")
  b <- if (is.null(bounds)) object$bounds else .rf_bounds(object$data, object$factors, bounds)
  lower <- b$lower; upper <- b$upper
  set.seed(seed)
  score <- function(x) {
    y <- .rf_predict_scalar(object, x)
    if (goal == "max") y else if (goal == "min") -y else -abs(y - target)
  }
  rows <- list()
  add <- function(name, x) {
    y <- .rf_predict_scalar(object, x)
    rows[[length(rows) + 1L]] <<- c(method = name, setNames(as.numeric(x), object$factors), predicted = y, score = score(x))
  }

  if (method %in% c("analytic", "all") && object$order == 2L) {
    ca <- try(rsm_canonical(object), silent = TRUE)
    if (!inherits(ca, "try-error") && all(is.finite(ca$stationary_point)) && all(ca$stationary_point >= lower & ca$stationary_point <= upper)) {
      if ((goal == "max" && ca$nature == "maximum") || (goal == "min" && ca$nature == "minimum")) add("analytic_stationary", ca$stationary_point)
    }
  }

  if (method %in% c("grid", "all", "hybrid")) {
    grid <- .rf_design_grid(b, n = grid_n, max_points = 150000L)
    vals <- apply(grid, 1, score)
    xg <- as.numeric(grid[which.max(vals), object$factors, drop = TRUE])
    add("grid", xg)
  } else xg <- (lower + upper)/2

  if (method %in% c("L-BFGS-B", "all", "hybrid")) {
    fn <- function(x) -score(x)
    starts <- rbind((lower + upper)/2, xg)
    ops <- lapply(seq_len(nrow(starts)), function(i) stats::optim(starts[i,], fn, method = "L-BFGS-B", lower = lower, upper = upper))
    best <- ops[[which.min(vapply(ops, `[[`, numeric(1), "value"))]]
    add("L-BFGS-B", best$par)
  }

  if (method %in% c("GA", "all", "hybrid")) {
    if (requireNamespace("GA", quietly = TRUE)) {
      ctrl <- modifyList(list(popSize = 80, maxiter = 500, run = 100), ga_control)
      ga <- GA::ga(type = "real-valued", fitness = score, lower = lower, upper = upper,
                   popSize = ctrl$popSize, maxiter = ctrl$maxiter, run = ctrl$run, monitor = FALSE, seed = seed)
      xga <- as.numeric(ga@solution[1, ])
      add("GA", xga)
      if (method == "hybrid") {
        local <- stats::optim(xga, function(x) -score(x), method = "L-BFGS-B", lower = lower, upper = upper)
        add("GA+L-BFGS-B", local$par)
      }
    } else if (method == "GA") {
      .rf_stop("Package 'GA' is required for method='GA'.")
    } else {
      .rf_warn("Package 'GA' is unavailable; hybrid optimization used grid + L-BFGS-B only.")
    }
  }

  if (!length(rows)) .rf_stop("No optimization method produced a candidate solution.")
  mat <- do.call(rbind, rows)
  df <- as.data.frame(mat, stringsAsFactors = FALSE, check.names = FALSE)
  num <- setdiff(names(df), "method")
  df[num] <- lapply(df[num], as.numeric)
  best_i <- which.max(df$score)
  out <- list(
    solution = setNames(as.numeric(df[best_i, object$factors]), object$factors),
    predicted = df$predicted[best_i], method = df$method[best_i], goal = goal, target = target,
    candidates = df, bounds = b, inside_region = TRUE, fit = object
  )
  class(out) <- "rsmFlow_optimum"
  out
}

#' Bootstrap uncertainty for an estimated optimum
# internal legacy implementation retained for cross-checking
.rf_optimum_ci_lm_legacy <- function(object, optimum = NULL, B = 999, conf = 0.95,
                           method = c("residual", "parametric", "case"),
                           optimizer = "L-BFGS-B", seed = 123) {
  method <- match.arg(method)
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  if (object$estimator != "ols") .rf_stop("Bootstrap optimum inference currently requires an OLS fit.")
  if (is.null(optimum)) optimum <- rsm_optimize(object, method = optimizer)
  if (method == "case") .rf_warn("Case bootstrap can disrupt designed-experiment structure. Prefer residual or parametric bootstrap unless case resampling is scientifically justified.")
  set.seed(seed)
  dat <- object$data
  yname <- object$response
  fitted <- stats::fitted(object$model); resid <- stats::residuals(object$model)
  sigma <- summary(object$model)$sigma
  sols <- matrix(NA_real_, B, length(object$factors) + 1L)
  colnames(sols) <- c(object$factors, "predicted")
  fail <- 0L
  for (b in seq_len(B)) {
    db <- dat
    if (method == "residual") db[[yname]] <- fitted + sample(resid, length(resid), replace = TRUE)
    else if (method == "parametric") db[[yname]] <- fitted + stats::rnorm(length(fitted), 0, sigma)
    else db <- dat[sample(seq_len(nrow(dat)), nrow(dat), replace = TRUE), , drop = FALSE]
    fb <- try(rsm_fit(db, yname, object$factors, object$order, object$block, "ols", bounds = object$bounds, coding = object$coding), silent = TRUE)
    if (inherits(fb, "try-error")) { fail <- fail + 1L; next }
    ob <- try(rsm_optimize(fb, goal = optimum$goal, method = optimizer, target = optimum$target, bounds = object$bounds, seed = seed + b), silent = TRUE)
    if (inherits(ob, "try-error")) { fail <- fail + 1L; next }
    sols[b,] <- c(ob$solution, ob$predicted)
  }
  sols <- sols[stats::complete.cases(sols), , drop = FALSE]
  if (nrow(sols) < max(30, .5 * B)) .rf_warn("A high fraction of bootstrap replicates failed; inspect estimability and boundary behavior.")
  alpha <- (1-conf)/2
  ci <- t(apply(sols, 2, stats::quantile, probs = c(alpha, 1-alpha), na.rm = TRUE))
  colnames(ci) <- c("lower", "upper")
  inside <- apply(sols[, object$factors, drop = FALSE], 1, function(z) all(z >= object$bounds$lower & z <= object$bounds$upper))
  list(
    estimate = c(optimum$solution, predicted = optimum$predicted), intervals = ci,
    bootstrap = as.data.frame(sols), conf = conf, B_requested = B, B_valid = nrow(sols),
    failures = fail, probability_inside_region = mean(inside), method = method
  )
}

#' Identify a near-optimal decision region
# internal legacy implementation retained for cross-checking
.rf_near_optimal_lm_legacy <- function(object, optimum = NULL, tolerance = 0.05,
                             goal = c("max", "min"), n = 41, max_points = 150000, seed = 123) {
  goal <- match.arg(goal)
  if (is.null(optimum)) optimum <- rsm_optimize(object, goal = goal, method = "hybrid", seed = seed)
  set.seed(seed)
  grid <- .rf_design_grid(object$bounds, n = n, max_points = max_points)
  pred <- apply(grid[, object$factors, drop = FALSE], 1, function(x) .rf_predict_scalar(object, x))
  best <- optimum$predicted
  keep <- if (goal == "max") pred >= best - tolerance * max(abs(best), .Machine$double.eps) else pred <= best + tolerance * max(abs(best), .Machine$double.eps)
  out <- grid[keep, object$factors, drop = FALSE]
  out$predicted <- pred[keep]
  attr(out, "tolerance") <- tolerance
  attr(out, "optimum") <- best
  out
}

#' Optimize a lower/upper confidence bound rather than only the fitted mean
# internal legacy implementation retained for cross-checking
.rf_robust_optimize_lm_legacy <- function(object, goal = c("max", "min"), lambda = 1.96,
                                method = c("L-BFGS-B", "GA"), seed = 123) {
  goal <- match.arg(goal); method <- match.arg(method)
  score <- function(x) {
    pr <- .rf_predict_scalar(object, x, se.fit = TRUE)
    if (goal == "max") pr$fit - lambda * pr$se.fit else -(pr$fit + lambda * pr$se.fit)
  }
  b <- object$bounds
  if (method == "GA") {
    if (!requireNamespace("GA", quietly = TRUE)) .rf_stop("Package 'GA' is required.")
    ga <- GA::ga(type = "real-valued", fitness = score, lower = b$lower, upper = b$upper,
                 popSize = 80, maxiter = 500, run = 100, monitor = FALSE, seed = seed)
    x <- as.numeric(ga@solution[1,])
  } else {
    op <- stats::optim((b$lower+b$upper)/2, function(x) -score(x), method = "L-BFGS-B", lower = b$lower, upper = b$upper)
    x <- op$par
  }
  pr <- .rf_predict_scalar(object, x, se.fit = TRUE)
  list(solution = setNames(x, object$factors), predicted = pr$fit, se = pr$se.fit,
       confidence_bound = if (goal == "max") pr$fit-lambda*pr$se.fit else pr$fit+lambda*pr$se.fit,
       goal = goal, lambda = lambda, method = method)
}

#' Approximate joint region from bootstrap optimum coordinates
#' @export
rsm_optimum_region <- function(uncertainty, factors = NULL, conf = NULL, n = 200) {
  if (is.null(uncertainty$bootstrap)) .rf_stop("uncertainty must come from rsm_optimum_ci().")
  B <- uncertainty$bootstrap
  if (is.null(factors)) factors <- setdiff(names(B), "predicted")
  if (!all(factors %in% names(B))) .rf_stop("Requested factors are not present in bootstrap samples.")
  if (is.null(conf)) conf <- uncertainty$conf %||% 0.95
  X <- as.matrix(B[,factors,drop=FALSE]); center <- colMeans(X); S <- stats::cov(X)
  out <- list(center=center, covariance=S, conf=conf, factors=factors,
              cutoff=stats::qchisq(conf, df=length(factors)), method="bootstrap covariance ellipsoid")
  if (length(factors)==2L) {
    ev <- eigen(S, symmetric=TRUE); theta <- seq(0,2*pi,length.out=n)
    circle <- rbind(cos(theta),sin(theta))
    A <- ev$vectors %*% diag(sqrt(pmax(ev$values,0)*out$cutoff),2)
    pts <- t(sweep(A %*% circle,1,center,"+")); pts <- as.data.frame(pts); names(pts) <- factors
    out$boundary <- pts
  }
  class(out) <- "rsmFlow_optimum_region"
  out
}
