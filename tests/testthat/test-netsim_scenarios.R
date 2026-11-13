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

test_that("get_batch_plan keeps a tweaked plan, else tweaks the default", {
  user_plan <- future::tweak(future::multisession, workers = 3)
  expect_identical(
    get_batch_plan(list(future.use.plan = user_plan), future::multicore, 2),
    user_plan
  )

  default_plan <- get_batch_plan(
    list(future.use.plan = FALSE), future::multicore, 2
  )
  expect_s3_class(default_plan, "tweaked")
  expect_s3_class(default_plan, "multicore")
  expect_equal(attr(default_plan, "tweaks")$workers, 2)

  # the tweak holds the value of `n_cores`, not a promise on the caller
  n <- 4
  default_plan <- get_batch_plan(list(), future::multisession, n)
  n <- 1
  expect_equal(attr(default_plan, "tweaks")$workers, 4)
})

test_that("batch files keep the cumulative edgelists of all their simulations", {
  skip_on_cran()
  out_dir <- fs::path(tempdir(), "scen_cel_out")
  est_path <- fs::path(tempdir(), "scen_cel_est.rds")
  on.exit(fs::file_delete(est_path))
  on.exit(fs::dir_delete(out_dir), add = TRUE)

  set.seed(1)
  nw <- network_initialize(n = 100)
  est <- netest(nw,
    formation = ~edges, target.stats = 50,
    coef.diss = dissolution_coefs(~offset(edges), 10, 0),
    verbose = FALSE
  )
  saveRDS(est, est_path)
  control <- control.net(
    type = "SI", nsteps = 3, tergmLite = TRUE, resimulate.network = TRUE,
    cumulative.edgelist = TRUE, save.cumulative.edgelist = TRUE,
    verbose = FALSE
  )
  scenario <- create_scenario_list(
    data.frame(.at = 0, .scenario.id = "base")
  )[[1]]

  # 3 replications over 2 batches: a batch of 2 merged sims, and one of 1
  for (b in 1:2) {
    netsim_run_one_scenario(
      scenario, b, est_path,
      param.net(inf.prob = 0.3, act.rate = 1), init.net(i.num = 10), control,
      libraries = NULL, output_dir = out_dir,
      n_batch = 2, n_rep = 3, n_cores = 2
    )
  }
  batches <- lapply(1:2, function(b) {
    readRDS(fs::path(out_dir, paste0("sim__base__", b, ".rds")))
  })
  expect_length(batches[[1]]$cumulative.edgelist, 2)
  expect_length(batches[[2]]$cumulative.edgelist, 1)

  merged <- merge(batches[[1]], batches[[2]], keep.cumulative.edgelist = TRUE)
  expect_length(merged$cumulative.edgelist, 3)
})
