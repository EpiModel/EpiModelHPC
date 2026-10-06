# Toy model: 2 batch files of 3 SI simulations, as written by
# `netsim_scenarios` for a scenario named "base"
make_toy_batches <- function(scen_dir) {
  set.seed(1)
  nw <- network_initialize(n = 100)
  est <- netest(nw,
    formation = ~edges, target.stats = 50,
    coef.diss = dissolution_coefs(~offset(edges), 10, 0),
    verbose = FALSE
  )
  control <- control.net(
    type = "SI", nsims = 3, nsteps = 5,
    tergmLite = TRUE, resimulate.network = TRUE, save.run = TRUE,
    verbose = FALSE
  )
  fs::dir_create(scen_dir)
  for (b in 1:2) {
    sim <- netsim(est, toy_param, toy_init, control)
    saveRDS(sim, fs::path(scen_dir, paste0("sim__base__", b, ".rds")))
  }
}

toy_param <- param.net(inf.prob = 0.3, act.rate = 1)
toy_init <- init.net(i.num = 10)
toy_control_restart <- control.net(
  type = "SI", start = 2, nsteps = 4,
  tergmLite = TRUE, resimulate.network = TRUE, save.run = TRUE,
  verbose = FALSE
)

# Copy a pool and tag each element with its pool number in an extra epi
# column, copied as is into time step 1 of the simulations restarted from it
tag_pool <- function(pool_dir, tagged_dir) {
  fs::dir_copy(pool_dir, tagged_dir)
  for (f in fs::dir_ls(tagged_dir, regexp = "/\\d+\\.rds$")) {
    x <- readRDS(f)
    x$epi$pool_tag <- data.frame(sim1 = as.numeric(sub("\\.rds$", "", fs::path_file(f))))
    saveRDS(x, f)
  }
  tagged_dir
}

test_that("make_restart_pool makes pool element i from row i of keep_sims", {
  skip_on_cran()
  scen_dir <- fs::path(tempdir(), "rp_scen_make")
  pool_dir <- fs::path(tempdir(), "rp_pool_make")
  on.exit(fs::dir_delete(c(scen_dir, pool_dir[fs::dir_exists(pool_dir)])))
  make_toy_batches(scen_dir)

  keep_sims <- data.frame(batch_number = c(2, 1, 1, 2), sim_number = c(3, 1, 3, 1))
  pool_index <- make_restart_pool(pool_dir, scen_dir, "base", keep_sims, "infTime")

  expect_setequal(fs::path_file(fs::dir_ls(pool_dir)), c(paste0(1:4, ".rds"), "pool_index.csv"))
  pool_index_csv <- utils::read.csv(fs::path(pool_dir, "pool_index.csv"))
  expect_equal(pool_index_csv$pool_num, 1:4)
  expect_equal(pool_index_csv$batch_number, keep_sims$batch_number)
  expect_equal(pool_index_csv$sim_number, keep_sims$sim_number)
  expect_equal(pool_index$batch_number, keep_sims$batch_number)

  for (i in seq_len(nrow(keep_sims))) {
    src <- readRDS(fs::path(scen_dir, paste0("sim__base__", keep_sims$batch_number[i], ".rds")))
    expected <- make_restart_point(src, "infTime", sim_num = keep_sims$sim_number[i])
    elt <- readRDS(fs::path(pool_dir, paste0(i, ".rds")))
    expect_identical(elt$run[[1]]$attr, expected$run[[1]]$attr)
    expect_equal(elt$epi, expected$epi)
    expect_equal(elt$control$nsims, 1)
  }

  expect_error(
    make_restart_pool(pool_dir, scen_dir, "base", keep_sims, "infTime"),
    "already exists"
  )
})

