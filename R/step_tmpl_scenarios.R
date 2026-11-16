#' Step template to run EpiModel network simulations with scenarios
#'
#' This step template is similar to `EpiModel::netsim_scenarios()` but for the
#' HPC. It uses `slurmworkflow::step_tmpl_map` internally and should be used as
#' any `slurmworkflow` step. For details, see the
#' `EpiModel::netsim_scenarios()` documentation.
#' The simulations of a batch are run in parallel, one `netsim` call per
#' simulation (see `EpiModel::netsim_path_wrapper()`), by default with
#' `future::plan("multicore", workers = n_cores)`.
#' Using `control$future.use.plan <- future::tweak(<your plan>)` will bypass
#' this setting.
#'
#' @inheritParams slurmworkflow::step_tmpl_map
#' @inheritParams EpiModel::netsim_scenarios
#'
#' @inheritSection EpiModel::.run_batch Checkpointing
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_netsim_scenarios <- function(path_to_x, param, init, control,
                                       scenarios_list, n_rep, n_cores,
                                       output_dir, libraries = NULL,
                                       setup_lines = NULL,
                                       max_array_size = NULL, ...) {
  control$future.use.plan <- EpiModel::.batch_plan(
    control, future::multicore, n_cores
  )

  # `EpiModel::.scenarios_setup()` does not add the HPC libraries to
  # `libraries`: the step runs on the HPC, so they are needed here.
  p_list <- EpiModel::.scenarios_setup(
    path_to_x = path_to_x,
    param = param,
    init = init,
    control = control,
    scenarios_list = scenarios_list,
    n_rep = n_rep,
    n_cores = n_cores,
    output_dir = output_dir,
    libraries = c("slurmworkflow", "EpiModelHPC", libraries)
  )

  message(
    "Simulations for `step_tmpl_netsim_scenarios` will be saved in: \n",
    "    \"", output_dir, "\""
  )

  slurmworkflow::step_tmpl_map(
    FUN = EpiModel::.run_batch,
    scenario = p_list$scenarios_list,
    batch_num = p_list$batchs_list,
    MoreArgs = p_list$MoreArgs,

    max_array_size = max_array_size,
    setup_lines = setup_lines
  )
}

#' Step Template to Create a Single Sim File per Scenarios Using the Files From
#' `EpiModel::netsim_scenarios()`
#'
#' @param n_cores Parallelize the process over `n_cores` (default = 1)
#'
#' @inheritParams slurmworkflow::step_tmpl_map
#' @inheritParams EpiModel::merge_netsim_scenarios
#'
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_merge_netsim_scenarios <- function(sim_dir, output_dir,
                                             keep.transmat = TRUE,
                                             keep.network = TRUE,
                                             keep.nwstats = TRUE,
                                             keep.other = TRUE,
                                             param.error = FALSE,
                                             keep.diss.stats = TRUE,
                                             truncate.at = NULL, n_cores = 1,
                                             setup_lines = NULL,
                                             keep.run = TRUE,
                                             keep.cumulative.edgelist = FALSE,
                                             keep.attr.history = TRUE) {

  merge_fun <- function(n_cores, ...) {
    future::plan("multicore", workers = n_cores)
    options(future.globals.maxSize = Inf)
    EpiModel::merge_netsim_scenarios(...)
  }

  slurmworkflow::step_tmpl_do_call(
    what = merge_fun,
    args = list(
      n_cores = n_cores,
      sim_dir = sim_dir,
      output_dir = output_dir,
      keep.transmat = keep.transmat,
      keep.network = keep.network,
      keep.nwstats = keep.nwstats,
      keep.other = keep.other,
      param.error = param.error,
      keep.diss.stats = keep.diss.stats,
      truncate.at = truncate.at,
      keep.run = keep.run,
      keep.cumulative.edgelist = keep.cumulative.edgelist,
      keep.attr.history = keep.attr.history
    ),
    setup_lines = setup_lines
  )
}

#' Step Template to Create a Single Sim File per Scenarios Using the Files From
#' `EpiModel::netsim_scenarios()`
#'
#' @param n_cores Parallelize the process over `n_cores` (default = 1)
#'
#' @inheritParams slurmworkflow::step_tmpl_map
#' @inheritParams EpiModel::merge_netsim_scenarios_tibble
#'
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_merge_netsim_scenarios_tibble <- function(
                      sim_dir, output_dir, steps_to_keep,
                      cols = dplyr::everything(), n_cores = 1,
                      setup_lines = NULL) {
  merge_fun <- function(sim_dir, output_dir, steps_to_keep, cols, n_cores) {
    future::plan("multicore", workers = n_cores)
    options(future.globals.maxSize = Inf)
    EpiModel::merge_netsim_scenarios_tibble(
      sim_dir = sim_dir,
      output_dir = output_dir,
      steps_to_keep = steps_to_keep,
      cols = {{ cols }}
    )
  }

  slurmworkflow::step_tmpl_do_call(
    what = merge_fun,
    args = list(
      sim_dir = sim_dir,
      output_dir = output_dir,
      steps_to_keep = steps_to_keep,
      cols = rlang::enquo(cols),
      n_cores = n_cores
    ),
    setup_lines = setup_lines
  )
}
