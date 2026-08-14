\name{rsm_optimize}
\alias{rsm_optimize}
\alias{rsm_optimum_ci}
\alias{rsm_optimum_region}
\alias{rsm_near_optimal}
\alias{rsm_robust_optimize}
\alias{print.rsmFlow_optimum}
\title{Unified bounded, global and uncertainty-aware response-surface optimization}
\usage{
rsm_optimize(object, goal = c("max", "min", "target"),
  method = c("hybrid", "L-BFGS-B", "GA", "grid", "analytic", "all"),
  target = NULL, bounds = NULL, seed = 123, grid_n = 31,
  ga_control = list(popSize = 80, maxiter = 500, run = 100),
  scale = c("response","link"))
rsm_optimum_ci(object, optimum = NULL, B = 999, conf = 0.95,
  method = NULL, optimizer = "L-BFGS-B", seed = 123)
rsm_optimum_region(uncertainty, factors = NULL, conf = NULL, n = 200)
rsm_near_optimal(object, optimum = NULL, tolerance = 0.05,
  goal = c("max", "min"), n = 41, max_points = 150000, seed = 123)
rsm_robust_optimize(object, goal = c("max", "min"), lambda = 1.96,
  method = c("L-BFGS-B", "GA"), seed = 123)
}
\arguments{
\item{object}{A supported Gaussian, GLM, nonlinear, or surrogate rsmFlow object as appropriate.}
\item{goal}{Maximize, minimize, or target.}
\item{method}{Optimizer or bootstrap method. For optimum inference, likelihood-based GLMs and homoscedastic \code{nls}/\code{nlsLM} fits default to parametric refit-and-reoptimization; quasi-family GLMs and \code{gnls} fits default to asymptotic coefficient simulation; classical Gaussian OLS defaults to residual bootstrap.}
\item{target}{Target response.}
\item{bounds}{Optional factor bounds.}
\item{seed}{Random seed.}
\item{grid_n}{Grid-search resolution.}
\item{ga_control}{GA controls.}
\item{scale}{Response scale by default; GLM link scale is available for expert use.}
\item{optimum}{Optional precomputed optimum.}
\item{B}{Bootstrap replicates.}
\item{conf}{Confidence level.}
\item{optimizer}{Optimizer used within refits.}
\item{uncertainty}{Object returned by \code{rsm_optimum_ci()}.}
\item{factors}{Optimum coordinates used for a joint region.}
\item{n}{Boundary/grid resolution.}
\item{tolerance}{Allowed relative fitted-response loss.}
\item{max_points}{Maximum candidate points.}
\item{lambda}{Prediction-standard-error multiplier.}
}
\description{Uses a common prediction interface across model engines. Analytic stationary optimization is reserved for second-order polynomial/GLM surfaces. GA and hybrid methods provide global search for nonlinear or surrogate surfaces. Bootstrap refits and reoptimizes the full model rather than adding uncertainty only after optimization.}
\examples{
set.seed(5)
d <- expand.grid(x1=seq(-1,1,length.out=7),x2=seq(-1,1,length.out=7))
d$y <- 8-.7*(d$x1-.2)^2-.4*(d$x2+.1)^2+rnorm(nrow(d),0,.05)
f <- rsm_fit(d,"y",c("x1","x2"))
rsm_optimize(f,"max","L-BFGS-B")

## Parametric GLM optimum uncertainty
mu <- exp(2-.25*(d$x1-.2)^2-.20*(d$x2+.1)^2)
## Example 2: GLM optimum uncertainty
d$count <- rpois(nrow(d),mu)
g <- rsm_glm_fit(d,"count",c("x1","x2"),family=poisson())
if (interactive()) rsm_optimum_ci(g,B=100,method="parametric")

## Nonlinear GA optimization
nn <- expand.grid(N=seq(10,160,length.out=7),P=seq(5,90,length.out=7))
nn$z <- 10*nn$N/(30+nn$N)*nn$P/(20+nn$P)
nl <- rsm_nonlinear_fit(nn,"z",c("N","P"),"michaelis_menten2",
  start=c(A=10,K1=30,K2=20),engine="nls")
rsm_optimize(nl,"max","L-BFGS-B")
}
