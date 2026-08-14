\name{rsm_surrogate}
\alias{rsm_surrogate}
\alias{rsm_surrogate_optimize}
\alias{rsm_bayes_opt}
\alias{predict.rsmFlow_surrogate}
\title{Tier-3 surrogate and Bayesian-optimization layer}
\usage{
rsm_surrogate(data, response, factors,
  method = c("quadratic", "gam", "gp", "tps", "rf", "nn"),
  bounds = NULL, seed = 123, ...)
rsm_surrogate_optimize(object, goal = c("max", "min"),
  method = c("L-BFGS-B", "GA"), seed = 123)
rsm_bayes_opt(data, response, factors, goal = c("max", "min"),
  bounds = NULL, candidates = NULL, n_candidates = 10000,
  xi = 0.01, seed = 123, ...)
}
\arguments{
\item{data}{Data frame containing response and quantitative factors.}
\item{response}{Numeric response column name.}
\item{factors}{Two or more quantitative factor names.}
\item{method}{Surrogate or optimizer choice, depending on function.}
\item{bounds}{Declared factor region.}
\item{seed}{Random seed.}
\item{...}{Additional selected-engine arguments.}
\item{object}{An \code{rsmFlow_surrogate}.}
\item{goal}{Maximize or minimize.}
\item{candidates}{Optional candidate set.}
\item{n_candidates}{Random candidate count if a set is not supplied.}
\item{xi}{Expected-improvement exploration margin.}
}
\description{Expert Tier-3 alternatives used explicitly when classical quadratic adequacy is scientifically insufficient: Gaussian processes, GAMs with main smooths plus pairwise tensor interactions, joint multivariate thin-plate smooths, random forests, neural networks, and one-step Bayesian optimization by expected improvement. These methods do not replace the design-aware RSM workflow automatically.}
\examples{
set.seed(30)
d <- data.frame(x1=runif(60,-1,1),x2=runif(60,-1,1))
d$y <- sin(2*d$x1)+cos(2*d$x2)+rnorm(60,0,.05)

## Example 1: GAM/TPS
if (requireNamespace("mgcv", quietly=TRUE)) {
  g <- rsm_surrogate(d,"y",c("x1","x2"),method="gam")
  tp <- rsm_surrogate(d,"y",c("x1","x2"),method="tps")
  rsm_surrogate_optimize(g,"max")
  predict(tp,d[1:3,c("x1","x2")])
}

## Example 2: Gaussian process and one-step Bayesian optimization
if (requireNamespace("DiceKriging", quietly=TRUE)) {
  gp <- rsm_surrogate(d,"y",c("x1","x2"),method="gp")
  predict(gp,d[1:3,c("x1","x2")],se.fit=TRUE)
  next_run <- rsm_bayes_opt(d,"y",c("x1","x2"),n_candidates=500)
}

## Example 3: random forest or neural network
if (requireNamespace("ranger", quietly=TRUE)) {
  rf <- rsm_surrogate(d,"y",c("x1","x2"),method="rf")
  rsm_surrogate_optimize(rf,"max")
}
if (requireNamespace("nnet", quietly=TRUE)) {
  nn <- rsm_surrogate(d,"y",c("x1","x2"),method="nn",size=3,maxit=200)
  predict(nn,d[1:3,c("x1","x2")])
}
}
