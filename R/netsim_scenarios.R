#' Step template to run EpiModel network simulations with scenarios
#'
#' This step template is similar to `netsim_scenarios` but for the HPC. It uses
#' `slurmworkflow::step_tmpl_map` internally and should be used as any
#' `slurmworkflow` step. For details, see `netsim_scenarios` documentation.
#'
#' @inheritParams slurmworkflow::step_tmpl_map
#' @inheritParams netsim_scenarios
#'
#' @inheritSection netsim_run_one_scenario Checkpointing
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_netsim_scenarios <- function(path_to_x, param, init, control,
                                       scenarios_list, n_rep, n_cores,
                                       output_dir, libraries = NULL,
                                       save_pattern = "simple",
                                       setup_lines = NULL,
                                       max_array_size = NULL) {
  p_list <- netsim_scenarios_setup(
    path_to_x, param, init, control,
    scenarios_list, n_rep, n_cores,
    output_dir, libraries, save_pattern
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

#' Function to run EpiModel network simulations with scenarios
#'
#' This function will run `n_rep` replications of each scenarios in
#' the `scenarios_list`. It runs them as multiple batches of up to
#' `n_cores` simulations at a time. The simfiles are then stored in the
#' `output_dir` folder and are named using the following pattern:
#' "sim__name_of_scenario__2.rds". Where the last number is the batch number
#' for this particular scenario. Each scenario is therefore run over
#' `ceiling(n_rep / n_cores)` batches.
#' This function is meant to mimic the behavior of
#' `step_tmpl_netsim_scenarios` in your local machine. It should fail
#' in a similar fashion an reciprocally, if it runs correctly locally, moving
#' to an HPC should not produce any issue.
#'
#' @param scenarios_list A list of scenarios to be run. Produced by the
#'   \code{EpiModel::create_scenario_list} function
#'
#' @inheritParams netsim_run_one_scenario
#' @inheritParams make_save_elements
#' @inheritSection netsim_run_one_scenario Checkpointing
#'
#' @export
netsim_scenarios <- function(path_to_x, param, init, control,
                             scenarios_list, n_rep, n_cores,
                             output_dir, libraries = NULL,
                             save_pattern = "simple") {
  p_list <- netsim_scenarios_setup(
    path_to_x, param, init, control,
    scenarios_list, n_rep, n_cores,
    output_dir, libraries, save_pattern
  )

  for (i in seq_along(p_list$scenarios_list)) {
    args <- list(p_list$scenarios_list[[i]], p_list$batchs_list[[i]])
    args <- c(args, p_list$MoreArgs)
    callr::r(do.call, args = list(netsim_run_one_scenario, args), show = TRUE)
  }
}

#' Helper function to  create the parameters for `netsim_run_one_scenario`
#'
#' @inheritParams netsim_scenarios
#'
#' @return a list of arguments for `netsim_run_one_scenario`
netsim_scenarios_setup <- function(path_to_x, param, init, control,
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

  raw_output <- !is.null(control[["raw.output"]]) && control[["raw.output"]]
  save_all <- "all" %in% save_pattern || raw_output
  save_elts <- if (save_all) character() else make_save_elements(save_pattern)

  list(
    scenarios_list = scenarios_list,
    batchs_list = batchs_list,
    MoreArgs = list(
      path_to_x = path_to_x,
      param = param,
      init = init,
      control = control,
      libraries = libraries,
      output_dir = output_dir,
      n_batch = n_batch,
      n_rep = n_rep,
      n_cores = n_cores,
      save_all = save_all,
      save_elements = save_elts
    )
  )
}

#' Create the `save_elements` vector for `netsim_run_one_scenario`
#'
#' Helper function to create the `save_elements` character vector according to
#' the `save_pattern`.
#'
#' @param save_pattern A character vector of what should be kept in the final
#'   `netsim` objects. It can contain the names of the elements as well as:
#'   "simple" (defautlt) to only keep "epi", "param" and "control"; "restart" to
#'   get the elements required to restart from such file; "all" to not trim the
#'   object at all. `c("simple", "el.cuml")` is an example of a valid pattern to
#'   save "epi", "param", "control" and "el.cuml". If `control$raw.output` is
#'   `TRUE`, this parameter has no effect and the full result is saved.
make_save_elements <- function(save_pattern) {
  save_elements <- save_pattern
  if ("simple" %in% save_pattern) {
    save_elements <- union(save_elements, c("param", "epi", "control"))
    save_elements <- setdiff(save_elements, "simple")
  }
  if ("restart" %in% save_pattern) {
    need_restart <- c(
      "param", "control", "epi",
      "nwparam", "attr", "temp", "net_attr",
      "el", "el.cuml", "_last_unique_id",
      "coef.form", "num.nw", "el", "network"
    )
    save_elements <- union(save_elements, need_restart)
    save_elements <- setdiff(save_elements, "restart")
  }

  save_elements
}

#' Run one `netsim` call with a scenario and saves the results deterministically
#'
#' This inner function is called by `netsim_scenarios` and
#' `step_tmpl_netsim_scenarios`.
#'
#' @param path_to_x Path to a Fitted network model object saved with `saveRDS`.
#'   (See the `x` argument to the `EpiModel::netsim` function)
#' @param scenario A single "`EpiModel` scenario" to be used in the simulation
#' @param batch_num The batch number, calculated from the number of replications
#'   and CPUs required.
#' @param n_batch The number of batches to be run `ceiling(n_rep / n_cores)`.
#' @param n_rep The number of replication to be run for each scenario.
#' @param n_cores The number of CPUs on which the simulations will be run.
#' @param output_dir The folder where the simulation files are to be stored.
#' @param libraries A character vector containing the name of the libraries
#'   required for the model to run. (e.g. EpiModelHIV or EpiModelCOVID)
#' @param save_all A flag instructing to save the result of the
#'   `EpiModel::netsim` call as is if TRUE.
#' @param save_elements A character vector of elements to keep from the
#'   `netsim` object if `save_all` is `FALSE`
#' @inheritParams EpiModel::netsim
#'
#' @section Checkpointing:
#' This function takes care of editing `.checkpoint.dir` to create unique sub
#' directories for each scenario. The `EpiModel::control.net` way of setting up
#' checkpoints can be used transparently.
netsim_run_one_scenario <- function(scenario, batch_num,
                                    path_to_x, param, init, control,
                                    libraries, output_dir,
                                    n_batch, n_rep, n_cores,
                                    save_all, save_elements) {
  est <- readRDS(path_to_x)
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
      control[[".checkpoint.dir"]], "/sim__", scenario[["id"]], "__", batch_num
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

#' Helper function to access the file name elements of scenarios
#'
#' This function returns the list of simulation files and the corresponding
#' scenario name and batch number present in a given directory. It is meant to
#' be used after `netsim_scenarios` or `step_tmpl_netsim_scenarios`.
#'
#' @param scenario_dir the directory where `netsim_scenarios` saved it's
#' simulations.
#'
#' @return a `tibble` with three columns: `file_path` - the full paths of
#' the simulation file, `scenario_name` the associated scenario name,
#' `batch_number` the associated batch number.
#'
#' @export
get_scenarios_batches_infos <- function(scenario_dir) {
  file_name_list <- fs::dir_ls(
    scenario_dir,
    regexp = "/sim__.*rds$",
    type = "file"
  )

  parts <- dplyr::tibble(
    file_path = file_name_list,
    simple_name = fs::path_ext_remove(.data$file_name)
  )

  tidyr::separate(
    parts,
    .data$simple_name, sep = "__", remove = TRUE,
    into = c(NA, "scenario_name", "batch_number")
  )
}


#' Create a Single Sim File per Scenarios Using the Files From
#' `netsim_scenarios`
#'
#' @param sim_dir The folder where the simulation files are to be stored.
#' @param output_dir The folder where the merged files will be stored.
#' @param truncate.at Time step at which to left-truncate the time series.
#'
#' @inheritParams EpiModel::merge.netsim
#'
#' @export
merge_netsim_scenarios <- function(sim_dir, output_dir,
                                   keep.transmat = TRUE, keep.network = TRUE,
                                   keep.nwstats = TRUE, keep.other = TRUE,
                                   param.error = FALSE, keep.diss.stats = TRUE,
                                   truncate.at = NULL) {

  if (!fs::dir_exists(output_dir)) fs::dir_create(output_dir)
  batches_infos <- EpiModelHPC::get_scenarios_batches_infos(sim_dir)

  future.apply::future_lapply(
    unique(batches_infos$scenario_name),
    function(scenario) {
      scenario_infos <- dplyr::filter(
        batches_infos,
        .data$scenario_name == scenario
      )
      file_paths <- scenario_infos$file_name
      for (j in seq_along(file_paths)) {
        current <- readRDS(file_paths[j])
        if (!is.null(truncate.at)) {
          current <- EpiModel::truncate_sim(current, truncate.at)
        }

        if (j == 1) {
          merged <- current
        } else {
          merged <- merge(
            merged, current,
            keep.transmat = keep.transmat,
            keep.network = keep.network,
            keep.nwstats = keep.nwstats,
            keep.other = keep.other,
            param.error = param.error,
            keep.diss.stats = keep.diss.stats
          )
        }

        saveRDS(
          merged,
          fs::path(output_dir, paste0("merged__", scenario, ".rds"))
        )
      }
  })
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
step_tmpl_merge_netsim_scenarios <- function(sim_dir, output_dir,
                                             keep.transmat = TRUE,
                                             keep.network = TRUE,
                                             keep.nwstats = TRUE,
                                             keep.other = TRUE,
                                             param.error = FALSE,
                                             keep.diss.stats = TRUE,
                                             truncate.at = NULL, n_cores = 1,
                                             setup_lines = NULL) {

  merge_fun <- function(sim_dir, output_dir, keep.transmat, keep.network,
                        keep.nwstats, keep.other, param.error, keep.diss.stats,
                        truncate.at, n_cores) {
    future::plan("multicore", workers = n_cores)
    EpiModelHPC::merge_netsim_scenarios(
      sim_dir, output_dir,
      keep.transmat, keep.network, keep.nwstats, keep.other, keep.diss.stats,
      param.error, truncate.at
    )
  }

  slurmworkflow::step_tmpl_do_call(
    what = merge_fun,
    args = list(
      sim_dir, output_dir,
      keep.transmat, keep.network, keep.nwstats, keep.other, keep.diss.stats,
      param.error, truncate.at, n_cores),
    setup_lines = setup_lines
  )
}

#' Create a Single Sim File per Scenarios Using the Files From
#' `netsim_scenarios`
#'
#' @param steps_to_keep Numbers of time steps add the end of the simulation to
#'   keep in the `data.frame`.
#' @param cols <tidy-select> columns to keep in the `data.frame`. By default all
#'    columns are kept. And in any case, the `batch_number`, `sim` and `time`
#'    are always kept.
#'
#' @inheritParams merge_netsim_scenarios
#'
#' @export
merge_netsim_scenarios_tibble <- function(sim_dir, output_dir, steps_to_keep,
                                          cols = dplyr::everything()) {
  expr <- rlang::enquo(cols)
  if (!fs::dir_exists(output_dir)) fs::dir_create(output_dir)
  batches_infos <- EpiModelHPC::get_scenarios_batches_infos(sim_dir)

  for (scenario in unique(batches_infos$scenario_name)) {
    scenario_infos <- dplyr::filter(
      batches_infos,
      .data$scenario_name == scenario
    )

    df_list <- future.apply::future_lapply(
      seq_len(nrow(scenario_infos)),
      function(i) {
        sc_inf <- scenario_infos[i, ]
        d <- readRDS(sc_inf$file_name) |>
          dplyr::as_tibble() |>
          dplyr::filter(.data$time >= max(.data$time) - steps_to_keep)

        d_fix <- dplyr::select(d, "sim", "time")
        d_var <- dplyr::select(d, -c("sim", "time"))

        pos <- tidyselect::eval_select(expr, data = d_var)
        d_var <- rlang::set_names(d_var[pos], names(pos))

        dplyr::bind_cols(d_fix, d_var) |>
          dplyr::mutate(,
            batch_number = sc_inf$batch_number) |>
          dplyr::select("batch_number", "sim", "time", dplyr::everything())
      }
    )
    df_sc <- dplyr::bind_rows(df_list)
    saveRDS(df_sc, fs::path(output_dir, paste0("df__", scenario, ".rds")))
  }
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
                      sim_dir, output_dir, steps_to_keep,
                      cols = dplyr::everything(), n_cores = 1,
                      setup_lines = NULL) {
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
    args = list(sim_dir, output_dir, steps_to_keep, rlang::enquo(cols), n_cores),
    setup_lines = setup_lines
  )
}

#' Helper function to access the infos on merged scenarios `data.frame`
#'
#' This function returns the list of scenario tibble files and the corresponding
#' scenario name present in a given directory. It is meant to
#' be used after `merge_netsim_scenarios_tibble` or
#' `step_tmpl_merge_netsim_scenarios_tibble`.
#'
#' @param scenario_dir the directory where `merge_netsim_scenarios_tibble` saved
#' the merged tibbles.
#'
#' @return a `tibble` with two columns: `file_path` - the full path of
#' the scenario tibble file and `scenario_name` the associated scenario name.
#'
#' @export
get_scenarios_tibble_infos <- function(scenario_dir) {
  file_name_list <- fs::dir_ls(
    scenario_dir,
    regexp = "/df__.*rds$",
    type = "file"
  )

  parts <- dplyr::tibble(
    file_path = file_name_list,
    simple_name = fs::path_ext_remove(.data$file_name)
  )

  tidyr::separate(
    parts,
    .data$simple_name, sep = "__", remove = TRUE,
    into = c(NA, "scenario_name")
  )
}
