#' Individual desirability function
#' @export
rsm_desirability <- function(y, goal = c("max", "min", "target", "interval"),
                             low, high, target = NULL, weight = 1) {
  goal <- match.arg(goal)
  if (high <= low) .rf_stop("high must be greater than low.")
  y <- as.numeric(y)
  d <- numeric(length(y))
  if (goal == "max") {
    d[y <= low] <- 0; d[y >= high] <- 1
    mid <- y > low & y < high
    d[mid] <- ((y[mid]-low)/(high-low))^weight
  } else if (goal == "min") {
    d[y <= low] <- 1; d[y >= high] <- 0
    mid <- y > low & y < high
    d[mid] <- ((high-y[mid])/(high-low))^weight
  } else if (goal == "target") {
    if (is.null(target) || target <= low || target >= high) .rf_stop("target must lie strictly between low and high.")
    left <- y > low & y <= target; right <- y > target & y < high
    d[left] <- ((y[left]-low)/(target-low))^weight
    d[right] <- ((high-y[right])/(high-target))^weight
    d[y == target] <- 1
  } else {
    d[y >= low & y <= high] <- 1
  }
  pmin(pmax(d, 0), 1)
}

#' Multiple-response optimization by desirability or Pareto search
#' @export
rsm_multiopt <- function(fits, goals, limits,
                         method = c("desirability", "pareto", "weighted", "distance", "epsilon"),
                         importance = NULL, optimizer = c("GA", "L-BFGS-B"), seed = 123,
                         sample_n = 5000, primary = 1, epsilon = NULL) {
  method <- match.arg(method); optimizer <- match.arg(optimizer)
  if (!is.list(fits) || length(fits) < 2L || !all(vapply(fits, .rf_model_supported, logical(1))))
    .rf_stop("fits must be a list of at least two supported rsmFlow model objects.")
  factors <- fits[[1]]$factors
  if (!all(vapply(fits, function(z) identical(z$factors, factors), logical(1)))) .rf_stop("All response models must use the same factors in the same order.")
  if (length(goals) != length(fits) || length(limits) != length(fits)) .rf_stop("goals and limits must match fits.")
  allowed_goals <- c("max", "min", "target", "interval")
  if (any(!goals %in% allowed_goals)) .rf_stop("Unsupported response goal in goals=.")
  for (i in seq_along(limits)) {
    if (is.null(limits[[i]]$low) || is.null(limits[[i]]$high) || limits[[i]]$high <= limits[[i]]$low)
      .rf_stop("Each limits[[i]] must define high > low.")
  }
  if (primary < 1L || primary > length(fits)) .rf_stop("primary must index one of the fitted responses.")
  if (is.null(importance)) importance <- rep(1, length(fits))
  if (length(importance) != length(fits) || any(!is.finite(importance)) || any(importance < 0) || sum(importance) <= 0)
    .rf_stop("importance must contain non-negative finite weights with positive total weight.")
  b <- fits[[1]]$bounds

  pred_all <- function(x) vapply(fits, function(f) .rf_predict_scalar(f, x), numeric(1))
  utility_one <- function(y, goal, lim) {
    lo <- lim$low; hi <- lim$high; tar <- lim$target %||% NULL
    if (goal == "max") return(pmin(pmax((y-lo)/(hi-lo),0),1))
    if (goal == "min") return(pmin(pmax((hi-y)/(hi-lo),0),1))
    if (goal == "target") {
      if (is.null(tar)) .rf_stop("target is required for target goals.")
      den <- if (y <= tar) tar-lo else hi-tar
      return(pmax(0, 1-abs(y-tar)/max(den,.Machine$double.eps)))
    }
    as.numeric(y >= lo && y <= hi)
  }
  dscore <- function(x) {
    ys <- pred_all(x)
    ds <- vapply(seq_along(fits), function(i) {
      lim <- limits[[i]]
      rsm_desirability(ys[i], goal = goals[[i]], low = lim$low, high = lim$high,
                       target = lim$target %||% NULL, weight = lim$shape %||% 1)
    }, numeric(1))
    if (any(ds <= 0)) return(0)
    exp(sum(importance * log(ds))/sum(importance))
  }
  weighted_score <- function(x) {
    ys <- pred_all(x)
    u <- vapply(seq_along(fits), function(i) utility_one(ys[i], goals[[i]], limits[[i]]), numeric(1))
    sum(importance*u)/sum(importance)
  }
  distance_score <- function(x) {
    ys <- pred_all(x)
    u <- vapply(seq_along(fits), function(i) utility_one(ys[i], goals[[i]], limits[[i]]), numeric(1))
    -sqrt(sum(importance*(1-u)^2)/sum(importance))
  }
  epsilon_score <- function(x) {
    ys <- pred_all(x)
    for (i in seq_along(fits)) if (i != primary) {
      lim <- limits[[i]]; eps_i <- if (!is.null(epsilon)) epsilon[[i]] %||% NULL else NULL
      ok <- if (goals[[i]] == "max") ys[i] >= (eps_i %||% lim$low) else if (goals[[i]] == "min") ys[i] <= (eps_i %||% lim$high) else ys[i] >= lim$low && ys[i] <= lim$high
      if (!ok) return(-1e100)
    }
    utility_one(ys[primary], goals[[primary]], limits[[primary]])
  }

  if (method == "pareto") {
    if (any(!goals %in% c("max", "min"))) .rf_stop("Pareto search currently requires each goal to be 'max' or 'min'. Transform target/interval responses to utilities before Pareto analysis.")
    return(rsm_pareto(fits, goals = goals, n = sample_n, engine = if (optimizer=="GA") "NSGA2" else "sample", seed = seed))
  }
  score <- switch(method, desirability=dscore, weighted=weighted_score, distance=distance_score, epsilon=epsilon_score)

  set.seed(seed)
  if (optimizer == "GA" && !requireNamespace("GA", quietly = TRUE)) {
    .rf_warn("Package 'GA' unavailable; falling back to L-BFGS-B."); optimizer <- "L-BFGS-B"
  }
  if (optimizer == "GA") {
    ga <- GA::ga(type = "real-valued", fitness = score, lower = b$lower, upper = b$upper,
                 popSize = 100, maxiter = 700, run = 150, monitor = FALSE, seed = seed)
    x <- as.numeric(ga@solution[1,])
  } else {
    starts <- .rf_design_grid(b, n = 8, max_points = 250)
    vals <- apply(starts, 1, score)
    st <- as.numeric(starts[which.max(vals), factors, drop = TRUE])
    op <- stats::optim(st, function(x) -score(x), method = "L-BFGS-B", lower = b$lower, upper = b$upper)
    x <- op$par
  }
  preds <- pred_all(x)
  list(solution = setNames(x, factors), predictions = preds, objective = score(x),
       method = paste(method, optimizer, sep = "+"), primary=primary)
}

