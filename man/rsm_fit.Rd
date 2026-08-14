\name{rsm_fit}
\alias{rsm_fit}
\alias{predict.rsmFlow_fit}
\alias{print.rsmFlow_fit}
\alias{summary.rsmFlow_fit}
\alias{plot.rsmFlow_fit}
\title{Unified entry point for Gaussian, GLM, and nonlinear response surfaces}
\usage{
rsm_fit(data, response, factors, order = 2, block = NULL,
  estimator = c("ols", "wls_power", "robust"), weights = NULL,
  bounds = NULL, coding = NULL, na.action = stats::na.omit,
  engine = c("lm", "glm", "nonlinear"), family = NULL,
  nonlinear_model = "mitscherlich2_product", nonlinear_formula = NULL,
  nonlinear_start = "ga", nonlinear_start_bounds = NULL,
  nonlinear_engine = "nlsLM", ...)
}
\arguments{
\item{data}{Data frame.}
\item{response}{Response column name.}
\item{factors}{Two or more quantitative factors for Gaussian RSM; GLM/nonlinear modules currently use exactly two.}
\item{order}{First- or second-order polynomial order for LM/GLM engines.}
\item{block}{Optional additive block factor for LM/GLM.}
\item{estimator}{OLS, feasible power-variance WLS, or optional robust regression for engine \code{"lm"}.}
\item{weights}{Optional weights.}
\item{bounds}{Experimental/decision region.}
\item{coding}{Optional coding metadata for polynomial RSM.}
\item{na.action}{Missing-data action.}
\item{engine}{\code{"lm"}, \code{"glm"}, or \code{"nonlinear"}.}
\item{family}{GLM family when \code{engine="glm"}.}
\item{nonlinear_model}{Built-in nonlinear model name.}
\item{nonlinear_formula}{Custom nonlinear formula.}
\item{nonlinear_start}{GA, multistart, automatic, or explicit starting values passed through the nonlinear workflow.}
\item{nonlinear_start_bounds}{Parameter bounds for custom automatic starts.}
\item{nonlinear_engine}{\code{nlsLM}, \code{nls}, or \code{gnls}.}
\item{...}{Additional selected-engine arguments.}
}
\description{Provides a backward-compatible Gaussian RSM entry point and optional routing to the two-factor GLM and nonlinear modules. Dedicated functions \code{rsm_glm_fit()} and \code{rsm_nonlinear_fit()} expose the same capabilities more explicitly.}
\examples{
## Example 1: classical second-order RSM
set.seed(1)
g <- expand.grid(x1=seq(-1,1,length.out=5),x2=seq(-1,1,length.out=5))
g$y <- 10 + g$x1 - 2*g$x1^2 - g$x2^2 + rnorm(nrow(g),0,.05)
f1 <- rsm_fit(g,"y",c("x1","x2"))

## Example 2: Poisson GLM-RSM through the unified entry point
g$count <- rpois(nrow(g),exp(2+.2*g$x1-.15*g$x2-.2*g$x1^2))
f2 <- rsm_fit(g,"count",c("x1","x2"),engine="glm",family=poisson())

## Example 3: nonlinear Michaelis-Menten surface
d <- transform(expand.grid(N=seq(10,150,length.out=7),P=seq(5,80,length.out=7)),
  resp=10*N/(30+N)*P/(20+P))
f3 <- rsm_fit(d,"resp",c("N","P"),engine="nonlinear",
  nonlinear_model="michaelis_menten2",nonlinear_start=c(A=10,K1=30,K2=20),
  nonlinear_engine="nls")
}
