test_that("near-optimal region is bounded by the experimental region", {
  g <- expand.grid(N=seq(0,200,length.out=7), K=seq(0,120,length.out=7))
  g$Yield <- 4 + .04*g$N + .03*g$K - .00015*g$N^2 - .0002*g$K^2
  fit <- rsm_fit(g, "Yield", c("N","K"), 2)
  nr <- rsm_near_optimal(fit, tolerance=.05, n=25)
  expect_true(all(nr$N >= 0 & nr$N <= 200))
  expect_true(all(nr$K >= 0 & nr$K <= 120))
})

test_that("economic optimum reports profit and biological comparator", {
  g <- expand.grid(N=seq(0,200,length.out=7), K=seq(0,120,length.out=7))
  g$Yield <- 4 + .04*g$N + .03*g$K - .00015*g$N^2 - .0002*g$K^2
  fit <- rsm_fit(g, "Yield", c("N","K"), 2)
  eco <- rsm_economic_optimum(fit, response_price=1200, factor_cost=c(N=5.5,K=4.0))
  expect_true(is.finite(eco$profit))
  expect_named(eco$solution, c("N","K"))
  expect_lt(eco$solution[["N"]], eco$biological_optimum[["N"]])
  expect_lt(eco$solution[["K"]], eco$biological_optimum[["K"]])
})
