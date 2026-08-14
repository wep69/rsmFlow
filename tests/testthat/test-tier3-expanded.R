test_that("Tier-3 GAM surrogate fits when mgcv is installed", {
  skip_if_not_installed("mgcv")
  set.seed(1301)
  d <- data.frame(x1=runif(50,-1,1),x2=runif(50,-1,1)); d$y<-sin(d$x1)+cos(d$x2)
  g <- rsm_surrogate(d,"y",c("x1","x2"),method="gam")
  expect_s3_class(g,"rsmFlow_surrogate")
  expect_equal(length(predict(g,d[1:4,c("x1","x2")])),4)
})

test_that("Tier-3 GP supports uncertainty and Bayesian next-point proposal", {
  skip_if_not_installed("DiceKriging")
  set.seed(1302)
  d <- data.frame(x1=runif(40,-1,1),x2=runif(40,-1,1)); d$y<-sin(2*d$x1)+cos(2*d$x2)
  gp <- rsm_surrogate(d,"y",c("x1","x2"),method="gp")
  pr <- predict(gp,d[1:3,c("x1","x2")],se.fit=TRUE)
  expect_equal(length(pr$fit),3)
  nx <- rsm_bayes_opt(d,"y",c("x1","x2"),n_candidates=100)
  expect_true(all(c("x1","x2") %in% names(nx$next_point)))
})

test_that("Tier-3 random forest surrogate fits when ranger is installed", {
  skip_if_not_installed("ranger")
  set.seed(1303)
  d <- data.frame(x1=runif(50,-1,1),x2=runif(50,-1,1)); d$y<-sin(d$x1)+cos(d$x2)
  rf <- rsm_surrogate(d,"y",c("x1","x2"),method="rf")
  expect_equal(length(predict(rf,d[1:5,c("x1","x2")])),5)
})

test_that("Tier-3 joint TPS retains a multivariate smooth when mgcv is installed", {
  skip_if_not_installed("mgcv")
  set.seed(1304)
  d <- data.frame(x1=runif(55,-1,1),x2=runif(55,-1,1)); d$y<-sin(2*d$x1)*cos(2*d$x2)
  tp <- rsm_surrogate(d,"y",c("x1","x2"),method="tps")
  expect_s3_class(tp,"rsmFlow_surrogate")
  expect_equal(length(predict(tp,d[1:4,c("x1","x2")])),4)
})

test_that("Tier-3 neural-network prediction uses numeric raw output when nnet is installed", {
  skip_if_not_installed("nnet")
  set.seed(1305)
  d <- data.frame(x1=runif(50,-1,1),x2=runif(50,-1,1)); d$y<-sin(d$x1)+cos(d$x2)
  nn <- rsm_surrogate(d,"y",c("x1","x2"),method="nn",size=3,maxit=200)
  pr <- predict(nn,d[1:5,c("x1","x2")])
  expect_type(pr,"double")
  expect_equal(length(pr),5)
})

test_that("Tier-3 surrogates support conditional slices with three factors", {
  skip_if_not_installed("mgcv")
  set.seed(1306)
  d <- data.frame(x1=runif(70,-1,1),x2=runif(70,-1,1),x3=runif(70,-1,1))
  d$y <- sin(2*d$x1)+cos(2*d$x2)+.4*d$x3+.3*d$x1*d$x3
  g <- rsm_surrogate(d,"y",c("x1","x2","x3"),method="gam")
  sl <- rsm_slices(g,x="x1",y="x2",slice_factor="x3",values=c(-.5,0,.5),n=12)
  expect_s3_class(sl,"rsmFlow_slices")
  expect_true(all(is.finite(sl$predicted)))
})
