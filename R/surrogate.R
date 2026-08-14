#' Fit an optional advanced surrogate model
#'
#' Advanced surrogates are expert-layer alternatives when a quadratic surface is
#' scientifically inadequate. They do not replace design diagnostics or the
#' classical second-order model by default.
#' @export
rsm_surrogate <- function(data, response, factors,
                          method = c("quadratic", "gam", "gp", "tps", "rf", "nn"),
                          bounds = NULL, seed = 123, ...) {
  method <- match.arg(method)
  .rf_assert_numeric_factors(data, factors)
  if (!response %in% names(data) || !is.numeric(data[[response]])) .rf_stop("response must name a numeric column.")
  b <- .rf_bounds(data, factors, bounds)
  set.seed(seed)
  if (method == "quadratic") {
    fit <- rsm_fit(data, response, factors, 2, bounds=b)
    out <- list(method=method, engine="rsmFlow", model=fit, response=response, factors=factors, bounds=b, data=data)
  } else if (method %in% c("gam","tps")) {
    if (!requireNamespace("mgcv", quietly=TRUE)) .rf_stop("Package 'mgcv' is required for GAM/TPS surrogates.")
    qf <- paste0("`", factors, "`")
    if (method == "tps") {
      # Joint multivariate thin-plate smooth, retaining interactions among factors.
      n_obs <- nrow(data)
      k_val <- min(10, max(4, floor(n_obs / 2)))
      rhs <- paste0("s(", paste(qf, collapse=","), ", k=", k_val, ", bs=\"tp\")")
    } else {
      # Main smooths plus pairwise tensor interactions. This is deliberately
      # explicit rather than silently fitting only an additive surface.
      n_obs <- nrow(data)
      k_s <- min(10, max(4, floor(sqrt(n_obs))))
      k_ti <- min(5, max(3, floor(sqrt(n_obs) / 2)))
      main <- paste0("s(", qf, ", k=", k_s, ", bs=\"tp\")")
      inter <- character()
      if (length(factors) >= 2L) {
        cmb <- utils::combn(seq_along(factors), 2)
        inter <- apply(cmb, 2, function(j) paste0("ti(",qf[j[1]],",",qf[j[2]],", k=", k_ti, ", bs=c(\"tp\",\"tp\"))"))
      }
      rhs <- paste(c(main, inter), collapse=" + ")
    }
    form <- stats::as.formula(paste0("`",response,"` ~ ",rhs))
    fenv <- new.env(parent=parent.frame()); fenv$s <- mgcv::s; fenv$ti <- mgcv::ti
    environment(form) <- fenv
    mod <- mgcv::gam(form, data=data, method="REML", ...)
    out <- list(method=method, engine="mgcv", model=mod, response=response, factors=factors, bounds=b, data=data, formula=form)
  } else if (method == "gp") {
    if (!requireNamespace("DiceKriging", quietly=TRUE)) .rf_stop("Package 'DiceKriging' is required for Gaussian-process surrogates.")
    design <- as.data.frame(data[factors])
    mod <- DiceKriging::km(formula=~1, design=design, response=data[[response]], covtype="matern5_2", nugget.estim=TRUE, ...)
    out <- list(method=method, engine="DiceKriging", model=mod, response=response, factors=factors, bounds=b, data=data)
  } else if (method == "rf") {
    if (!requireNamespace("ranger", quietly=TRUE)) .rf_stop("Package 'ranger' is required for random-forest surrogates.")
    form <- stats::as.formula(paste0("`",response,"` ~ ",paste(paste0("`",factors,"`"),collapse=" + ")))
    mod <- ranger::ranger(form, data=data, num.trees=1000, seed=seed, ...)
    out <- list(method=method, engine="ranger", model=mod, response=response, factors=factors, bounds=b, data=data)
  } else {
    if (!requireNamespace("nnet", quietly=TRUE)) .rf_stop("Package 'nnet' is required for neural-network surrogates.")
    form <- stats::as.formula(paste0("`",response,"` ~ ",paste(paste0("`",factors,"`"),collapse=" + ")))
    dots <- list(...)
    if (is.null(dots$size)) dots$size <- max(3, length(factors)+1)
    if (is.null(dots$maxit)) dots$maxit <- 2000
    nnet_args <- c(list(form=form, data=data, linout=TRUE, trace=FALSE), dots)
    mod <- do.call(nnet::nnet, nnet_args)
    out <- list(method=method, engine="nnet", model=mod, response=response, factors=factors, bounds=b, data=data)
  }
  class(out) <- "rsmFlow_surrogate"
  out
}

