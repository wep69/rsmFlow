library(rsmFlow)

# Core Gaussian/design-aware workflow
p <- system.file("extdata", "agronomy_rsm_nonorthogonal.csv", package="rsmFlow")
d <- read.csv(p)
f <- rsm_fit(d, "Yield", c("N","K","Irrigation"), order=2)
a <- rsm_design_audit(f)
stopifnot(a$estimable)
c <- rsm_canonical(f)
o <- rsm_optimize(f, goal="max", method="L-BFGS-B")
n <- rsm_near_optimal(f, o, tolerance=.05, n=12)
e <- rsm_economic_optimum(f, response_price=1200, factor_cost=c(N=5.5,K=4,Irrigation=900))
stopifnot(is.finite(o$predicted), nrow(n)>0, is.finite(e$profit))

# Two-factor GLM-RSM workflow
set.seed(20260813)
g <- expand.grid(x1=seq(-1,1,length.out=6),x2=seq(-1,1,length.out=6))
g$count <- rpois(nrow(g), exp(2+.2*g$x1-.1*g$x2-.25*g$x1^2-.15*g$x2^2))
fg <- rsm_glm_fit(g,"count",c("x1","x2"),family=poisson())
og <- rsm_optimize(fg,"max","L-BFGS-B")
stopifnot(inherits(fg,"rsmFlow_glm"),is.finite(og$predicted),is.finite(rsm_glm_dispersion(fg)$pearson_dispersion))

# Two-factor nonlinear workflow
nl <- expand.grid(N=seq(10,150,length.out=6),P=seq(5,80,length.out=6))
nl$Yield <- 10*nl$N/(30+nl$N)*nl$P/(20+nl$P)
fn <- rsm_nonlinear_fit(nl,"Yield",c("N","P"),model="michaelis_menten2",
                        start=c(A=10,K1=30,K2=20),engine="nls")
on <- rsm_optimize(fn,"max","L-BFGS-B")
stopifnot(inherits(fn,"rsmFlow_nonlinear"),is.finite(on$predicted),rsm_nonlinear_diagnostics(fn)$converged)

# GA is used specifically as an initial-parameter search when available.
if (requireNamespace("GA",quietly=TRUE)) {
  fga <- rsm_nonlinear_fit(nl,"Yield",c("N","P"),model="michaelis_menten2",
                           start="ga",start_control=list(popSize=20,maxiter=30,run=10),engine="nls")
  stopifnot(identical(fga$start_search$engine,"GA"))
}

# Tier-3 smoke checks are conditional on the optional backend.
if (requireNamespace("mgcv",quietly=TRUE)) {
  sg <- rsm_surrogate(g,"count",c("x1","x2"),method="gam")
  stopifnot(inherits(sg,"rsmFlow_surrogate"),length(predict(sg,g[1:3,c("x1","x2")]))==3L)
}

cat("rsmFlow 0.2.0 smoke test passed.\n")
