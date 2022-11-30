context("Network model with scenarios")

test_that("SIS with scenarios", {
  set.seed(10)

  nw <- network_initialize(n = 200)
  est <- netest(nw,
    formation = ~edges, target.stats = 60,
    coef.diss = dissolution_coefs(~offset(edges), 10, 0),
    verbose = FALSE
  )

  param <- param.net(inf.prob = 0.9, rec.rate = 0.01, act.rate = 2)
  control <- control.net(type = "SIS", nsims = 1, nsteps = 2, verbose = FALSE)
  init <- init.net(i.num = 10)

  output_dir <- "testscen_dir"
  saveRDS(est, paste0(output_dir, "/est.rds"))

  scenarios.df <- dplyr::tribble(
    ~.scenario.id, ~.at, ~inf.prob, ~rec.rate,
    "base", 0, 0.9, 0.01,
    "multiple_changes", 0, 0.1, 0.04,
    "multiple_changes", 20, 0.9, 0.01,
    "multiple_changes", 40, 0.1, 0.1
  )

  scenarios.list <- create_scenario_list(scenarios.df)

  n_rep <- 3
  n_cores <- 2
  n_scen <- length(scenarios.list)
  netsim_scenarios(
    path_to_x = paste0(output_dir, "/est.rds"),
    param, init, control,
    scenarios_list = scenarios.list,
    n_rep = n_rep, n_cores = n_cores,
    output_dir = output_dir,
    libraries = NULL,
    save_pattern = c("simple", "_last_unique_id", "absent")
  )

  sim <- readRDS(paste0(output_dir, "/sim__base__1.rds"))
  expect_setequal(
    names(sim),
    c("epi", "param", "control", "_last_unique_id")
  )

  testthat::expect_length(
    list.files(output_dir),
    n_scen * ceiling(n_rep / n_cores) + 1 # +1 for est file
  )
  unlink(output_dir)
})
