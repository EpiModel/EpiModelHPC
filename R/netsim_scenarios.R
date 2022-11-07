#' Function to run EpiModel network simulations with scenarios
#'
#' This function will run \code{n_rep} replications of each scenarios in
#' the \code{scenarios_list}. It runs them as multiple batches of up to
#' \code{n_cores} simulations at a time. The simfiles are then stored in the
#' \code{output_dir} folder and are named using the following pattern:
#' "sim__name_of_scenario__2.Rds". Where the last number is the batch number
#' for this particular scenario. Each scenario is therefore run over
#' \code{ceiling(n_rep / n_cores)} batches.
#' This function is meant to mimic the behavior of
#' \code{step_tmpl_netsim_scenarios} in your local machine. It should fail
#' in a similar fashion an reciprocally, if it runs correctly locally, moving
#' to HPC should not produce an issue.
#'
#' @param scenarios_list A list of scenarios to be run. Produced by the
#'   \code{EpiModel::create_scenario_list} function
#' @param n_rep The number of replication to be run for each scenario.
#' @param n_cores The number of CPUs on which the simulations will be run for
#'   each node on the HPC
#' @param output_dir The folder where the simulation files are to be stored on
#'   the HPC
#' @param libraries A character vector containing the name of the libraries
#'   required for the model to run. (e.g. EpiModelHIV or EpiModelCOVID)
#' @param save_pattern A character vector of what should be kept in the final
#'   \code{sim} objects. It can contain the names of the elements as well as:
#'   "simple" (defautlt) to only "epi", "param" and "control"; "restart" to get
#'   the elements required to restart from such file; "all" to not trim the
#'   object at all. `c("simple", "el.cuml")` is an example of a valid pattern to
#'   save "epi", "param", "control" and "el.cuml".
#'
#' @inheritParams EpiModel::netsim
#'
#' @export
netsim_scenarios <- function(x, param, init, control,
                             scenarios_list, n_rep, n_cores,
                             output_dir, libraries = NULL,
                             save_pattern = "simple") {
  p_list <- netsim_scenarios_setup(x, param, init, control,
                                   scenarios_list, n_rep, n_cores,
                                   output_dir, libraries, save_pattern)
  for (i in seq_along(p_list$scenarios_list)) {
    args <- list(p_list$scenarios_list[[i]], p_list$batchs_list[[i]])
    args <- c(args, p_list$MoreArgs)
    callr::r(do.call, args = list(netsim_run_one_scenario, args), show = TRUE)
  }
}

#' Helper function to configure `netsim_run_one_scenario`
netsim_scenarios_setup <- function(est, param, init, control,
                                   scenarios_list, n_rep, n_cores,
                                   output_dir, libraries, save_pattern) {
  libraries <- c("slurmworkflow", "EpiModelHPC", libraries)
  if (is.null(scenarios_list)) {
    scenarios_list <- data.frame(.at = 0, .scenario.id = "empty_scenario")
    scenarios_list <- EpiModel::create_scenario_list(scenarios_list)
  }

  n_batch <- ceiling(n_rep / n_cores)
  batchs_list <- rep(seq_len(n_batch), length(scenarios_list))
  scenarios_list <- rep(scenarios_list, each = n_batch)

  save_elements <- character(0)
  save_all <- "all" %in% save_pattern
  if (!save_all)
    save_elements <- make_save_elements(save_pattern)

  list(
    scenarios_list = scenarios_list,
    batchs_list = batchs_list,
    MoreArgs = list(
      est = est,
      param = param,
      init = init,
      control = control,
      libraries = libraries,
      output_dir = output_dir,
      n_batch = n_batch,
      n_rep = n_rep,
      n_cores = n_cores,
      save_all = save_all,
      save_elements = save_elements
    )
  )
}

#' Create the `save_elements` character vector according to the `save_pattern`
make_save_elements <- function(save_pattern) {
  save_elements <- save_pattern
  if ("simple" %in% save_pattern) {
    save_elements <- union(save_elements, c("param", "epi", "control"))
    save_elements <- setdiff(save_elements, "simple")
  }
  if ("restart" %in% save_pattern) {
    need_restart <- c(
      "param", "control", "nwparam",
      "epi", "attr", "temp",
      "el", "el.cuml"
    )
    save_elements <- union(save_elements, need_restart)
    save_elements <- setdiff(save_elements, "restart")
  }
  return(save_elements)
}

#' Inner function called by `netsim_scenarios` and `step_tmpl_netsim_scenarios`
netsim_run_one_scenario <- function(scenario, batch_num,
                                    est, param, init, control,
                                    libraries, output_dir,
                                    n_batch, n_rep, n_cores,
                                    save_all, save_elements) {
  start_time <- Sys.time()
  lapply(libraries, function(l) library(l, character.only = TRUE))

  if (!fs::dir_exists(output_dir))
    fs::dir_create(output_dir, recurse = TRUE)

  # On last batch, adjust the number of simulation to be run
  if (batch_num == n_batch)
    n_cores <- n_rep - n_cores * (n_batch - 1)

  param_sc <- EpiModel::use_scenario(param, scenario)
  control$nsims <- n_cores
  control$ncores <- n_cores

  if (!is.null(control[[".checkpoint.dir"]])) {
    control[[".checkpoint.dir"]] <- paste0(
      control[[".checkpoint.dir"]], "/batch_", batch_num, ""
    )
  }

  print(paste0("Starting simulation for scenario: ", scenario[["id"]]))
  print(paste0("Batch number: ", batch_num, " / ", n_batch))
  sim <- EpiModel::netsim(est, param_sc, init, control)

  if (!save_all) {
    print(paste0(
      "Triming simulation in file to keep only: `",
      paste0(save_elements, collapse = "`, `"),
      "`"
    ))
    remove_elts <- setdiff(names(sim), save_elements)
    sim[remove_elts] <- NULL
  }

  file_name <- paste0("sim__", scenario[["id"]], "__", batch_num, ".rds")
  print(paste0("Saving simulation in file: ", file_name))
  saveRDS(sim, fs::path(output_dir, file_name))

  print("Done in: ")
  print(Sys.time() - start_time)
}
