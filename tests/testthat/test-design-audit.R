test_that("rank deficiency is detected", {
  d <- data.frame(x1=c(-1,0,1,-1,0,1), x2=c(-1,0,1,-1,0,1))
  d$y <- 1 + d$x1
  fit <- rsm_fit(d, "y", c("x1","x2"), order=2)
  a <- rsm_design_audit(fit, rotatability=FALSE)
  expect_false(a$estimable)
  expect_equal(a$status, "non-estimable")
})

test_that("augmentation returns requested new runs", {
  g <- expand.grid(x1=c(-1,0,1), x2=c(-1,0,1))
  g$y <- 5 - g$x1^2 - g$x2^2
  fit <- rsm_fit(g, "y", c("x1","x2"), order=2)
  aug <- rsm_augment(fit, n_add=3, grid_n=5)
  expect_equal(nrow(aug), 3)
})
