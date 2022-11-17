#' Run one `netsim` call with the result of an `swfcalib` calibration
#'
#' @inheritParams swfcalib:::get_default_proposal
#' @inheritParams netsim_run_one_scenario
netsim_run_swfcalib_scenario <- function(calib_object, batch_num,
                                         x, param, init, control,
                                         libraries, output_dir,
                                         n_batch, n_rep, n_cores,
                                         save_all, save_elements) {
  scenario <- make_calibrated_scenario(calib_object)
  netsim_run_one_scenario(
    scenario, batch_num, x, param, init, control,
    libraries, output_dir, n_batch, n_rep, n_cores, save_all, save_elements
  )
}

#' Make an EpiModel scenario using the result of an `swfcalib` calibration
#'
#' @inheritParams swfcalib:::get_default_proposal
make_calibrated_scenario <- function(calib_object) {
  calib_object <- swfcalib:::load_calib_object(calib_object)
  calibrated_scenario <- swfcalib:::get_default_proposal(calib_object)
  calibrated_scenario[[".at"]] <- 1
  calibrated_scenario[[".scenario.id"]] <- "calibrated"
  EpiModel::create_scenario_list(calibrated_scenario)[[1]]
}


#' Helper function to  create the parameters for `netsim_run_swfcalib_scenario`
#'
#' @inheritParams swfcalib:::get_default_proposal
#' @inheritParams netsim_scenarios_setup
netsim_swfcalib_output_setup <- function(x, param, init, control,
                                         calib_object, n_rep, n_cores,
                                         output_dir, libraries, save_pattern) {
  scenarios_list <- NULL
  p_list <- netsim_scenarios_setup(
    x, param, init, control,
    scenarios_list, n_rep, n_cores,
    output_dir, libraries, save_pattern
  )
  p_list$scenarios_list <- NULL
  p_list$MoreArgs$calib_object <- calib_object
  p_list
}

#' Step template to run sims with the result of an `swfcalib` calibration
#'
#' @inheritParams step_tmpl_netsim_scenarios
#' @inheritParams swfcalib:::get_default_proposal
#'
#' @inheritSection netsim_run_one_scenario Checkpointing
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_netsim_swfcalib_output <- function(x, param, init, control,
                                             calib_object, n_rep, n_cores,
                                             output_dir, libraries = NULL,
                                             save_pattern = "simple",
                                             setup_lines = NULL,
                                             max_array_size = NULL) {
  p_list <- netsim_swfcalib_output_setup(
    x, param, init, control,
    calib_object, n_rep, n_cores,
    output_dir, libraries, save_pattern
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
#' @inheritParams netsim_scenarios
#' @inheritParams swfcalib:::get_default_proposal
#'
#' @inheritSection netsim_run_one_scenario Checkpointing
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
netsim_swfcalib_output <- function(x, param, init, control,
                                   calib_object, n_rep, n_cores,
                                   output_dir, libraries = NULL,
                                   save_pattern = "simple") {
  p_list <- netsim_swfcalib_output_setup(
    x, param, init, control,
    calib_object, n_rep, n_cores,
    output_dir, libraries, save_pattern
  )

  for (i in seq_along(p_list$scenarios_list)) {
    args <- list(p_list$batchs_list[[i]])
    args <- c(args, p_list$MoreArgs)
    callr::r(do.call, args = list(netsim_run_swfcalib_scenario, args), show = TRUE)
  }
}
