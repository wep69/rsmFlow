test_that("rsm_fit routes to GLM and nonlinear engines", {
  set.seed(1201)
  d <- expand.grid(x1=seq(-1,1,length.out=6),x2=seq(-1,1,length.out=6))
  d$count <- rpois(nrow(d),exp(2-.2*d$x1^2-.1*d$x2^2))
  g <- rsm_fit(d,"count",c("x1","x2"),engine="glm",family=poisson())
  expect_s3_class(g,"rsmFlow_glm")
  n <- expand.grid(N=seq(10,140,length.out=6),P=seq(5,70,length.out=6))
  n$y <- 8*n$N/(25+n$N)*n$P/(15+n$P)+rnorm(nrow(n),0,.02)
  nl <- rsm_fit(n,"y",c("N","P"),engine="nonlinear",nonlinear_model="michaelis_menten2",
                nonlinear_start=c(A=8,K1=25,K2=15),nonlinear_engine="nls")
  expect_s3_class(nl,"rsmFlow_nonlinear")
})

test_that("economic and near-optimal layers accept nonlinear models", {
  d <- expand.grid(N=seq(10,140,length.out=6),P=seq(5,70,length.out=6))
  d$y <- 8*d$N/(25+d$N)*d$P/(15+d$P)+rnorm(nrow(d),0,.02)
  nl <- rsm_nonlinear_fit(d,"y",c("N","P"),"michaelis_menten2",start=c(A=8,K1=25,K2=15),engine="nls")
  eco <- rsm_economic_optimum(nl,1000,c(N=4,P=5))
  expect_true(is.finite(eco$profit))
  nr <- rsm_near_optimal(nl,tolerance=.05,n=15)
  expect_true(nrow(nr)>0)
})

test_that("cross-engine summaries are compatible", {
  set.seed(1203)
  d <- expand.grid(x1=seq(.1,1,length.out=6),x2=seq(.1,1,length.out=6))
  d$y <- 5+d$x1+d$x2-.5*d$x1^2-.4*d$x2^2+rnorm(nrow(d),0,.03)
  a <- rsm_fit(d,"y",c("x1","x2"))
  b <- rsm_glm_fit(d,"y",c("x1","x2"),family=gaussian())
  cmp <- rsm_compare_engines(OLS=a,GLM=b)
  expect_equal(nrow(cmp),2)
  expect_true(all(c("RMSE","MAE","AIC") %in% names(cmp)))
})
