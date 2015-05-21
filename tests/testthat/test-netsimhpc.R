context("netsim_hpc")

test_that("1 sim on 1 core", {
  nw <- network.initialize(n = 50, directed = FALSE)
  formation <- ~edges
  target.stats <- 25
  dissolution <- ~offset(edges)
  duration <- 50
  coef.diss <- dissolution_coefs(dissolution, duration)
  est <- netest(nw, formation, dissolution,
                target.stats, coef.diss, verbose = FALSE)
  save(est, file = "est.temp.rda")
  param <- param.net(inf.prob = 0.25)
  init <- init.net(i.num = 50)
  control <- control.net(type = "SI", nsteps = 25, verbose = FALSE,
                         par.type = "single", nsims = 1, ncores = 1)
  netsim_hpc("est.temp.rda", param, init, control)
  expect_true(dir.exists("data/"))
  expect_true(length(list.files("data/")) == 1)

})

if (dir.exists("tests/testthat/data/")) {
  unlink("tests/testthat/data/", recursive = TRUE)
}
if (file.exists("est.temp.rda")) {
  file.remove("est.temp.rda")
}

