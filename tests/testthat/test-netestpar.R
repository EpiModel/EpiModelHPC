context("netest_par testing")

test_that("netest_par for multiple coef.diss", {
  nw <- network.initialize(n = 100, directed = FALSE)
  formation <- ~edges + concurrent
  target.stats <- c(50, 25)
  coef.diss <- list(dissolution_coefs(dissolution = ~offset(edges), duration = 10),
                    dissolution_coefs(dissolution = ~offset(edges), duration = 20))
  est <- netest_par(nw, formation, target.stats, coef.diss, ncores = 2)
  expect_is(est[[1]], "netest")
  expect_is(est[[2]], "netest")
})

test_that("netest_par for multiple target.stats", {
  nw <- network.initialize(n = 100, directed = FALSE)
  formation <- ~edges + concurrent
  target.stats <- list(c(50, 25),
                       c(50, 20))
  coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 10)
  est <- netest_par(nw, formation, target.stats, coef.diss, ncores = 2)
  expect_is(est[[1]], "netest")
  expect_is(est[[2]], "netest")
})

test_that("Error when both elements are singular", {
  nw <- network.initialize(n = 100, directed = FALSE)
  formation <- ~edges + concurrent
  target.stats <- c(50, 25)
  coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 10)
  expect_error(netest_par(nw, formation, target.stats, coef.diss, ncores = 2),
               "Either target.stats or coef.diss must be a list containing more than 1 element")
})

test_that("Error when both elements are multiple", {
  nw <- network.initialize(n = 100, directed = FALSE)
  formation <- ~edges + concurrent
  target.stats <- list(c(50, 25),
                       c(50, 10))
  coef.diss <- list(dissolution_coefs(dissolution = ~offset(edges), duration = 10),
                    dissolution_coefs(dissolution = ~offset(edges), duration = 20))
  expect_error(netest_par(nw, formation, target.stats, coef.diss, ncores = 2),
               "Only 1 of target.stats or coef.diss is allowed to have multiple inputs")
})
