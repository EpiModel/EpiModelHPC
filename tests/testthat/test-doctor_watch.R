context("Deploy-doctor watch-list steps")

test_that("register lines create the campaign marker", {
  reg <- doctor_register_lines("mywf", "data/run/.doctor_watch")
  expect_true(any(grepl("mkdir -p", reg)))
  expect_true(any(grepl("touch .*/mywf(\"|$)", reg)))
  # trailing ':' so the step's `set -e` never trips on a no-op
  expect_identical(reg[length(reg)], ":")
})

test_that("teardown lines are race-free and stop the right job", {
  td <- doctor_teardown_lines("mywf", "data/run/.doctor_watch", "deploy_doctor")

  # The marker removal MUST come before the emptiness test: that ordering is
  # what makes two simultaneous finishes race-free.
  rm_idx   <- grep("rm -f .*/mywf", td)
  test_idx <- grep("ls -A", td)
  expect_length(rm_idx, 1)
  expect_length(test_idx, 1)
  expect_lt(rm_idx, test_idx)

  # Stops only the named doctor job, guarded so scancel never fails the step.
  expect_true(any(grepl("scancel .*--name=deploy_doctor", td)))
  expect_true(any(grepl("\\|\\| :", td)))
  expect_identical(td[length(td)], ":")
})

test_that("teardown honors a custom job name", {
  td <- doctor_teardown_lines("w", "wd", "my_doctor")
  expect_true(any(grepl("--name=my_doctor", td)))
  expect_false(any(grepl("--name=deploy_doctor", td)))
})

test_that("add_doctor_*_step append steps that write the expected bash", {
  wd <- file.path(tempdir(), "swf_doctor_test")
  unlink(wd, recursive = TRUE)
  dir.create(wd, showWarnings = FALSE, recursive = TRUE)
  old <- setwd(wd)
  on.exit({ setwd(old); unlink(wd, recursive = TRUE) }, add = TRUE)

  wf <- slurmworkflow::create_workflow(
    wf_name = "toy",
    default_sbatch_opts = list("partition" = "test")
  )
  wf <- add_doctor_register_step(wf, "toy")
  wf <- add_doctor_teardown_step(wf, "toy")

  instr <- list.files(file.path("workflows", "toy"),
                      pattern = "instructions.sh$", recursive = TRUE,
                      full.names = TRUE)
  all_lines <- unlist(lapply(instr, readLines))
  expect_true(any(grepl("touch .*/toy", all_lines)))
  expect_true(any(grepl("rm -f .*/toy", all_lines)))
  expect_true(any(grepl("scancel .*--name=deploy_doctor", all_lines)))
})
