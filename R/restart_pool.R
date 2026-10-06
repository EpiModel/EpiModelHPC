# File names of the `<n>.rds` elements of a restart pool directory, in order
get_restart_pool_files <- function(pool_dir) {
  pool <- list.files(pool_dir, "^\\d+\\.rds$")
  pool[order(as.integer(sub("\\.rds$", "", pool)))]
}

# Save each element of `sims` as the next numbered file of the restart pool at
# `pool_dir`. The directory is created if needed.
add_to_restart_pool <- function(sims, pool_dir) {
  if (!fs::dir_exists(pool_dir)) {
    message("Creating a new restart pool at: \n\"", pool_dir, "\"")
    fs::dir_create(pool_dir, recurse = TRUE)
  }
  pool_last <- length(pool)
  for (i in seq_along(sims)) {
    saveRDS(sims[[i]], fs::path(pool_dir, paste0(pool_last + i, ".rds")))
  }
  invisible(pool_last + seq_along(sims))
}

#' Make a Restart Pool From Simulations Run With Scenarios
#'
#' Creates a directory of single simulation restart points (`1.rds`, `2.rds`,
#' ...) from the batch files written by `netsim_scenarios`,
#' `step_tmpl_netsim_scenarios` or `step_tmpl_netsim_swfcalib_output`. Such a
#' directory can be passed as `path_to_x` to these functions (see
#' `netsim_path_wrapper`).
#'
#' Pool element `i` is made from row `i` of `keep_sims`, with
#' `EpiModel::make_restart_point` (keeping only the last time step). Each batch
#' file is read once. The pool directory also receives a `pool_index.csv` file
#' with one row per pool element: `pool_num`, `scenario_name`, `batch_number`,
#' `sim_number` and `file_path` (the batch file it was made from).
#'
#' If an error occurs while writing the pool, the partial pool directory is
#' removed.
#'
#' @param pool_dir Path to the restart pool directory to create. It must not
#'   exist.
#' @param scenarios_dir The directory containing the
#'   `sim__<scenario>__<batch>.rds` files.
#' @param scenario_name The name of the scenario to make the pool from.
#' @param keep_sims A `data.frame` with a `batch_number` and a `sim_number`
#'   column, one row per simulation to put in the pool. `sim_number` is the
#'   position of the simulation within its batch file (the `sim_number`
#'   column of `merge_netsim_scenarios_tibble`, not the `sim` one).
#' @param time_attrs A character vector of the attributes holding time steps,
#'   passed to `EpiModel::make_restart_point`.
#'
#' @return The pool index `data.frame` (invisibly).
#'
#' @seealso [validate_restart_pool()], [netsim_path_wrapper()]
#'
#' @examples
#' \dontrun{
#' d_sim <- readRDS("data/run/calib/merged_tibbles/df__default.rds")
#' keep_sims <- dplyr::distinct(d_sim, batch_number, sim_number)[1:32, ]
#' make_restart_pool(
#'   pool_dir = "data/run/restart_pool",
#'   scenarios_dir = "data/run/calib",
#'   scenario_name = "default",
#'   keep_sims = keep_sims,
#'   time_attrs = c("infTime")
#' )
#' validate_restart_pool("data/run/restart_pool")
#' }
#'
#' @export
make_restart_pool <- function(
  pool_dir,
  scenarios_dir,
  scenario_name,
  keep_sims,
  time_attrs
) {
  if (fs::dir_exists(pool_dir)) {
    stop("A restart pool already exists at: \"", pool_dir, "\"")
  }
  if (!all(c("batch_number", "sim_number") %in% names(keep_sims))) {
    stop("`keep_sims` must have a `batch_number` and a `sim_number` column")
  }
  if (nrow(keep_sims) == 0) {
    stop("`keep_sims` has no rows")
  }
  if (anyDuplicated(keep_sims[c("batch_number", "sim_number")]) > 0) {
    stop("`keep_sims` contains the same simulation more than once")
  }

  b_infos <- EpiModelHPC::get_scenarios_batches_infos(scenarios_dir)
  b_infos <- b_infos[b_infos$scenario_name == scenario_name, , drop = FALSE]
  missing_batches <- setdiff(keep_sims$batch_number, b_infos$batch_number)
  if (length(missing_batches) > 0) {
    stop(
      "No simulation file for scenario \"", scenario_name, "\" and batch(es) ",
      paste(missing_batches, collapse = ", "), " in \"", scenarios_dir, "\""
    )
  }

  restart_points <- vector("list", nrow(keep_sims))
  file_paths <- character(nrow(keep_sims))
  for (batch in unique(keep_sims$batch_number)) {
    rows <- which(keep_sims$batch_number == batch)
    batch_path <- b_infos$file_path[b_infos$batch_number == batch]
    sim_obj <- readRDS(batch_path)
    out_of_range <- setdiff(
      keep_sims$sim_number[rows],
      seq_len(sim_obj$control$nsims)
    )
    if (length(out_of_range) > 0) {
      stop(
        "`sim_number` ", paste(out_of_range, collapse = ", "),
        " out of range for batch ", batch, " (", sim_obj$control$nsims,
        " simulations)"
      )
    }
    for (i in rows) {
      restart_points[[i]] <- EpiModel::make_restart_point(
        sim_obj,
        time_attrs = time_attrs,
        sim_num = keep_sims$sim_number[i]
      )
    }
    file_paths[rows] <- batch_path
    rm(sim_obj)
  }

  pool_written <- FALSE
  on.exit(
    if (!pool_written && fs::dir_exists(pool_dir)) fs::dir_delete(pool_dir),
    add = TRUE
  )
  add_to_restart_pool(restart_points, pool_dir)
  pool_index <- data.frame(
    pool_num = seq_len(nrow(keep_sims)),
    scenario_name = scenario_name,
    batch_number = keep_sims$batch_number,
    sim_number = keep_sims$sim_number,
    file_path = as.character(file_paths)
  )
  utils::write.csv(
    pool_index,
    fs::path(pool_dir, "pool_index.csv"),
    row.names = FALSE
  )
  pool_written <- TRUE

  invisible(pool_index)
}

