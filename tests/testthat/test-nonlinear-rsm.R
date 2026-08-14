test_that("built-in nonlinear registry and explicit-start nls fit work", {
  expect_true(all(c("mitscherlich2_product","michaelis_menten2","quadratic_plateau2") %in% rsm_nonlinear_models()$model))
  set.seed(1101)
  d <- expand.grid(N=seq(10,160,length.out=7),P=seq(5,90,length.out=7))
  d$y <- 10*d$N/(30+d$N)*d$P/(20+d$P)+rnorm(nrow(d),0,.03)
  f <- rsm_nonlinear_fit(d,"y",c("N","P"),"michaelis_menten2",
                         start=c(A=10,K1=30,K2=20),engine="nls")
  expect_s3_class(f,"rsmFlow_nonlinear")
  dg <- rsm_nonlinear_diagnostics(f)
  expect_true(is.finite(dg$RMSE))
  expect_true(is.finite(dg$jacobian_condition))
})

test_that("bounded multistart provides finite nonlinear starting values", {
  set.seed(1102)
  d <- expand.grid(N=seq(10,150,length.out=6),P=seq(5,80,length.out=6))
  d$y <- 9*d$N/(25+d$N)*d$P/(18+d$P)+rnorm(nrow(d),0,.04)
  f <- rsm_nonlinear_fit(d,"y",c("N","P"),"michaelis_menten2",
                         start="multistart",n_start=80,engine="nls")
  expect_true(all(is.finite(f$start)))
  expect_equal(f$start_search$engine,"random_multistart")
})

test_that("GA can be used specifically for nonlinear starting parameters", {
  skip_if_not_installed("GA")
  set.seed(1103)
  d <- expand.grid(N=seq(10,150,length.out=6),P=seq(5,80,length.out=6))
  d$y <- 11*(1-exp(-.025*d$N))*(1-exp(-.04*d$P))+rnorm(nrow(d),0,.05)
  f <- rsm_nonlinear_fit(d,"y",c("N","P"),"mitscherlich2_product",
                         start="ga",start_control=list(popSize=20,maxiter=30,run=10),engine="nls")
  expect_equal(f$start_search$engine,"GA")
  expect_true(all(is.finite(f$start_search$start)))
})

test_that("gnls supports explicit variance structures when nlme is installed", {
  skip_if_not_installed("nlme")
  set.seed(1104)
  d <- expand.grid(N=seq(10,150,length.out=6),P=seq(5,80,length.out=6))
  mu <- 10*d$N/(30+d$N)*d$P/(20+d$P)
  d$y <- mu + rnorm(nrow(d),0,.02+.02*mu)
  f <- rsm_nonlinear_fit(d,"y",c("N","P"),"michaelis_menten2",
                         start=c(A=10,K1=30,K2=20),engine="gnls",variance="power")
  expect_s3_class(f,"rsmFlow_nonlinear")
  expect_equal(f$engine,"gnls")
})

test_that("smooth quadratic plateau uses plateau and breakpoint parameters", {
  set.seed(1105)
  d <- expand.grid(N=seq(0,160,length.out=8),P=seq(0,100,length.out=8))
  d$y <- 10 - 0.00022*pmin(d$N-120,0)^2 - 0.00035*pmin(d$P-70,0)^2 + rnorm(nrow(d),0,.02)
  f <- rsm_nonlinear_fit(d,"y",c("N","P"),"quadratic_plateau2",
                         start=c(A=10,c1=-0.0002,t1=120,c2=-0.0003,t2=70),engine="nls")
  expect_s3_class(f,"rsmFlow_nonlinear")
  expect_equal(names(coef(f$model)),c("A","c1","t1","c2","t2"))
  expect_true(all(is.finite(predict(f,d[1:5,]))))
})

test_that("gnls optimum uncertainty defaults to coefficient simulation", {
  skip_if_not_installed("nlme")
  set.seed(1106)
  d <- expand.grid(N=seq(10,150,length.out=6),P=seq(5,80,length.out=6))
  mu <- 10*d$N/(30+d$N)*d$P/(20+d$P)
  d$y <- mu + rnorm(nrow(d),0,.02+.01*mu)
  f <- rsm_nonlinear_fit(d,"y",c("N","P"),"michaelis_menten2",
                         start=c(A=10,K1=30,K2=20),engine="gnls",variance="power")
  u <- rsm_optimum_ci(f,B=35,optimizer="L-BFGS-B",seed=22)
  expect_equal(u$method,"coefficient")
  expect_gt(u$B_valid,0)
  expect_error(rsm_optimum_ci(f,B=35,method="parametric"),"gnls")
})
