\name{rsm_compare_engines}
\alias{rsm_compare_engines}
\alias{rsm_compare_optima}
\title{Compare response-surface engines and their optima}
\usage{
rsm_compare_engines(...)
rsm_compare_optima(...)
}
\arguments{\item{...}{Named fitted rsmFlow models or optimum objects.}}
\description{Produces compatible descriptive summaries across Gaussian RSM, GLM-RSM, nonlinear surfaces, and expert surrogates. AIC/BIC are omitted for quasi-likelihood fits instead of being ranked as if directly likelihood-comparable. Optimum comparison reports factor coordinates, prediction, and optimizer.}
\examples{
set.seed(20)
d <- expand.grid(x1=seq(.1,1,length.out=7),x2=seq(.1,1,length.out=7))
d$y <- 5 + d$x1 + d$x2 - .6*d$x1^2 - .4*d$x2^2 + rnorm(nrow(d),0,.05)
a <- rsm_fit(d,"y",c("x1","x2"))
b <- rsm_glm_fit(d,"y",c("x1","x2"),family=gaussian())
rsm_compare_engines(OLS=a,GLM=b)

## Example 2: compare bounded optima
o1 <- rsm_optimize(a,"max","L-BFGS-B")
o2 <- rsm_optimize(b,"max","L-BFGS-B")
rsm_compare_optima(OLS=o1,GLM=o2)

## Third example: add a nonlinear fit
n <- d; n$z <- 8*n$x1/(.25+n$x1)*n$x2/(.3+n$x2)+rnorm(nrow(n),0,.03)
nl <- rsm_nonlinear_fit(n,"z",c("x1","x2"),"michaelis_menten2",
  start=c(A=8,K1=.25,K2=.3),engine="nls")
rsm_compare_engines(Polynomial=a,Nonlinear=nl)
}
