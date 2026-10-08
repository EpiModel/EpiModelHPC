context("Network model with scenarios")

output_dir <- "testscen_dir"
if (!dir.exists(output_dir)) dir.create(output_dir)

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
    libraries = NULL
  )

  sim <- readRDS(paste0(output_dir, "/sim__base__1.rds"))

  testthat::expect_length(
    list.files(output_dir),
    n_scen * ceiling(n_rep / n_cores) + 1 # +1 for est file
  )
  unlink(output_dir, recursive = TRUE)
})

test_that("get_scenarios_batches_infos sorts by scenario and batch number", {
  scen_dir <- fs::path(tempdir(), "batches_order")
  on.exit(fs::dir_delete(scen_dir))
  fs::dir_create(scen_dir)
  fs::file_touch(fs::path(scen_dir, paste0("sim__b__", 1:12, ".rds")))
  fs::file_touch(fs::path(scen_dir, paste0("sim__a__", c(10, 2, 1), ".rds")))

  infos <- get_scenarios_batches_infos(scen_dir)
  expect_equal(infos$scenario_name, c(rep("a", 3), rep("b", 12)))
  expect_equal(infos$batch_number, c(1L, 2L, 10L, 1:12))
  expect_equal(fs::path_file(infos$file_path)[1:3],
               c("sim__a__1.rds", "sim__a__2.rds", "sim__a__10.rds"))
})