test_that("make_restart_pool rejects bad keep_sims without leaving a pool", {
  skip_on_cran()
  scen_dir <- fs::path(tempdir(), "rp_scen_bad")
  pool_dir <- fs::path(tempdir(), "rp_pool_bad")
  on.exit(fs::dir_delete(scen_dir))
  make_toy_batches(scen_dir)

  expect_error(
    make_restart_pool(pool_dir, scen_dir, "base",
                      data.frame(batch_number = 3, sim_number = 1), "infTime"),
    "No simulation file"
  )
  expect_error(
    make_restart_pool(pool_dir, scen_dir, "other",
                      data.frame(batch_number = 1, sim_number = 1), "infTime"),
    "No simulation file"
  )
  expect_error(
    make_restart_pool(pool_dir, scen_dir, "base",
                      data.frame(batch_number = 1, sim_number = 4), "infTime"),
    "out of range"
  )
  expect_error(
    make_restart_pool(pool_dir, scen_dir, "base",
                      data.frame(batch_number = c(1, 1), sim_number = c(2, 2)), "infTime"),
    "more than once"
  )
  expect_error(
    make_restart_pool(pool_dir, scen_dir, "base",
                      data.frame(batch_number = 1, sim_number = 1), "not_an_attr"),
    "not present"
  )
  expect_false(fs::dir_exists(pool_dir))
})

test_that("add_to_restart_pool appends to empty and existing pools", {
  pool_dir <- fs::path(tempdir(), "rp_pool_add")
  on.exit(fs::dir_delete(pool_dir))
  fs::dir_create(pool_dir)

  expect_equal(add_to_restart_pool(list("a", "b"), pool_dir), 1:2)
  expect_equal(add_to_restart_pool(list("c"), pool_dir), 3)
  expect_equal(readRDS(fs::path(pool_dir, "3.rds")), "c")

  new_dir <- fs::path(pool_dir, "sub", "pool")
  expect_message(add_to_restart_pool(list("a"), new_dir), "Creating")
  expect_true(fs::file_exists(fs::path(new_dir, "1.rds")))
})

test_that("validate_restart_pool checks pools and single files", {
  skip_on_cran()
  scen_dir <- fs::path(tempdir(), "rp_scen_valid")
  pool_dir <- fs::path(tempdir(), "rp_pool_valid")
  copy_dir <- fs::path(tempdir(), "rp_pool_valid_copy")
  on.exit(fs::dir_delete(c(scen_dir, pool_dir, copy_dir[fs::dir_exists(copy_dir)])))
  make_toy_batches(scen_dir)
  keep_sims <- data.frame(batch_number = c(1, 2, 2), sim_number = c(2, 1, 3))
  make_restart_pool(pool_dir, scen_dir, "base", keep_sims, "infTime")

  # a valid pool
  expect_warning(infos <- validate_restart_pool(pool_dir), NA)
  expect_equal(infos$pool_num, 1:3)
  expect_equal(infos$n_runs, rep(1, 3))
  expect_equal(infos$nsteps, rep(1, 3))

  # a single restart point file
  expect_warning(validate_restart_pool(fs::path(pool_dir, "1.rds")), NA)
  # a single file with several simulations
  expect_warning(
    validate_restart_pool(fs::path(scen_dir, "sim__base__1.rds")),
    "holds 3 simulations"
  )
  expect_error(validate_restart_pool(fs::path(tempdir(), "no_such_pool")), "neither")

  # numbering gap
  fs::dir_copy(pool_dir, copy_dir)
  fs::file_delete(fs::path(copy_dir, "2.rds"))
  expect_error(validate_restart_pool(copy_dir), "must be named")

  # an element holding several simulations
  fs::file_copy(fs::path(scen_dir, "sim__base__1.rds"), fs::path(copy_dir, "2.rds"))
  expect_error(validate_restart_pool(copy_dir), "holds 3 simulations")

  # pool index not matching the files
  fs::file_copy(fs::path(pool_dir, "2.rds"), fs::path(copy_dir, "2.rds"), overwrite = TRUE)
  fs::file_delete(fs::path(copy_dir, "3.rds"))
  expect_warning(validate_restart_pool(copy_dir), "pool_index.csv")

  # no pool element
  fs::file_delete(fs::dir_ls(copy_dir, regexp = "\\.rds$"))
  expect_error(validate_restart_pool(copy_dir), "contains no")
})

