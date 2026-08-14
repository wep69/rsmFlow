\name{rsm_economic_optimum}
\alias{rsm_economic_optimum}
\title{Economic optimum of Gaussian, GLM, nonlinear, or surrogate response surfaces}
\usage{
rsm_economic_optimum(object, response_price, factor_cost, fixed_cost = 0,
  baseline = NULL, method = c("L-BFGS-B", "GA"), seed = 123)
}
\arguments{
\item{object}{A supported fitted rsmFlow response model.}
\item{response_price}{Numeric price per response unit or function mapping predicted response to revenue.}
\item{factor_cost}{Named marginal costs or named cost functions for every quantitative factor.}
\item{fixed_cost}{Constant cost.}
\item{baseline}{Optional named cost baseline.}
\item{method}{Bounded L-BFGS-B or GA.}
\item{seed}{Random seed.}
}
\description{Maximizes fitted revenue minus declared factor and fixed costs inside the experimental region and reports the biological maximum for comparison. The function is deliberately a limited decision-support layer rather than a whole-farm economics model.}
\examples{
## Example 1: polynomial yield response
N <- seq(0,200,length.out=9); P <- seq(0,120,length.out=8)
d <- expand.grid(N=N,P=P); d$yield <- 4+.04*d$N+.03*d$P-.00015*d$N^2-.0002*d$P^2
f <- rsm_fit(d,"yield",c("N","P"))
rsm_economic_optimum(f,response_price=1200,factor_cost=c(N=5.5,P=4))

## Example 2: nonlinear production response
nd <- transform(expand.grid(N=seq(10,180,length.out=8),P=seq(5,100,length.out=7)),
  yield=10*N/(30+N)*P/(20+P))
nl <- rsm_nonlinear_fit(nd,"yield",c("N","P"),"michaelis_menten2",
  start=c(A=10,K1=30,K2=20),engine="nls")
rsm_economic_optimum(nl,response_price=1000,factor_cost=c(N=5,P=6))

## Example 3: nonlinear factor cost function
rsm_economic_optimum(f,response_price=1200,
  factor_cost=list(N=function(x) 4*x + .01*x^2, P=4))
}
