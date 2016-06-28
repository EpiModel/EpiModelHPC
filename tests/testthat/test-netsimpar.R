context("netsim_par")

test_that("1 sim on 1 core", {
  nw <- network::network.initialize(n = 50, directed = FALSE)
  target.stats <- 25
  coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 50)
  est <- netest(nw, formation = ~edges, target.stats, coef.diss, verbose = FALSE)
  param <- param.net(inf.prob = 0.25)
  init <- init.net(i.num = 50)
  control <- control.net(type = "SI", nsteps = 5, verbose = FALSE,
                         nsims = 1, ncores = 1)
  sims <- netsim(est, param, init, control)
  expect_is(sims, "netsim")
  expect_output(print(sims), "simulations: 1")
})

test_that("2 sims on 1 core", {
  nw <- network::network.initialize(n = 50, directed = FALSE)
  target.stats <- 25
  coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 50)
  est <- netest(nw, formation = ~edges, target.stats, coef.diss, verbose = FALSE)
  param <- param.net(inf.prob = 0.25)
  init <- init.net(i.num = 50)
  control <- control.net(type = "SI", nsteps = 5, verbose = FALSE,
                         nsims = 2, ncores = 1)
  sims <- netsim(est, param, init, control)
  expect_is(sims, "netsim")
  expect_output(print(sims), "simulations: 2")
})

test_that("1 sim on (not really) 2 cores", {
  nw <- network::network.initialize(n = 50, directed = FALSE)
  target.stats <- 25
  coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 50)
  est <- netest(nw, formation = ~edges, target.stats, coef.diss, verbose = FALSE)
  param <- param.net(inf.prob = 0.25)
  init <- init.net(i.num = 50)
  control <- control.net(type = "SI", nsteps = 5, verbose = FALSE,
                         nsims = 1, ncores = 2)
  sims <- netsim(est, param, init, control)
  expect_is(sims, "netsim")
  expect_output(print(sims), "simulations: 1")
})

test_that("2 sims on 2 cores", {
  nw <- network::network.initialize(n = 50, directed = FALSE)
  target.stats <- 25
  coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 50)
  est <- netest(nw, formation = ~edges, target.stats, coef.diss, verbose = FALSE)
  param <- param.net(inf.prob = 0.25)
  init <- init.net(i.num = 50)
  control <- control.net(type = "SI", nsteps = 5, verbose = FALSE,
                         nsims = 2, ncores = 2)
  sims <- netsim(est, param, init, control)
  expect_is(sims, "netsim")
  expect_output(print(sims), "simulations: 2")
})
