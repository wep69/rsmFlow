#' Economic optimum of a fitted response surface
#'
#' Maximizes predicted gross margin or profit over the declared experimental
#' region. This is a decision-support layer, not a general farm-economics model.
#'
#' @param object rsmFlow_fit object for an output/yield response.
#' @param response_price Price received per response unit; alternatively a function y -> revenue.
#' @param factor_cost Named marginal cost per unit of each quantitative factor, or named functions.
#' @param fixed_cost Constant cost independent of factor levels.
#' @param baseline Optional factor baseline. Costs are computed on x-baseline when supplied.
#' @param method L-BFGS-B or GA.
# internal legacy implementation retained for cross-checking
.rf_economic_optimum_lm_legacy <- function(object, response_price, factor_cost,
                                 fixed_cost = 0, baseline = NULL,
                                 method = c("L-BFGS-B", "GA"), seed = 123) {
  method <- match.arg(method)
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  factors <- object$factors
  if (is.null(names(factor_cost)) || !all(factors %in% names(factor_cost)))
    .rf_stop("factor_cost must be named for every fitted factor: ", paste(factors, collapse = ", "))
  if (is.null(baseline)) baseline <- setNames(object$bounds$lower, factors)
  if (length(baseline) != length(factors)) .rf_stop("baseline must match the number of factors.")
  if (is.null(names(baseline))) names(baseline) <- factors

  revenue <- function(y) if (is.function(response_price)) response_price(y) else as.numeric(response_price) * y
  cost <- function(x) {
    sum(vapply(seq_along(factors), function(j) {
      cst <- factor_cost[[factors[j]]]
      amount <- x[j] - baseline[[factors[j]]]
      if (is.function(cst)) cst(amount) else as.numeric(cst) * amount
    }, numeric(1))) + fixed_cost
  }
  profit <- function(x) {
    y <- .rf_predict_scalar(object, x)
    revenue(y) - cost(x)
  }

  b <- object$bounds; set.seed(seed)
  if (method == "GA") {
    if (!requireNamespace("GA", quietly = TRUE)) .rf_stop("Package 'GA' is required for method='GA'.")
    ga <- GA::ga(type = "real-valued", fitness = profit, lower = b$lower, upper = b$upper,
                 popSize = 100, maxiter = 700, run = 150, monitor = FALSE, seed = seed)
    x <- as.numeric(ga@solution[1,])
  } else {
    grid <- .rf_design_grid(b, n = 12, max_points = 5000)
    vals <- apply(grid, 1, profit)
    start <- as.numeric(grid[which.max(vals), factors, drop = TRUE])
    op <- stats::optim(start, function(x) -profit(x), method = "L-BFGS-B", lower = b$lower, upper = b$upper)
    x <- op$par
  }
  y <- .rf_predict_scalar(object, x)
  rev <- revenue(y); cst <- cost(x)
  bio <- rsm_optimize(object, goal = "max", method = "L-BFGS-B")
  out <- list(
    solution = setNames(x, factors), predicted_response = y, revenue = rev, variable_plus_fixed_cost = cst,
    profit = rev - cst, method = method, response_price = response_price, factor_cost = factor_cost,
    biological_optimum = bio$solution, biological_predicted = bio$predicted,
    interpretation = "Economic optimum maximizes fitted revenue minus declared factor and fixed costs inside the experimental region; it does not extrapolate beyond declared bounds."
  )
  class(out) <- "rsmFlow_economic_optimum"
  out
}
