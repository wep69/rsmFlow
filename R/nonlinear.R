# Two-factor nonlinear response surfaces ----------------------------------

#' Available built-in nonlinear two-factor response-surface models
#' @export
rsm_nonlinear_models <- function() {
  data.frame(
    model = c("mitscherlich2_product", "mitscherlich2_offset", "gompertz2_product",
              "michaelis_menten2", "asymptotic2", "hoerl2",
              "linear_plateau2", "quadratic_plateau2", "custom"),
    parameters = c("A,k1,k2", "A,k1,k2,b1,b2", "A,b1,k1,b2,k2",
                   "A,K1,K2", "A,B1,k1,B2,k2", "A,b1,c1,b2,c2",
                   "A,s1,t1,s2,t2", "A,c1,t1,c2,t2", "user-defined"),
    interpretation = c("multiplicative saturation", "multiplicative saturation with offsets",
                       "multiplicative Gompertz saturation", "two-factor Michaelis-Menten saturation",
                       "additive asymptotic response", "two-factor Hoerl surface",
                       "increasing two-factor linear plateau", "smooth increasing two-factor quadratic plateau", "custom nonlinear formula"),
    stringsAsFactors = FALSE
  )
}

.rf_nl_spec <- function(model, response, factors, data) {
  f1 <- paste0("`", factors[1], "`"); f2 <- paste0("`", factors[2], "`"); y <- paste0("`", response, "`")
  yr <- range(data[[response]], na.rm = TRUE); ymax <- max(yr); yspan <- diff(yr); if (!is.finite(yspan) || yspan == 0) yspan <- max(abs(ymax), 1)
  r1 <- range(data[[factors[1]]], na.rm = TRUE); r2 <- range(data[[factors[2]]], na.rm = TRUE)
  s1 <- max(diff(r1), .Machine$double.eps); s2 <- max(diff(r2), .Machine$double.eps)
  eps <- 1e-8
  if (model == "mitscherlich2_product") {
    form <- stats::as.formula(paste0(y, " ~ A*(1-exp(-k1*", f1, "))*(1-exp(-k2*", f2, "))"))
    lower <- c(A = max(eps, 0.2*ymax), k1 = eps, k2 = eps)
    upper <- c(A = max(3*ymax, ymax + 5*yspan, 1), k1 = 20/s1, k2 = 20/s2)
  } else if (model == "mitscherlich2_offset") {
    form <- stats::as.formula(paste0(y, " ~ A*(1-exp(-k1*(`", factors[1], "`+b1)))*(1-exp(-k2*(`", factors[2], "`+b2)))"))
    lower <- c(A=max(eps,.2*ymax),k1=eps,k2=eps,b1=-r1[1]-2*s1,b2=-r2[1]-2*s2)
    upper <- c(A=max(3*ymax,ymax+5*yspan,1),k1=20/s1,k2=20/s2,b1=-r1[1]+2*s1,b2=-r2[1]+2*s2)
  } else if (model == "gompertz2_product") {
    form <- stats::as.formula(paste0(y, " ~ A*exp(-b1*exp(-k1*", f1, "))*exp(-b2*exp(-k2*", f2, "))"))
    lower <- c(A=max(eps,.2*ymax),b1=eps,k1=eps,b2=eps,k2=eps)
    upper <- c(A=max(3*ymax,ymax+5*yspan,1),b1=20,k1=20/s1,b2=20,k2=20/s2)
  } else if (model == "michaelis_menten2") {
    form <- stats::as.formula(paste0(y, " ~ A*", f1, "/(K1+", f1, ")*", f2, "/(K2+", f2, ")"))
    pos1 <- max(eps, max(abs(r1))); pos2 <- max(eps, max(abs(r2)))
    lower <- c(A=max(eps,.2*ymax),K1=eps,K2=eps)
    upper <- c(A=max(3*ymax,ymax+5*yspan,1),K1=10*pos1,K2=10*pos2)
  } else if (model == "asymptotic2") {
    form <- stats::as.formula(paste0(y, " ~ A-B1*exp(-k1*", f1, ")-B2*exp(-k2*", f2, ")"))
    lower <- c(A=min(yr)-5*yspan,B1=-5*yspan,k1=eps,B2=-5*yspan,k2=eps)
    upper <- c(A=max(yr)+5*yspan,B1=5*yspan,k1=20/s1,B2=5*yspan,k2=20/s2)
  } else if (model == "hoerl2") {
    form <- stats::as.formula(paste0(y, " ~ A*(b1^", f1, ")*exp(c1*", f1, ")*(b2^", f2, ")*exp(c2*", f2, ")"))
    lower <- c(A=max(eps,.01*max(abs(ymax),1)),b1=.05,c1=-10/s1,b2=.05,c2=-10/s2)
    upper <- c(A=max(10*max(abs(ymax),1),1),b1=5,c1=10/s1,b2=5,c2=10/s2)
  } else if (model == "linear_plateau2") {
    # A is the joint plateau. Positive slopes describe an increasing response
    # below each breakpoint and a constant response after the breakpoint.
    form <- stats::as.formula(paste0(y, " ~ A+s1*pmin(", f1, "-t1,0)+s2*pmin(", f2, "-t2,0)"))
    sl1 <- max(eps, 20*yspan/s1); sl2 <- max(eps, 20*yspan/s2)
    lower <- c(A=min(yr)-2*yspan,s1=eps,t1=r1[1],s2=eps,t2=r2[1])
    upper <- c(A=max(yr)+5*yspan,s1=sl1,t1=r1[2],s2=sl2,t2=r2[2])
  } else if (model == "quadratic_plateau2") {
    # Smooth quadratic plateau: derivative is zero at each breakpoint.
    # A is the joint plateau and negative curvature gives an increasing
    # response as the factor approaches its breakpoint from below.
    form <- stats::as.formula(paste0(y, " ~ A+c1*pmin(",f1,"-t1,0)^2+c2*pmin(",f2,"-t2,0)^2"))
    cv1 <- max(eps, 50*yspan/(s1^2)); cv2 <- max(eps, 50*yspan/(s2^2))
    lower <- c(A=min(yr)-2*yspan,c1=-cv1,t1=r1[1],c2=-cv2,t2=r2[1])
    upper <- c(A=max(yr)+5*yspan,c1=-eps,t1=r1[2],c2=-eps,t2=r2[2])
  } else .rf_stop("Unknown built-in nonlinear model: ", model)
  names(lower) <- names(upper)
  list(formula = form, lower = lower, upper = upper)
}

