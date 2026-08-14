test_that("desirability is bounded between zero and one", {
  d <- rsm_desirability(c(-1,0,.5,1,2), "max", low=0, high=1)
  expect_true(all(d >= 0 & d <= 1))
  expect_equal(d[c(1,2,4,5)], c(0,0,1,1))
})
