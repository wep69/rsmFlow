test_that("second-order fit recovers a known interior maximum", {
  g <- expand.grid(x1 = seq(-1,1,length.out=5), x2 = seq(-1,1,length.out=5))
  g$y <- 10 + 2*g$x1 - g$x2 - 2*g$x1^2 - 1.5*g$x2^2 + 0.2*g$x1*g$x2
  fit <- rsm_fit(g, "y", c("x1","x2"), order = 2)
  ca <- rsm_canonical(fit)
  expect_equal(ca$nature, "maximum")
  expect_true(ca$inside_region)
  opt <- rsm_optimize(fit, goal="max", method="L-BFGS-B")
  expect_true(all(opt$solution >= c(-1,-1) & opt$solution <= c(1,1)))
})

test_that("saddle systems are not mislabeled as maxima", {
  g <- expand.grid(x1 = seq(-1,1,length.out=5), x2 = seq(-1,1,length.out=5))
  g$y <- 5 + g$x1^2 - g$x2^2
  fit <- rsm_fit(g, "y", c("x1","x2"), order = 2)
  expect_equal(rsm_canonical(fit)$nature, "saddle")
})


test_that("canonical analysis is stable in natural factor units", {
  g <- expand.grid(N = seq(0, 200, length.out = 7), K = seq(0, 120, length.out = 7))
  g$y <- 30 + 0.10*g$N + 0.08*g$K - 0.0004*g$N^2 - 0.0005*g$K^2
  fit <- rsm_fit(g, "y", c("N", "K"), order = 2)
  ca <- rsm_canonical(fit)
  expect_equal(ca$nature, "maximum")
  expect_equal(unname(ca$stationary_point), c(125, 80), tolerance = 1e-4)
})

test_that("lack-of-fit reference preserves blocks", {
  d <- expand.grid(Block = factor(1:4), x1 = c(-1, 0, 1), x2 = c(-1, 0, 1))
  be <- c(-1.0, -0.3, 0.4, 0.9)
  d$y <- 10 + 2*d$x1 - d$x2 - d$x1^2 - 0.5*d$x2^2 + be[as.integer(d$Block)]
  fit <- rsm_fit(d, "y", c("x1", "x2"), order = 2, block = "Block")
  lof <- rsm_lack_of_fit(fit)
  expect_true(lof$available)
  expect_equal(unname(lof$lack_of_fit["SS"]), 0, tolerance = 1e-8)
  expect_equal(lof$reference, "block + cell-means")
})