.rf_nl_eval <- function(formula, data, pars) {
  env <- new.env(parent = environment(formula) %||% parent.frame())
  for (nm in names(data)) assign(nm, data[[nm]], envir = env)
  for (nm in names(pars)) assign(nm, pars[[nm]], envir = env)
  as.numeric(eval(formula[[3]], envir = env))
}

.rf_nl_bounds <- function(start_bounds, default_lower = NULL, default_upper = NULL) {
  if (is.null(start_bounds)) {
    if (is.null(default_lower) || is.null(default_upper)) return(NULL)
    return(list(lower = default_lower, upper = default_upper))
  }
  if (is.matrix(start_bounds) || is.data.frame(start_bounds)) {
    if (ncol(start_bounds) != 2L) .rf_stop("start_bounds matrix/data frame must have two columns: lower and upper.")
    lo <- as.numeric(start_bounds[,1]); up <- as.numeric(start_bounds[,2]); names(lo) <- names(up) <- rownames(start_bounds)
  } else if (is.list(start_bounds) && all(c("lower","upper") %in% names(start_bounds))) {
    lo <- as.numeric(start_bounds$lower); up <- as.numeric(start_bounds$upper)
    nms <- names(start_bounds$lower) %||% names(start_bounds$upper); names(lo) <- names(up) <- nms
  } else .rf_stop("start_bounds must be a two-column matrix/data frame or list(lower=, upper=).")
  if (any(!is.finite(lo)) || any(!is.finite(up)) || any(lo >= up)) .rf_stop("All parameter start bounds must be finite with lower < upper.")
  list(lower = lo, upper = up)
}