#' Validate a Restart Pool
#'
#' Checks that a restart pool (a directory made by `make_restart_pool`) can be
#' used by `netsim_path_wrapper`. This function is not called by the
#' simulation functions: call it after making a pool, or before starting a
#' long run from it.
#'
#' Errors are raised when:
#' - the pool files are not numbered `1.rds` to `N.rds`;
#' - an element is not a single simulation `netsim` restart point with the
#'   elements needed to restart (`param`, `nwparam`, `epi`, `run`,
#'   `coef.form` and `num.nw`);
#' - the elements were not all made at the same time step
#'   (`control$nsteps`).
#'
#' Warnings are raised when:
#' - the elements' parameters differ. On restart, `netsim` fills the
#'   parameters missing from `param` with the ones of the restart point. Then
#'   merging the simulations of a batch (`merge.netsim` with
#'   `param.error = TRUE`) fails if these differ between elements;
#' - `pool_index.csv` does not have one row per element;
#' - `path` is a single file holding several simulations:
#'   `netsim_path_wrapper` restarts every replicate from its first simulation.
#'
#' @param path Path to a restart pool directory, or to a single restart point
#'   file.
#'
#' @return A `data.frame` with one row per pool element (invisibly):
#'   `pool_num`, `file_path`, `n_runs`, `nsteps` and `same_param` (whether its
#'   parameters are identical to the first element's ones).
#'
#' @seealso [make_restart_pool()], [netsim_path_wrapper()]
#'
#' @export
validate_restart_pool <- function(path) {
  is_pool_dir <- fs::dir_exists(path)
  if (is_pool_dir) {
    pool <- get_restart_pool_files(path)
    if (length(pool) == 0) {
      stop("The restart pool at \"", path, "\" contains no `<n>.rds` file")
    }
    if (!identical(pool, sprintf("%d.rds", seq_along(pool)))) {
      stop(
        "The restart pool files must be named `1.rds` to `", length(pool),
        ".rds`. Found: ", paste(pool, collapse = ", ")
      )
    }
    file_paths <- fs::path(path, pool)
  } else if (fs::file_exists(path)) {
    file_paths <- path
  } else {
    stop("`path` points to neither a file nor a directory: \"", path, "\"")
  }

  required_elts <- c("param", "nwparam", "epi", "run", "coef.form", "num.nw")

  infos <- vector("list", length(file_paths))
  for (i in seq_along(file_paths)) {
    x <- readRDS(file_paths[i])
    if (!inherits(x, "netsim")) {
      stop("\"", file_paths[i], "\" is not a `netsim` object")
    }
    missing_elts <- setdiff(required_elts, names(x))
    if (length(missing_elts) > 0) {
      stop(
        "\"", file_paths[i], "\" is missing the restart element(s): ",
        paste(missing_elts, collapse = ", ")
      )
    }
    n_runs <- length(x$run)
    if (is_pool_dir && n_runs != 1) {
      stop(
        "\"", file_paths[i], "\" holds ", n_runs, " simulations. ",
        "Restart pool elements must hold a single one"
      )
    }

  if (is_pool_dir) {
    index_path <- fs::path(path, "pool_index.csv")
    if (fs::file_exists(index_path)) {
      pool_index <- utils::read.csv(index_path)
      if (!identical(as.integer(pool_index$pool_num), infos$pool_num)) {
        warning(
          "\"", index_path, "\" does not have one row per pool element ",
          "(numbered 1 to ", nrow(infos), ")"
        )
      }
    }
  } else if (infos$n_runs > 1) {
    warning(
      "\"", path, "\" holds ", infos$n_runs, " simulations. ",
      "`netsim_path_wrapper` restarts every replicate from the first one. ",
      "Use `make_restart_pool` to make a pool of these simulations."
    )
  }

  invisible(infos)
}

#' Run Single Simulations From a Restart Pool or a Single Object
#'
#' Runs one `EpiModel::netsim` call with a single simulation for each element
#' of `sim_nums`, in parallel with `future.apply::future_lapply` (using the
#' current `future` plan).
#'
#' If `path_to_x` is a restart pool directory of size `N` (see
#' `make_restart_pool`), simulation `k` starts from pool element
#' `(k - 1) %% N + 1`: the pool is reused in order when there are more
#' simulations than pool elements. If `path_to_x` is a file, every simulation
#' starts from it (from its first simulation if it holds several).
#'
#' `control$nsims`, `control$ncores` and `control$future.use.plan` are
#' overridden. If `control$.checkpoint.dir` is set, each simulation
#' checkpoints in its own `<.checkpoint.dir>/sim_<k>` sub directory.
#'
#' Use `validate_restart_pool` to check a pool before using it.
#'
#' @param path_to_x Path to a restart pool directory, or to a single file
#'   saved with `saveRDS` (a fitted network model or a restart point, see the
#'   `x` argument to `EpiModel::netsim`).
#' @param sim_nums The simulation numbers to run, used to pick the pool
#'   elements.
#' @inheritParams EpiModel::netsim
#'
#' @return A list of `netsim` objects with one simulation each, in the order
#'   of `sim_nums`.
#'
#' @seealso [make_restart_pool()], [validate_restart_pool()]
#'
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

  checkpoint_dir <- control[[".checkpoint.dir"]]
  sim_list <- future.apply::future_lapply(
    seq_along(orig_paths),
    function(i) {
      if (!is.null(checkpoint_dir)) {
        control[[".checkpoint.dir"]] <-
          paste0(checkpoint_dir, "/sim_", sim_nums[i])
      }
      sim <- EpiModel::netsim(readRDS(orig_paths[i]), param, init, control)
      # `merge.netsim` requires identical controls
      sim$control[[".checkpoint.dir"]] <- checkpoint_dir
      sim
    },
    future.seed = TRUE
  )
  sim_list
}