#' @export
predict.rsmFlow_surrogate <- function(object, newdata, se.fit=FALSE, ...) {
  nd <- as.data.frame(newdata)[,object$factors,drop=FALSE]
  if (object$method == "quadratic") return(predict(object$model, newdata=nd, se.fit=se.fit, ...))
  if (object$engine == "DiceKriging") {
    pr <- stats::predict(object$model, newdata=nd, type="UK", se.compute=TRUE, cov.compute=FALSE, light.return=TRUE)
    if (se.fit) return(list(fit=as.numeric(pr$mean), se.fit=as.numeric(pr$sd)))
    return(as.numeric(pr$mean))
  }
  if (object$engine == "ranger") {
    fit <- as.numeric(predict(object$model, data=nd)$predictions)
    if (se.fit) return(list(fit=fit,se.fit=rep(NA_real_,length(fit))))
    return(fit)
  }
  if (object$engine == "mgcv") {
    pr <- stats::predict(object$model,newdata=nd,type="response",se.fit=se.fit)
    if (se.fit) return(list(fit=as.numeric(pr$fit),se.fit=as.numeric(pr$se.fit)))
    return(as.numeric(pr))
  }
  # nnet::predict.nnet uses type='raw' for numeric regression predictions.
  fit <- as.numeric(stats::predict(object$model,newdata=nd,type="raw"))
  if (se.fit) return(list(fit=fit,se.fit=rep(NA_real_,length(fit))))
  fit
}

.rf_surrogate_scalar <- function(object, x, se.fit=FALSE) {
  nd <- as.data.frame(as.list(as.numeric(x)), check.names=FALSE); names(nd) <- object$factors
  p <- predict(object, nd, se.fit=se.fit)
  if (se.fit) return(list(fit=as.numeric(p$fit)[1], se.fit=as.numeric(p$se.fit)[1]))
  as.numeric(p)[1]
}

#' Optimize an advanced surrogate inside its declared region
#' @export
rsm_surrogate_optimize <- function(object, goal=c("max","min"), method=c("L-BFGS-B","GA"), seed=123) {
  goal <- match.arg(goal); method <- match.arg(method)
  if (!inherits(object,"rsmFlow_surrogate")) .rf_stop("object must be an rsmFlow_surrogate.")
  score <- function(x) { y <- .rf_surrogate_scalar(object,x); if (goal=="max") y else -y }
  b <- object$bounds; set.seed(seed)
  if (method == "GA") {
    if (!requireNamespace("GA",quietly=TRUE)) .rf_stop("Package 'GA' is required.")
    ga <- GA::ga(type="real-valued", fitness=score, lower=b$lower, upper=b$upper, popSize=100, maxiter=700, run=150, monitor=FALSE, seed=seed)
    x <- as.numeric(ga@solution[1,])
  } else {
    grid <- .rf_design_grid(b,n=12,max_points=5000); v <- apply(grid,1,score); st <- as.numeric(grid[which.max(v),object$factors,drop=TRUE])
    op <- stats::optim(st,function(x)-score(x),method="L-BFGS-B",lower=b$lower,upper=b$upper); x <- op$par
  }
  list(solution=setNames(x,object$factors), predicted=.rf_surrogate_scalar(object,x), goal=goal, method=method, surrogate=object$method)
}

#' One-step Bayesian optimization recommendation using a GP surrogate
#'
#' Fits a Matern 5/2 Gaussian process and recommends the next experimental point
#' by expected improvement. The function proposes a point; it does not fabricate
#' the unobserved response or automatically iterate without new data.
#' @export
rsm_bayes_opt <- function(data, response, factors, goal=c("max","min"),
                          bounds=NULL, candidates=NULL, n_candidates=10000,
                          xi=0.01, seed=123, ...) {
  goal <- match.arg(goal)
  gp <- rsm_surrogate(data,response,factors,method="gp",bounds=bounds,seed=seed,...)
  set.seed(seed)
  if (is.null(candidates)) {
    k <- length(factors)
    U <- matrix(stats::runif(n_candidates*k),ncol=k)
    candidates <- sweep(U,2,gp$bounds$upper-gp$bounds$lower,"*")
    candidates <- sweep(candidates,2,gp$bounds$lower,"+")
    candidates <- as.data.frame(candidates); names(candidates) <- factors
  }
  pr <- predict(gp,candidates,se.fit=TRUE); mu <- pr$fit; s <- pmax(pr$se.fit,1e-12)
  best <- if (goal=="max") max(data[[response]],na.rm=TRUE) else min(data[[response]],na.rm=TRUE)
  imp <- if (goal=="max") mu-best-xi else best-mu-xi
  z <- imp/s
  ei <- imp*stats::pnorm(z) + s*stats::dnorm(z)
  ei[s <= 1e-11] <- 0
  i <- which.max(ei)
  list(next_point=candidates[i,factors,drop=FALSE], expected_improvement=ei[i], predicted_mean=mu[i], predicted_se=s[i], best_observed=best, goal=goal, surrogate=gp)
}