test_that("netsim_run_one_scenario restarts simulation k from pool element (k - 1) %% N + 1", {
  skip_on_cran()
  scen_dir <- fs::path(tempdir(), "rp_scen_run")
  pool_dir <- fs::path(tempdir(), "rp_pool_run")
  tagged_dir <- fs::path(tempdir(), "rp_pool_run_tagged")
  out_dir <- fs::path(tempdir(), "rp_out_run")
  on.exit(fs::dir_delete(c(scen_dir, pool_dir, tagged_dir, out_dir)))
  make_toy_batches(scen_dir)
  keep_sims <- data.frame(batch_number = c(2, 1, 2, 1), sim_number = c(1, 3, 2, 2))
  make_restart_pool(pool_dir, scen_dir, "base", keep_sims, "infTime")
  tag_pool(pool_dir, tagged_dir)

  scenario <- EpiModel::create_scenario_list(
    data.frame(.at = 0, .scenario.id = "base")
  )[[1]]
  # 6 replications over 3 batches of 2: sims 1 to 6 use elements 1 2 3 4 1 2
  for (b in 1:3) {
    netsim_run_one_scenario(
      scenario, b, tagged_dir, toy_param, toy_init, toy_control_restart,
      libraries = NULL, output_dir = out_dir,
      n_batch = 3, n_rep = 6, n_cores = 2
    )
  }
  expect_setequal(
    fs::path_file(fs::dir_ls(out_dir)),
    paste0("sim__base__", 1:3, ".rds")
  )

  pool_epi <- lapply(1:4, function(i) readRDS(fs::path(pool_dir, paste0(i, ".rds")))$epi)
  tags <- c()
  for (b in 1:3) {
    sim <- readRDS(fs::path(out_dir, paste0("sim__base__", b, ".rds")))
    expect_equal(sim$control$nsims, 2)
    expect_equal(nrow(sim$epi$i.num), 4)
    for (j in 1:2) {
      k <- (b - 1) * 2 + j
      expected_elt <- (k - 1) %% 4 + 1
      tags <- c(tags, sim$epi$pool_tag[1, j])
      expect_equal(sim$epi$i.num[1, j], pool_epi[[expected_elt]]$i.num[1, 1])
      expect_equal(sim$epi$num[1, j], pool_epi[[expected_elt]]$num[1, 1])
    }
  }
  expect_equal(tags, c(1, 2, 3, 4, 1, 2))
})

test_that("netsim_run_one_scenario gives each simulation its own checkpoint directory", {
  skip_on_cran()
  scen_dir <- fs::path(tempdir(), "rp_scen_ckpt")
  pool_dir <- fs::path(tempdir(), "rp_pool_ckpt")
  out_dir <- fs::path(tempdir(), "rp_out_ckpt")
  ckpt_dir <- fs::path(tempdir(), "rp_ckpt")
  on.exit(fs::dir_delete(c(scen_dir, pool_dir, out_dir, ckpt_dir[fs::dir_exists(ckpt_dir)])))
  make_toy_batches(scen_dir)
  make_restart_pool(
    pool_dir, scen_dir, "base",
    data.frame(batch_number = 1, sim_number = 1:2), "infTime"
  )

  control <- toy_control_restart
  control$.checkpoint.dir <- ckpt_dir
  control$.checkpoint.steps <- 1
  control$.checkpoint.keep <- TRUE
  scenario <- EpiModel::create_scenario_list(
    data.frame(.at = 0, .scenario.id = "base")
  )[[1]]
  netsim_run_one_scenario(
    scenario, 1, pool_dir, toy_param, toy_init, control,
    libraries = NULL, output_dir = out_dir,
    n_batch = 1, n_rep = 2, n_cores = 2
  )

  sim <- readRDS(fs::path(out_dir, "sim__base__1.rds"))
  batch_ckpt_dir <- paste0(ckpt_dir, "/sim__base__1")
  expect_equal(sim$control$nsims, 2)
  expect_equal(sim$control$.checkpoint.dir, batch_ckpt_dir)
  expect_setequal(
    fs::path_file(fs::dir_ls(batch_ckpt_dir)),
    c("sim_1", "sim_2")
  )
})
