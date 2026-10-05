add_to_restart_pool <- function(sims, pool_dir) {
  if (!dir.exists(pool_dir)) {
    message("Creating a new restart pool at: \n\"", pool_dir, "\"")
    dir.create(pool_dir)
    pool_last <- 0
  } else {
    pool <- list.files(pool_dir, "^\\d+\\.rds$")
    pool_nums <- as.numeric(sub("\\.rds", "", pool))
    pool_last <- max(pool_nums)
  }
  for (i in seq_along(sims)) {
    saveRDS(sims[[i]], paste0(pool_dir, "/", pool_last + i, ".rds"))
  }
}

#' @export
make_restart_pool <- function(
  pool_dir,
  scenarios_dir,
  scenario_name,
  keep_sims,
  time_attrs
) {
  if (dir.exists(pool_dir)) {
    stop("A restart pool at this location already exists")
  }
  b_infos <- EpiModelHPC::get_scenarios_batches_infos(scenarios_dir)
  b_infos <- b_infos[b_infos$scenario_name == scenario_name, , drop = FALSE]
  for (batch in unique(keep_sims$batch_number)) {
    batch_path <- b_infos$file_path[b_infos$batch_number == batch]
    sims <- lapply(
      sort(unique(keep_sims$sim_number[keep_sims$batch_number == batch])),
      make_restart_point,
      sim_obj = readRDS(batch_path),
      time_attrs = time_attrs
    )
    add_to_restart_pool(sims, pool_dir)
  }
}

#' @export
netsim_path_wrapper <- function(path_to_x, param, init, control, sim_nums) {
  control$nsims <- 1
  control$ncores <- 1
  control$future.use.plan <- FALSE

  if (dir.exists(path_to_x)) {
    # case: point to a dir of start objects
    size <- length(list.files(path_to_x, "^\\d+\\.rds$"))
    start_nums <- (sim_nums - 1) %% size + 1
    orig_paths <- paste0(path_to_x, "/", start_nums, ".rds")
    if (!all(file.exists(orig_paths))) {
      stop("Error in the restart paths. Check the directory.")
    }
  } else if (file.exists(path_to_x)) {
    # case: it's a file
    orig_paths <- rep(path_to_x, length(sim_nums))
  } else {
    stop("`path_to_x` points to neither of file or directory.")
  }
  sim_list <- future.apply::future_lapply(
    orig_paths,
    function(orig_path) {
      EpiModel::netsim(readRDS(orig_path), param, init, control)
    },
    future.seed = TRUE
  )
  sim_list
}

netsim_run_one_scenario_path <- function(
  scenario,
  batch_num,
  path_to_x,
  param,
  init,
  control,
  libraries,
  output_dir,
  n_batch,
  n_rep,
  n_cores
) {
  start_time <- Sys.time()
  lapply(libraries, function(l) library(l, character.only = TRUE))

  if (!fs::dir_exists(output_dir)) {
    fs::dir_create(output_dir, recurse = TRUE)
  }

  sim_nums_offset <- (batch_num - 1) * n_cores
  # On last batch, adjust the number of simulation to be run
  if (batch_num == n_batch) {
    n_cores <- n_rep - n_cores * (n_batch - 1)
  }
  sim_nums <- sim_nums_offset + seq_len(n_cores)
  param_sc <- EpiModel::use_scenario(param, scenario)

  # NOTE: break chekcpoints
  print(paste0("Starting simulation for scenario: ", scenario[["id"]]))
  print(paste0("Batch number: ", batch_num, " / ", n_batch))

  with(future::plan("multicore", workers = n_cores), local = TRUE)
  sim <- netsim_path_wrapper(path_to_x, param_sc, init, control, sim_nums) |>
    Reduce(f = merge.netsim)

  file_name <- paste0("sim__", scenario[["id"]], "__", batch_num, ".rds")
  print(paste0("Saving simulation in file: ", file_name))
  saveRDS(sim, fs::path(output_dir, file_name))

  print("Done in: ")
  print(Sys.time() - start_time)
}
