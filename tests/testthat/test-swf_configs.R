test_that("swf_configs_rsph defaults to the epimodel partition and R 4.6.1", {
  cfg <- swf_configs_rsph()
  expect_named(
    cfg,
    c("default_sbatch_opts", "renv_sbatch_opts", "r_loader", "max_cores")
  )
  expect_identical(
    cfg$default_sbatch_opts,
    list("partition" = "epimodel", "mail-type" = "FAIL")
  )
  expect_identical(
    cfg$renv_sbatch_opts,
    list("mem" = "16G", "cpus-per-task" = 4, "time" = 180)
  )
  expect_identical(cfg$r_loader[3], "spack load r@4.6.1")
  expect_identical(cfg$max_cores, 32)
})

test_that("swf_configs_rsph sets mail-user only when given", {
  cfg <- swf_configs_rsph(mail_user = "user@emory.edu")
  expect_identical(cfg$default_sbatch_opts[["mail-user"]], "user@emory.edu")
  expect_null(swf_configs_rsph()$default_sbatch_opts[["mail-user"]])
})

test_that("swf_configs_rsph accepts every current partition", {
  for (p in c("epimodel", "CIDMATH", "short-cpu", "day-long-cpu",
              "week-long-cpu", "month-long-cpu", "interactive-cpu",
              "largemem")) {
    expect_identical(
      swf_configs_rsph(p)$default_sbatch_opts$partition, p
    )
  }
})

test_that("swf_configs_rsph takes a vector or a comma-separated string", {
  from_vec <- swf_configs_rsph(c("epimodel", "CIDMATH", "short-cpu"))
  from_str <- swf_configs_rsph("epimodel, CIDMATH,short-cpu")
  expect_identical(
    from_vec$default_sbatch_opts$partition, "epimodel,CIDMATH,short-cpu"
  )
  expect_identical(from_vec, from_str)

  # case-insensitive match to the canonical name, duplicates dropped
  cfg <- swf_configs_rsph(c("cidmath", "epimodel", "CIDMATH"))
  expect_identical(cfg$default_sbatch_opts$partition, "CIDMATH,epimodel")
})

test_that("swf_configs_rsph rejects the retired preemptable partition", {
  expect_error(swf_configs_rsph("preemptable"), "no longer exists")
  expect_error(swf_configs_rsph("epimodel,preemptable"), "no longer exists")
})

test_that("swf_configs_rsph rejects unknown or empty partitions", {
  expect_error(swf_configs_rsph("compute"), "Unknown RSPH partition")
  expect_error(swf_configs_rsph(""), "at least one")
  expect_error(swf_configs_rsph(NA_character_), "character vector")
  expect_error(swf_configs_rsph(1), "character vector")
})

test_that("max_cores is the smallest per-task limit of the listed partitions", {
  expect_identical(swf_configs_rsph("short-cpu")$max_cores, 32)
  expect_identical(
    swf_configs_rsph(c("epimodel", "interactive-cpu"))$max_cores, 16
  )
  expect_identical(swf_configs_rsph("largemem")$max_cores, 31)
})

test_that("r_loader loads the requested R and the worker cleanup trap", {
  with_trap <- swf_configs_rsph(r_version = "4.5.1")$r_loader
  no_trap <- swf_configs_rsph(r_version = "4.5.1", cleanup_workers = FALSE)
  expect_identical(
    no_trap$r_loader,
    c(
      ". /projects/epimodel/spack/share/spack/setup-env.sh",
      "spack unload -a",
      "spack load r@4.5.1"
    )
  )
  expect_identical(with_trap, c(no_trap$r_loader, swf_cleanup_r_workers()))
})

test_that("swf_configs_rsph warns on a partial R version", {
  expect_warning(swf_configs_rsph(r_version = "4.3"), "not a full version")
  expect_no_warning(swf_configs_rsph(r_version = "4.5.1"))
})

test_that("the default sbatch options reach the generated job scripts", {
  wd <- file.path(tempdir(), "swf_configs_test")
  unlink(wd, recursive = TRUE)
  dir.create(wd, showWarnings = FALSE, recursive = TRUE)
  old <- setwd(wd)
  on.exit({ setwd(old); unlink(wd, recursive = TRUE) }, add = TRUE)

  cfg <- swf_configs_rsph(c("epimodel", "CIDMATH"), mail_user = "u@emory.edu")
  wf <- slurmworkflow::create_workflow(
    wf_name = "toy",
    default_sbatch_opts = cfg$default_sbatch_opts
  )
  wf <- slurmworkflow::add_workflow_step(
    wf_summary = wf,
    step_tmpl = step_tmpl_renv_restore(
      git_branch = "main",
      setup_lines = cfg$r_loader,
      lockfile = "renv.lock.hpc"
    ),
    sbatch_opts = cfg$renv_sbatch_opts
  )

  job <- readLines(file.path("workflows", "toy", "SWF", "steps", "1", "job.sh"))
  expect_true("#SBATCH --partition=epimodel,CIDMATH" %in% job)
  expect_true("#SBATCH --mail-user=u@emory.edu" %in% job)
  expect_true("#SBATCH --time=180" %in% job)
})
