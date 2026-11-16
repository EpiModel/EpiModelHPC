#' Run one `netsim` call with the result of an `swfcalib` calibration
#'
#' @inheritParams swfcalib::calibration_step1
#' @inheritParams EpiModel::internal_run_batch
netsim_run_swfcalib_scenario <- function(calib_object, batch_num,
                                         path_to_x, param, init, control,
                                         libraries, output_dir,
                                         n_batch, n_rep, n_cores) {
  scenario <- make_calibrated_scenario(calib_object)
  EpiModel::internal_run_batch(
    scenario = scenario,
    batch_num = batch_num,
    path_to_x = path_to_x,
    param = param,
    init = init,
    control = control,
    libraries = libraries,
    output_dir = output_dir,
    n_batch = n_batch,
    n_rep = n_rep,
    n_cores = n_cores
  )
}

#' Make an EpiModel scenario using the result of an `swfcalib` calibration
#'
#' @inheritParams swfcalib::calibration_step1
make_calibrated_scenario <- function(calib_object) {
  calib_object <- swfcalib:::load_calib_object(calib_object)
  calibrated_scenario <- swfcalib:::get_default_proposal(calib_object)
  swfcalib_proposal_to_scenario(calibrated_scenario)
}


#' Helper function to  create the parameters for `netsim_run_swfcalib_scenario`
#'
#' @inheritParams swfcalib::calibration_step1
#' @inheritParams EpiModel::internal_scenarios_setup
netsim_swfcalib_output_setup <- function(path_to_x, param, init, control,
                                         calib_object, n_rep, n_cores,
                                         output_dir, libraries) {
  scenarios_list <- NULL
  # `EpiModel::internal_scenarios_setup()` does not add the HPC libraries to
  # `libraries`: the calibration output runs on the HPC.
  p_list <- EpiModel::internal_scenarios_setup(
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
  p_list$scenarios_list <- NULL
  p_list$MoreArgs$calib_object <- calib_object
  p_list
}

#' Step template to run sims with the result of an `swfcalib` calibration
#'
#' The simulations of a batch are run in parallel, one `netsim` call per
#' simulation (see `EpiModel::netsim_path_wrapper()`), by default with
#' `future::plan("multicore", workers = n_cores)`.
#' Using `control$future.use.plan <- future::tweak(<your plan>)` will bypass
#' this setting.
#'
#' @inheritParams step_tmpl_netsim_scenarios
#' @inheritParams swfcalib::calibration_step1
#'
#' @inheritSection EpiModel::internal_run_batch Checkpointing
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_netsim_swfcalib_output <- function(path_to_x, param, init, control,
                                             calib_object, n_rep, n_cores,
                                             output_dir, libraries = NULL,
                                             setup_lines = NULL,
                                             max_array_size = NULL) {
  control$future.use.plan <- EpiModel::internal_batch_plan(
    control, future::multicore, n_cores
  )

  p_list <- netsim_swfcalib_output_setup(
    path_to_x = path_to_x,
    param = param,
    init = init,
    control = control,
    calib_object = calib_object,
    n_rep = n_rep,
    n_cores = n_cores,
    output_dir = output_dir,
    libraries = libraries
  )

  slurmworkflow::step_tmpl_map(
    FUN = netsim_run_swfcalib_scenario,
    batch_num = p_list$batchs_list,
    MoreArgs = p_list$MoreArgs,
    max_array_size = max_array_size,
    setup_lines = setup_lines
  )
}

#' Function to run an EpiModel sim with the result of an `swfcalib` calibration
#'
#' The batches are run one after the other in the current R session, without a
#' subprocess (see `EpiModel::netsim_scenarios()` for the same local
#' equivalent). Within a batch, the simulations run in parallel, one `netsim`
#' call per simulation (see `EpiModel::netsim_path_wrapper()`), by default with
#' `future::plan("multisession", workers = n_cores)`. Unlike the `multicore`
#' default of `step_tmpl_netsim_swfcalib_output`, this also runs in parallel
#' from RStudio and on Windows.
#' Using `control$future.use.plan <- future::tweak(<your plan>)` will bypass
#' this setting.
#'
#' @inheritParams EpiModel::netsim_scenarios
#' @inheritParams swfcalib::calibration_step1
#'
#' @inheritSection EpiModel::internal_run_batch Checkpointing
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
netsim_swfcalib_output <- function(path_to_x, param, init, control,
                                   calib_object, n_rep, n_cores,
                                   output_dir, libraries = NULL) {
  p_list <- netsim_swfcalib_output_setup(
    path_to_x = path_to_x,
    param = param,
    init = init,
    control = control,
    calib_object = calib_object,
    n_rep = n_rep,
    n_cores = n_cores,
    output_dir = output_dir,
    libraries = libraries
  )

  for (batch in p_list$batchs_list) {
    # `batch_num` is passed by name as `calib_object` comes first in the
    # signature and is already in `MoreArgs`.
    do.call(
      netsim_run_swfcalib_scenario,
      c(list(batch_num = batch), p_list$MoreArgs)
    )
  }

  invisible(NULL)
}

#' Convert an swfcalib Proposal into an EpiModel Scenario
#'
#' @param proposal an swfcalib formatted proposal
#' @param id the `.scenario.id` for the scenario. If `NULL`, use the
#'   `.proposal_index` or "default" if the former is `NULL` as well.
#' @return an EpiModel scenario
#'
#' @export
swfcalib_proposal_to_scenario <- function(proposal, id = NULL) {
  scenario_df <- proposal

  scenario_df[[".scenario.id"]] <- if (!is.null(id)) {
    id
  } else if (is.null(proposal[[".proposal_index"]])) {
    "default"
  } else {
    proposal[[".proposal_index"]]
  }

  scenario_df[[".at"]] <- 1L
  scenario_df[[".proposal_index"]] <- NULL
  scenario_df[[".wave"]] <- NULL
  scenario_df[[".iteration"]] <- NULL
  EpiModel::create_scenario_list(scenario_df)[[1]]
}