#' Approximate a Pareto front for multiple fitted responses
#' @export
rsm_pareto <- function(fits, goals, n = 5000, engine = c("sample","NSGA2"), seed = 123) {
  engine <- match.arg(engine)
  if (length(fits) != length(goals)) .rf_stop("goals must match fits.")
  if (any(!goals %in% c("max", "min"))) .rf_stop("rsm_pareto() supports only max/min objectives; convert target/interval goals to utility models first.")
  factors <- fits[[1]]$factors; b <- fits[[1]]$bounds
  set.seed(seed)
  if (engine == "NSGA2") {
    if (!requireNamespace("mco", quietly=TRUE)) {
      .rf_warn("Package 'mco' unavailable; using sampled Pareto approximation.")
      engine <- "sample"
    } else {
      fn <- function(x) vapply(seq_along(fits), function(j) {
        y <- .rf_predict_scalar(fits[[j]], x)
        if (goals[[j]] == "max") -y else y
      }, numeric(1))
      res <- mco::nsga2(fn, idim=length(factors), odim=length(fits), lower.bounds=b$lower,
                        upper.bounds=b$upper, popsize=100, generations=150)
      keep <- res$pareto.optimal
      X <- as.data.frame(res$par[keep,,drop=FALSE]); names(X) <- factors
      out <- cbind(X, as.data.frame(sapply(fits, function(f) apply(X,1,function(x) .rf_predict_scalar(f,x)))))
      names(out)[(length(factors)+1):ncol(out)] <- paste0("response", seq_along(fits))
      attr(out,"engine") <- "NSGA2"
      return(out)
    }
  }
  grid_n <- max(8L, floor(n^(1/length(factors))))
  X <- .rf_design_grid(b, n = grid_n, max_points = n)
  Y <- sapply(fits, function(f) apply(X[, factors, drop = FALSE], 1, function(x) .rf_predict_scalar(f, x)))
  for (j in seq_along(goals)) if (goals[[j]] == "min") Y[,j] <- -Y[,j]
  # Incremental nondominated set; avoids materializing an n x n dominance matrix.
  front <- integer(0)
  for (i in seq_len(nrow(Y))) {
    if (length(front) && any(vapply(front, function(j) all(Y[j,] >= Y[i,]) && any(Y[j,] > Y[i,]), logical(1)))) next
    if (length(front)) front <- front[!vapply(front, function(j) all(Y[i,] >= Y[j,]) && any(Y[i,] > Y[j,]), logical(1))]
    front <- c(front, i)
  }
  out <- cbind(X[front, factors, drop = FALSE], as.data.frame(sapply(fits, function(f) apply(X[front, factors, drop = FALSE], 1, function(x) .rf_predict_scalar(f, x)))))
  names(out)[(length(factors)+1):ncol(out)] <- paste0("response", seq_along(fits))
  out
}