#' Obtain nonlinear starting values by a genetic algorithm
#' @export
rsm_nonlinear_start_ga <- function(data, formula, start_bounds, weights = NULL,
                                   seed = 123, ga_control = list(popSize=120,maxiter=600,run=120)) {
  b <- .rf_nl_bounds(start_bounds)
  if (is.null(names(b$lower)) || any(!nzchar(names(b$lower)))) .rf_stop("Parameter bounds must be named.")
  yname <- all.vars(formula[[2]])[1]; y <- data[[yname]]
  if (is.null(weights)) weights <- rep(1, length(y))
  sse <- function(p) {
    names(p) <- names(b$lower)
    pr <- try(.rf_nl_eval(formula, data, p), silent = TRUE)
    if (inherits(pr,"try-error") || length(pr) != length(y) || any(!is.finite(pr))) return(Inf)
    sum(weights * (y-pr)^2, na.rm = TRUE)
  }
  set.seed(seed)
  if (requireNamespace("GA", quietly=TRUE)) {
    ctrl <- modifyList(list(popSize=120,maxiter=600,run=120), ga_control)
    ga <- GA::ga(type="real-valued", fitness=function(p)-sse(p), lower=b$lower, upper=b$upper,
                 popSize=ctrl$popSize,maxiter=ctrl$maxiter,run=ctrl$run,monitor=FALSE,seed=seed)
    st <- as.numeric(ga@solution[1,]); names(st) <- names(b$lower)
    return(list(start=st,SSE=sse(st),engine="GA",ga=ga,bounds=b))
  }
  .rf_warn("Package 'GA' is unavailable; using random multistart search instead.")
  rsm_nonlinear_start_multistart(data, formula, b, weights=weights, n_start=max(500, ga_control$popSize %||% 120), seed=seed)
}

#' Obtain nonlinear starting values by bounded random multistart search
#' @export
rsm_nonlinear_start_multistart <- function(data, formula, start_bounds, weights = NULL,
                                           n_start = 500, seed = 123) {
  b <- .rf_nl_bounds(start_bounds)
  yname <- all.vars(formula[[2]])[1]; y <- data[[yname]]
  if (is.null(weights)) weights <- rep(1, length(y))
  set.seed(seed); k <- length(b$lower)
  U <- matrix(stats::runif(n_start*k), ncol=k)
  P <- sweep(U,2,b$upper-b$lower,"*"); P <- sweep(P,2,b$lower,"+")
  ss <- apply(P,1,function(p){names(p)<-names(b$lower); pr<-try(.rf_nl_eval(formula,data,p),silent=TRUE); if(inherits(pr,"try-error")||any(!is.finite(pr))) Inf else sum(weights*(y-pr)^2,na.rm=TRUE)})
  i <- which.min(ss); st <- P[i,]; names(st) <- names(b$lower)
  list(start=st,SSE=ss[i],engine="random_multistart",evaluated=n_start,bounds=b)
}

