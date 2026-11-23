# Tests for the slurmworkflow step templates. The functions they call and the
# scenario machinery itself live in EpiModel and are tested there: these tests
# only exercise the wiring, in a throw-away step folder as `slurmworkflow` uses
# when building a workflow. No netsim runs.

# Run a step template the way `slurmworkflow` does: in a step folder, with an
# `instructions.sh` script and the `SWF__CUR_DIR` variable.
run_step_tmpl <- function(step_tmpl) {
  step_dir <- tempfile("swf_step_")
  dir.create(step_dir)
  on.exit(unlink(step_dir, recursive = TRUE))

  instructions_script <- file.path(step_dir, "instructions.sh")
  extra <- step_tmpl(
    instructions_script,
    c(SWF__CUR_DIR = step_dir)
  )

  # read the step files before `step_dir` is removed on exit
  read_if_exists <- function(f) {
    path <- file.path(step_dir, f)
    if (file.exists(path)) readRDS(path) else NULL
  }

  list(
    instructions = readLines(instructions_script),
    extra = extra,
    map = read_if_exists("map.rds"),
    do_call = read_if_exists("do_call.rds")
  )
}

# A control with a user `future` plan, so no `multicore` plan is built here
# (and the templates are not tied to a platform)
test_control <- function(...) {
  control <- EpiModel::control.net(type = "SI", nsteps = 2, ...)
  control$future.use.plan <- future::tweak(future::multisession, workers = 1)
  control
}

test_that("step_tmpl_netsim_scenarios builds its map step template", {
  scenarios_list <- EpiModel::create_scenario_list(
    data.frame(.at = 0, .scenario.id = "base")
  )

  step_tmpl <- step_tmpl_netsim_scenarios(
    path_to_x = tempfile("est_", fileext = ".rds"),
    param = EpiModel::param.net(inf.prob = 0.3),
    init = EpiModel::init.net(i.num = 10),
    control = test_control(),
    scenarios_list = scenarios_list,
    n_rep = 2, n_cores = 1,
    output_dir = tempfile("scen_out_")
  )

  expect_type(step_tmpl, "closure")

  step <- run_step_tmpl(step_tmpl)
  expect_equal(step$extra$array, "0-1")
  expect_true(any(grepl("Rscript", step$instructions)))

  map <- step$map
  expect_equal(map$FUN, EpiModel::.run_batch)
  expect_equal(map$dots$batch_num, c(1L, 2L))
  expect_false("libraries" %in% names(map$MoreArgs))
})

test_that("step_tmpl_merge_netsim_scenarios passes its arguments by name", {
  step_tmpl <- step_tmpl_merge_netsim_scenarios(
    sim_dir = tempfile("sims_"),
    output_dir = tempfile("merged_"),
    param.error = TRUE,
    keep.diss.stats = FALSE
  )

  expect_type(step_tmpl, "closure")

  step <- run_step_tmpl(step_tmpl)
  do_call <- step$do_call
  expect_true(do_call$args$param.error)
  expect_false(do_call$args$keep.diss.stats)
  expect_equal(do_call$args$n_cores, 1)
})

test_that("step_tmpl_merge_netsim_scenarios_tibble builds its do_call step", {
  step_tmpl <- step_tmpl_merge_netsim_scenarios_tibble(
    sim_dir = tempfile("sims_"),
    output_dir = tempfile("merged_"),
    steps_to_keep = 5
  )

  expect_type(step_tmpl, "closure")

  step <- run_step_tmpl(step_tmpl)
  do_call <- step$do_call
  expect_named(
    do_call$args,
    c("sim_dir", "output_dir", "steps_to_keep", "cols", "n_cores")
  )
  expect_equal(do_call$args$steps_to_keep, 5)
})

test_that("step_tmpl_netsim_swfcalib_output builds its map step template", {
  step_tmpl <- step_tmpl_netsim_swfcalib_output(
    path_to_x = tempfile("est_", fileext = ".rds"),
    param = EpiModel::param.net(inf.prob = 0.3),
    init = EpiModel::init.net(i.num = 10),
    control = test_control(),
    calib_object = "calib_object.rds",
    n_rep = 1, n_cores = 1,
    output_dir = tempfile("swf_out_")
  )

  expect_type(step_tmpl, "closure")

  step <- run_step_tmpl(step_tmpl)
  map <- step$map
  expect_equal(map$FUN, netsim_run_swfcalib_scenario)
  expect_equal(map$dots$batch_num, 1L)
  expect_equal(map$MoreArgs$calib_object, "calib_object.rds")
  expect_false("libraries" %in% names(map$MoreArgs))
})

test_that("the swfcalib output setup rejects raw.output", {
  expect_error(
    netsim_swfcalib_output_setup(
      path_to_x = tempfile("est_", fileext = ".rds"),
      param = EpiModel::param.net(inf.prob = 0.3),
      init = EpiModel::init.net(i.num = 10),
      control = test_control(raw.output = TRUE),
      calib_object = "calib_object.rds",
      n_rep = 1, n_cores = 1,
      output_dir = tempfile("swf_out_")
    ),
    "raw.output"
  )
})
