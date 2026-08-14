test_that("structured cross-validation returns finite metrics", {
  g <- expand.grid(x1=seq(-1,1,length.out=5), x2=seq(-1,1,length.out=5), block=1:4)
  g$y <- 5 + g$x1 - g$x1^2 - .5*g$x2^2 + rep(c(-.15,-.05,.05,.15), length.out=nrow(g))
  g$block <- factor(g$block)
  fit <- rsm_fit(g,"y",c("x1","x2"),2,block="block")
  cv <- suppressWarnings(rsm_cv(fit, folds=2, group="block"))
  expect_true(all(is.finite(cv$metrics)))
})

test_that("feasible power WLS retains rsmFlow fit semantics", {
  set.seed(1)
  g <- expand.grid(x1=seq(-1,1,length.out=7), x2=seq(-1,1,length.out=7))
  mu <- 5 + g$x1 - g$x1^2 - .5*g$x2^2
  g$y <- mu + rnorm(nrow(g),0,.05 + .15*abs(mu))
  fit <- rsm_fit(g,"y",c("x1","x2"),2,estimator="wls_power")
  expect_s3_class(fit,"rsmFlow_fit")
  expect_false(is.null(fit$variance_model))
})