#' Fit a two-factor nonlinear response surface
#'
#' @param data Data frame.
#' @param response Numeric response column.
#' @param factors Exactly two quantitative factors.
#' @param model Built-in model name or "custom".
#' @param formula Required for model="custom"; optional override otherwise.
#' @param start Named numeric starting values, or "ga", "multistart", "auto".
#' @param start_bounds Named parameter bounds used for GA/multistart and bounded nls.
#' @param engine nlsLM, nls, or gnls. nlsLM and gnls are optional backends.
#' @param bounds Factor-space bounds.
#' @param weights Optional observation weights for nls/nlsLM.
#' @param variance For gnls: constant, power, exponential, or an nlme varFunc object.
#' @param correlation Optional nlme corStruct for gnls.
#' @param n_start Number of random starts when requested.
#' @param seed Random seed.
#' @param ... Additional backend arguments.
#' @export
rsm_nonlinear_fit <- function(data, response, factors,
                              model = c("mitscherlich2_product","mitscherlich2_offset","gompertz2_product",
                                        "michaelis_menten2","asymptotic2","hoerl2","linear_plateau2","quadratic_plateau2","custom"),
                              formula = NULL, start = "ga", start_bounds = NULL,
                              engine = c("nlsLM","nls","gnls"), bounds = NULL,
                              weights = NULL, variance = "constant", correlation = NULL,
                              n_start = 500, start_control = list(popSize=120,maxiter=600,run=120),
                              seed = 123, ...) {
  model <- match.arg(model); engine <- match.arg(engine)
  if (!is.data.frame(data)) data <- as.data.frame(data)
  if (!response %in% names(data) || !is.numeric(data[[response]])) .rf_stop("response must name a numeric column.")
  if (length(factors) != 2L) .rf_stop("rsm_nonlinear_fit() currently targets exactly two quantitative factors.")
  .rf_assert_numeric_factors(data, factors)
  spec <- NULL
  if (model != "custom") spec <- .rf_nl_spec(model,response,factors,data)
  if (is.null(formula)) {
    if (is.null(spec)) .rf_stop("formula= is required when model='custom'.")
    formula <- spec$formula
  }
  pb <- .rf_nl_bounds(start_bounds, if(!is.null(spec)) spec$lower else NULL, if(!is.null(spec)) spec$upper else NULL)
  if (is.character(start)) {
    mode <- match.arg(start, c("ga","multistart","auto"))
    if (is.null(pb)) .rf_stop("start_bounds= is required for automatic/GA starts with a custom nonlinear model.")
    sres <- if (mode == "multistart") rsm_nonlinear_start_multistart(data,formula,pb,weights,n_start,seed) else rsm_nonlinear_start_ga(data,formula,pb,weights,seed,start_control)
    start_vec <- sres$start
  } else {
    start_vec <- as.numeric(start); names(start_vec) <- names(start)
    if (is.null(names(start_vec)) || any(!nzchar(names(start_vec)))) .rf_stop("Numeric start values must be named.")
    sres <- list(start=start_vec,engine="user",SSE=NA_real_,bounds=pb)
  }
  if (!is.null(pb)) {
    if (!all(names(start_vec) %in% names(pb$lower))) .rf_stop("start names and parameter bounds are inconsistent.")
    lo <- pb$lower[names(start_vec)]; up <- pb$upper[names(start_vec)]
    start_vec <- pmin(pmax(start_vec,lo),up)
  } else { lo <- rep(-Inf,length(start_vec)); up <- rep(Inf,length(start_vec)); names(lo)<-names(up)<-names(start_vec) }

  variance_obj <- variance
  if (engine == "gnls") {
    if (!is.null(weights)) .rf_stop("For engine='gnls', specify heteroscedasticity through variance= rather than observation weights=; separate prior weights are not silently translated to an nlme variance function.")
    if (!requireNamespace("nlme",quietly=TRUE)) .rf_stop("Package 'nlme' is required for engine='gnls'.")
    if (is.character(variance)) variance_obj <- switch(match.arg(variance,c("constant","power","exponential")), constant=NULL, power=nlme::varPower(), exponential=nlme::varExp())
    fit <- nlme::gnls(formula, data=data, start=start_vec, weights=variance_obj, correlation=correlation, ...)
  } else if (engine == "nlsLM") {
    if (!requireNamespace("minpack.lm",quietly=TRUE)) {
      .rf_warn("Package 'minpack.lm' is unavailable; falling back to stats::nls().")
      engine <- "nls"
    }
    # Ensure nls/nlsLM can resolve 'weights' by setting formula env to this frame
    if (!is.null(weights)) environment(formula) <- environment()
    fit <- if (is.null(weights)) {
      minpack.lm::nlsLM(formula, data=data, start=start_vec, lower=lo, upper=up, ...)
    } else {
      minpack.lm::nlsLM(formula, data=data, start=start_vec, lower=lo, upper=up, weights=weights, ...)
    }
  }
  if (engine == "nls") {
    if (!is.null(weights)) environment(formula) <- environment()
    fit <- if (is.null(weights)) {
      stats::nls(formula, data=data, start=start_vec, algorithm="port", lower=lo, upper=up, control=stats::nls.control(warnOnly=TRUE,maxiter=500), ...)
    } else {
      stats::nls(formula, data=data, start=start_vec, algorithm="port", lower=lo, upper=up, weights=weights, control=stats::nls.control(warnOnly=TRUE,maxiter=500), ...)
    }
  }

  out <- list(call=match.call(),data=data,response=response,factors=factors,
              model_name=model,formula=formula,model=fit,engine=engine,
              bounds=.rf_bounds(data,factors,bounds),parameter_bounds=pb,
              start=start_vec,start_search=sres,weights=weights,
              variance_spec=variance,correlation_spec=correlation,created=Sys.time())
  class(out) <- c("rsmFlow_nonlinear","rsmFlow_model")
  out
}

