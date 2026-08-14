\name{rsm_nonlinear_fit}
\alias{rsm_nonlinear_fit}
\alias{rsm_nonlinear_models}
\alias{rsm_nonlinear_start_ga}
\alias{rsm_nonlinear_start_multistart}
\alias{rsm_nonlinear_diagnostics}
\alias{predict.rsmFlow_nonlinear}
\alias{print.rsmFlow_nonlinear}
\alias{summary.rsmFlow_nonlinear}
\alias{plot.rsmFlow_nonlinear}
\title{Two-factor nonlinear response surfaces with GA or multistart initialization}
\usage{
rsm_nonlinear_models()
rsm_nonlinear_start_ga(data, formula, start_bounds, weights = NULL,
  seed = 123, ga_control = list(popSize=120,maxiter=600,run=120))
rsm_nonlinear_start_multistart(data, formula, start_bounds, weights = NULL,
  n_start = 500, seed = 123)
rsm_nonlinear_fit(data, response, factors, model = c(
  "mitscherlich2_product", "mitscherlich2_offset", "gompertz2_product",
  "michaelis_menten2", "asymptotic2", "hoerl2",
  "linear_plateau2", "quadratic_plateau2", "custom"),
  formula = NULL, start = "ga", start_bounds = NULL,
  engine = c("nlsLM","nls","gnls"), bounds = NULL, weights = NULL,
  variance = "constant", correlation = NULL, n_start = 500,
  start_control = list(popSize=120,maxiter=600,run=120), seed = 123, ...)
rsm_nonlinear_diagnostics(object)
}
\arguments{
\item{data}{Data frame.}
\item{response}{Numeric response column.}
\item{factors}{Exactly two quantitative factors.}
\item{model}{Built-in nonlinear surface or \code{"custom"}.}
\item{formula}{Custom nonlinear formula or an override of a built-in formula.}
\item{start}{Named numeric parameter vector, \code{"ga"}, \code{"multistart"}, or \code{"auto"}.}
\item{start_bounds}{Named lower/upper parameter bounds. Built-in models provide defaults; custom models require them for automatic starts.}
\item{engine}{\code{nlsLM}, \code{nls}, or \code{gnls}.}
\item{bounds}{Factor-space region used for downstream optimization.}
\item{weights}{Optional nonlinear least-squares weights.}
\item{variance}{For \code{gnls}: constant, power, exponential, or an \code{nlme} variance object.}
\item{correlation}{Optional \code{nlme} correlation structure for \code{gnls}.}
\item{n_start}{Number of random starts.}
\item{start_control,ga_control}{Controls for genetic-algorithm initial-value search.}
\item{seed}{Random seed.}
\item{object}{An \code{rsmFlow_nonlinear}.}
\item{...}{Additional backend arguments.}
}
\description{
Fits mechanistic or semi-empirical two-factor nonlinear surfaces. Built-ins include two-factor Mitscherlich, Gompertz, Michaelis-Menten, asymptotic, Hoerl, and increasing linear plateau and smooth increasing quadratic plateau structures. Genetic algorithms search the parameter space for starting values before nonlinear least-squares fitting; multistart and explicit starts remain available. \code{gnls} adds unequal-variance and correlated-error structures.
}
\examples{
## Example 1: Mitscherlich product, using explicit starts for a fast example
set.seed(10)
d <- expand.grid(N=seq(10,180,length.out=8), P=seq(5,100,length.out=7))
d$y <- 12*(1-exp(-.025*d$N))*(1-exp(-.04*d$P)) + rnorm(nrow(d),0,.15)
fm <- rsm_nonlinear_fit(d,"y",c("N","P"), model="mitscherlich2_product",
  start=c(A=12,k1=.02,k2=.03), engine="nls")
rsm_nonlinear_diagnostics(fm)
rsm_optimize(fm,"max","L-BFGS-B")

## Example 2: Michaelis-Menten with multistart
set.seed(11)
d$y2 <- 15*d$N/(35+d$N)*d$P/(22+d$P) + rnorm(nrow(d),0,.12)
fm2 <- rsm_nonlinear_fit(d,"y2",c("N","P"), model="michaelis_menten2",
  start="multistart", n_start=100, engine="nls")
rsm_near_optimal(fm2, tolerance=.05)

## Example 3: GA initial values when GA is installed
if (requireNamespace("GA", quietly=TRUE)) {
  fm3 <- rsm_nonlinear_fit(d,"y",c("N","P"), model="mitscherlich2_product",
    start="ga", start_control=list(popSize=30,maxiter=60,run=20), engine="nls")
  fm3$start_search$start
}
}
