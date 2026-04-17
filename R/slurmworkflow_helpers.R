#' Step template to update a project \code{renv}
#'
#' This template makes the step run `git pull` and \code{renv::restore()}. This
#' could help ensure that the project is up to date when running the rest of the
#' workflow.
#' See \code{slurmworkflow::step_tmpl_bash_lines} for details on step templates
#'
#' @param git_branch The git branch that the project is supposed to follow. If
#'   the project is not following the right branch, this step will error.
#' @param setup_lines (optional) a vector of bash lines to be run first.
#'   This can be used to load the required modules (like R, python, etc).
#' @param lockfile (optional) path to an alternative lockfile to restore
#'
#' @return a template function to be used by \code{add_workflow_step}
#'
#' @export
step_tmpl_renv_restore <- function(
  git_branch,
  setup_lines = NULL,
  lockfile = NULL
) {
  instructions <- c(
    "CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)",
    paste0("if [[ \"$CUR_BRANCH\" != \"", git_branch, "\" ]]; then"),
    paste0("echo 'The git branch is not `", git_branch, "`.)"),
    paste0("Exiting' 1>&2"),
    "exit 1",
    "fi",
    "git pull",
    "Rscript -e \"renv::init(bare = TRUE, load = FALSE)\""
  )
  if (is.null(lockfile)) {
    instructions <- c(instructions, "Rscript -e \"renv::restore()\"")
  } else {
    instructions <- c(
      instructions,
      paste0("Rscript -e \"renv::restore(lockfile = '", lockfile, "')\"")
    )
  }

  instructions <- slurmworkflow::helper_use_setup_lines(
    instructions,
    setup_lines
  )

  slurmworkflow::step_tmpl_bash_lines(instructions)
}

#' Step template to run EpiModel network simulations with scenarios
#'
#' This step template is similar to `netsim_scenarios` but for the HPC. It uses
#' `slurmworkflow::step_tmpl_map` internally and should be used as any
#' `slurmworkflow` step. For details, see `netsim_scenarios` documentation.
#' The inner parallelization is by default handled with
#' `future::plan("multicore", workers = n_cores)`.
#' Using `control$future.use.plan <- future::tweaked(<your plan>)` will bypass
#' this setting.
#'
#' @inheritParams slurmworkflow::step_tmpl_map
#' @inheritParams netsim_scenarios
#'
#' @inheritSection netsim_run_one_scenario Checkpointing
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_netsim_scenarios <- function(
  path_to_x,
  param,
  init,
  control,
  scenarios_list,
  n_rep,
  n_cores,
  output_dir,
  libraries = NULL,
  setup_lines = NULL,
  max_array_size = NULL,
  ...
) {
  # Set a `multicore` plan with `n_cores` workers by default.
  # Bypassed if `control$future.use.plan` is manually set
  if (!inherits(control$future.use.plan, c("tweaked", "future"))) {
    control$future.use.plan <- future::tweak("multicore", workers = n_cores)
  }

  p_list <- netsim_scenarios_setup(
    path_to_x,
    param,
    init,
    control,
    scenarios_list,
    n_rep,
    n_cores,
    output_dir,
    libraries
  )

  message(
    "Simulations for `step_tmpl_netsim_scenarios` will be saved in: \n",
    "    \"",
    output_dir,
    "\""
  )

  slurmworkflow::step_tmpl_map(
    FUN = netsim_run_one_scenario,
    scenario = p_list$scenarios_list,
    batch_num = p_list$batchs_list,
    MoreArgs = p_list$MoreArgs,

    max_array_size = max_array_size,
    setup_lines = setup_lines
  )
}

#' Step Template to Create a Single Sim File per Scenarios Using the Files From
#' `netsim_scenarios`
#'
#' @param n_cores Parallelize the process over `n_cores` (default = 1)
#'
#' @inheritParams slurmworkflow::step_tmpl_map
#' @inheritParams merge_netsim_scenarios
#'
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_merge_netsim_scenarios <- function(
  sim_dir,
  output_dir,
  keep.transmat = TRUE,
  keep.network = TRUE,
  keep.nwstats = TRUE,
  keep.other = TRUE,
  param.error = FALSE,
  keep.diss.stats = TRUE,
  truncate.at = NULL,
  n_cores = 1,
  setup_lines = NULL
) {
  merge_fun <- function(
    sim_dir,
    output_dir,
    keep.transmat,
    keep.network,
    keep.nwstats,
    keep.other,
    param.error,
    keep.diss.stats,
    truncate.at,
    n_cores
  ) {
    future::plan("multicore", workers = n_cores)
    EpiModelHPC::merge_netsim_scenarios(
      sim_dir,
      output_dir,
      keep.transmat,
      keep.network,
      keep.nwstats,
      keep.other,
      keep.diss.stats,
      param.error,
      truncate.at
    )
  }

  slurmworkflow::step_tmpl_do_call(
    what = merge_fun,
    args = list(
      sim_dir,
      output_dir,
      keep.transmat,
      keep.network,
      keep.nwstats,
      keep.other,
      keep.diss.stats,
      param.error,
      truncate.at,
      n_cores
    ),
    setup_lines = setup_lines
  )
}

#' Step Template to Create a Single Sim File per Scenarios Using the Files From
#' `netsim_scenarios`
#'
#' @param n_cores Parallelize the process over `n_cores` (default = 1)
#'
#' @inheritParams slurmworkflow::step_tmpl_map
#' @inheritParams merge_netsim_scenarios_tibble
#'
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_merge_netsim_scenarios_tibble <- function(
  sim_dir,
  output_dir,
  steps_to_keep,
  cols = dplyr::everything(),
  n_cores = 1,
  setup_lines = NULL
) {
  merge_fun <- function(sim_dir, output_dir, steps_to_keep, cols, n_cores) {
    future::plan("multicore", workers = n_cores)
    EpiModelHPC::merge_netsim_scenarios_tibble(
      sim_dir = sim_dir,
      output_dir = output_dir,
      steps_to_keep = steps_to_keep,
      cols = {{ cols }}
    )
  }

  slurmworkflow::step_tmpl_do_call(
    what = merge_fun,
    args = list(
      sim_dir,
      output_dir,
      steps_to_keep,
      rlang::enquo(cols),
      n_cores
    ),
    setup_lines = setup_lines
  )
}
