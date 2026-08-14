\name{rsm_glm_fit}
\alias{rsm_glm_fit}
\alias{predict.rsmFlow_glm}
\alias{print.rsmFlow_glm}
\alias{summary.rsmFlow_glm}
\alias{plot.rsmFlow_glm}
\alias{rsm_glm_dispersion}
\alias{rsm_glm_diagnostics}
\alias{rsm_glm_lack_of_fit}
\alias{rsm_glm_canonical}
\title{Two-factor generalized response-surface models}
\usage{
rsm_glm_fit(data, response, factors, order = 2, block = NULL,
  family = stats::gaussian(), bounds = NULL, weights = NULL,
  offset = NULL, offset_reference = 0, na.action = stats::na.omit, ...)
rsm_glm_dispersion(object)
rsm_glm_diagnostics(object)
rsm_glm_lack_of_fit(object)
rsm_glm_canonical(object, tol = 1e-7)
}
\arguments{
\item{data}{Data frame.}
\item{response}{Response column name.}
\item{factors}{Exactly two quantitative factor names.}
\item{order}{First- or second-order surface on the link scale.}
\item{block}{Optional additive block factor.}
\item{family}{A GLM family object/function or supported string. Negative binomial uses \code{MASS::glm.nb}.}
\item{bounds}{Declared factor region.}
\item{weights}{Optional prior weights, including binomial trial totals when proportions are used.}
\item{offset}{Optional observation-level link-scale offset. It is encoded as an explicit \code{offset()} term for compatibility with both \code{glm} and \code{glm.nb}.}
\item{offset_reference}{Link-scale offset used at new prediction/optimization points when an offset was supplied; zero is the unit-exposure reference for a log offset.}
\item{na.action}{Missing-value action.}
\item{...}{Additional backend arguments.}
\item{object}{An \code{rsmFlow_glm}.}
\item{tol}{Numerical tolerance for response-scale Hessian classification.}
}
\description{
Fits two-factor generalized response surfaces using Gaussian, Poisson, quasi-Poisson, binomial, quasi-binomial, Gamma, inverse-Gaussian, or optional negative-binomial families. Optimization and graphics use the response scale by default. Canonical classification is verified on the response scale rather than inferred solely from the link-scale quadratic form.
}
\value{\code{rsm_glm_fit()} returns an \code{rsmFlow_glm}. Diagnostic functions return structured lists.}
\examples{
## Example 1: Poisson count surface
set.seed(1)
d <- expand.grid(x1=seq(-1,1,length.out=7), x2=seq(-1,1,length.out=7))
mu <- exp(2 + .35*d$x1 - .25*d$x2 - .30*d$x1^2 - .20*d$x2^2)
d$count <- rpois(nrow(d), mu)
gp <- rsm_glm_fit(d, "count", c("x1","x2"), family=poisson())
rsm_glm_dispersion(gp)
rsm_optimize(gp, "max", "L-BFGS-B")

## Example 2: binomial proportion with trial weights
set.seed(2)
d$trials <- 30
eta <- -.5 + .8*d$x1 - .4*d$x2 - .5*d$x1^2
p <- plogis(eta)
d$success <- rbinom(nrow(d), d$trials, p)
d$prop <- d$success/d$trials
gb <- rsm_glm_fit(d, "prop", c("x1","x2"), family=binomial(), weights=d$trials)
rsm_glm_diagnostics(gb)

## Example 3: Gamma response surface
set.seed(3)
mg <- exp(1.5 + .2*d$x1 + .15*d$x2 - .18*d$x1^2 - .12*d$x2^2)
d$positive <- rgamma(nrow(d), shape=8, scale=mg/8)
gg <- rsm_glm_fit(d, "positive", c("x1","x2"), family=Gamma(link="log"))
rsm_plot(gg, type="contour")
}