#' @export
predict.rsmFlow_nonlinear <- function(object, newdata = NULL, se.fit = FALSE, level = 0.95, ...) {
  if (is.null(newdata)) newdata <- object$data
  cf <- if (!is.null(object$coefficient_override)) object$coefficient_override else stats::coef(object$model)
  fit <- if (!is.null(object$coefficient_override)) as.numeric(.rf_nl_eval(object$formula,newdata,cf)) else as.numeric(stats::predict(object$model,newdata=newdata,...))
  if (!se.fit) return(fit)
  if (!is.null(object$coefficient_override)) return(list(fit=fit,se.fit=rep(NA_real_,length(fit))))
  V <- tryCatch(stats::vcov(object$model),error=function(e)NULL)
  if (is.null(V)) return(list(fit=fit,se.fit=rep(NA_real_,length(fit))))
  # Delta-method Jacobian of predictions with respect to nonlinear parameters.
  eps <- sqrt(.Machine$double.eps)^(1/2)
  J <- matrix(NA_real_,nrow(newdata),length(cf)); colnames(J)<-names(cf)
  for(j in seq_along(cf)) {
    h <- eps*max(abs(cf[j]),1); cp<-cm<-cf; cp[j]<-cp[j]+h; cm[j]<-cm[j]-h
    pp <- .rf_nl_eval(object$formula,newdata,cp); pm <- .rf_nl_eval(object$formula,newdata,cm)
    J[,j] <- (pp-pm)/(2*h)
  }
  vv <- rowSums((J %*% V) * J); se <- sqrt(pmax(vv,0))
  list(fit=fit,se.fit=se,lower=fit-stats::qnorm((1+level)/2)*se,upper=fit+stats::qnorm((1+level)/2)*se)
}

#' Diagnostics and identifiability checks for nonlinear response surfaces
#' @export
rsm_nonlinear_diagnostics <- function(object) {
  if (!inherits(object,"rsmFlow_nonlinear")) .rf_stop("object must be an rsmFlow_nonlinear.")
  cf <- stats::coef(object$model); n <- nrow(object$data); p <- length(cf)
  pred <- as.numeric(stats::predict(object$model,newdata=object$data)); res <- object$data[[object$response]]-pred
  J <- matrix(NA_real_,n,p); colnames(J)<-names(cf)
  for(j in seq_along(cf)) {
    h <- 1e-5*max(abs(cf[j]),1); cp<-cm<-cf; cp[j]<-cp[j]+h; cm[j]<-cm[j]-h
    J[,j] <- (.rf_nl_eval(object$formula,object$data,cp)-.rf_nl_eval(object$formula,object$data,cm))/(2*h)
  }
  sv <- svd(J,nu=0,nv=0)$d
  V <- tryCatch(stats::vcov(object$model),error=function(e)NULL)
  corpar <- if(!is.null(V)) stats::cov2cor(V) else NULL
  conv <- if (inherits(object$model,"nls")) isTRUE(object$model$convInfo$isConv) else TRUE
  list(converged=conv,engine=object$engine,model=object$model_name,
       coefficients=cf,RSS=sum(res^2),RMSE=sqrt(mean(res^2)),
       logLik=tryCatch(as.numeric(stats::logLik(object$model)),error=function(e)NA_real_),
       AIC=tryCatch(stats::AIC(object$model),error=function(e)NA_real_),
       BIC=tryCatch(stats::BIC(object$model),error=function(e)NA_real_),
       jacobian_singular_values=sv,
       jacobian_condition=if(length(sv)&&min(sv)>0) max(sv)/min(sv) else Inf,
       parameter_correlation=corpar,
       start_engine=object$start_search$engine,
       start_SSE=object$start_search$SSE,
       warning=if(length(sv)&&min(sv)/max(sv)<1e-6) "Weak local parameter identifiability is indicated by the prediction Jacobian." else NULL)
}
