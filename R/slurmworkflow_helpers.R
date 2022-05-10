#' Preset of Configuration for the HYAK Cluster
#'
#' @param hpc Which HPC to use on HYAK (either "klone" or "mox")
#' @param partition Which partition to use on HYAK (either "csde" or "ckpt")
#' @param r_version Which version of R to load (default="4.1.2")
#'
#' @return a list containing \code{default_sbatch_opts}, \code{renv_sbatch_opts}
#'   and \code{r_loader} (see the "hpc_configs" section)
#'
#' @section hpc_configs:
#' \enumerate{
#'   \item \code{default_sbatch_opts} is a list of sbatch options to be passed to
#'   \code{slurmworkflow::create_workflow}.
#'   \item \code{renv_sbatch_opts} is a list of sbatch options to be passed to
#'   \code{slurmworkflow::step_tmpl_renv_restore}. It provides sane defaults for
#'   building the dependencies of an R project using \code{renv}
#'   \item \code{r_loader} is a set of bash lines to make the R software available.
#'   This is passed to the \code{setup_lines} arguments of the
#'   \code{slurmworkflow::step_tmpl_} functions that requires it.
#' }
#'
#' @export
swf_configs_hyak <- function(hpc = "klone", partition = "csde",
                             r_version = "4.1.2") {
  if (!hpc %in% c("klone", "mox"))
    stop("On HYAK, `hpc` must be one of \"mox\" or \"klone\"")

  if (!partition %in% c("csde", "ckpt"))
    stop("On ", hpc, ", partition must be one of \"csde\" or \"ckpt\"")

  hpc_configs <- list()
  hpc_configs[["default_sbatch_opts"]] <-  list(
    "account" = if (partition == "ckpt") "csde-ckpt" else "csde",
    "partition" = partition,
    "mail-type" = "FAIL"
  )

  hpc_configs[["renv_sbatch_opts"]] <- swf_renv_sbatch_opts()

  if (hpc == "mox") {
    hpc_configs[["renv_sbatch_opts"]][["partition"]] <- "build"
    hpc_configs[["r_loader"]] <- c(
      ". /gscratch/csde/spack/spack/share/spack/setup-env.sh",
      paste0("spack load r@", r_version),
      "spack load git"
    )
  } else if (hpc == "klone") {
    hpc_configs[["r_loader"]] <- c(
      ". /gscratch/csde/spack/spack/share/spack/setup-env.sh",
      paste0("spack load r@", r_version),
      "spack load git"
    )
  }

  return(hpc_configs)
}

#' Preset of Configuration for the RSPH Cluster
#'
#' @param partition Which partition to use on RSPH (either "compute" or
#'  "epimodel")
#' @param git_version Which version of Git to load (default="2.31.1")
#'
#' @inherit swf_configs_hyak return
#' @inheritParams swf_configs_hyak
#' @inheritSection swf_configs_hyak hpc_configs
#'
#' @export
swf_configs_rsph <- function(partition = "preemptable",
                             r_version = "4.1.2",
                             git_version = "2.31.1") {
  if (!partition %in% c("preemptable", "epimodel"))
    stop("On RSPH, partition must be one of \"preemptable\" or \"epimodel\"")

  hpc_configs <- list()
  hpc_configs[["default_sbatch_opts"]] <-  list(
    "partition" = partition,
    "mail-type" = "FAIL"
  )

  hpc_configs[["renv_sbatch_opts"]] <- swf_renv_sbatch_opts()

  hpc_configs[["r_loader"]] <- c(
    ". /projects/epimodel/spack/share/spack/setup-env.sh",
    paste0("spack load r@", r_version),
    paste0("spack load git@", git_version)
  )

  return(hpc_configs)
}

#' @noRd
swf_renv_sbatch_opts <- function() {
  list(
    "mem" = "16G",
    "cpus-per-task" = 4,
    "time" = 120
  )
}

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
#'
#' @return a template function to be used by \code{add_workflow_step}
#'
#' @export
step_tmpl_renv_restore <- function(git_branch, setup_lines = NULL) {
  instructions <- c(
    "CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)",
    paste0("if [[ \"$CUR_BRANCH\" != \"", git_branch, "\" ]]; then"),
    paste0("echo 'The git branch is not `", git_branch, "`.)"),
    paste0("Exiting' 1>&2"),
    "exit 1",
    "fi",
    "git pull",
    "Rscript -e \"renv::restore()\""
  )
  instructions <- slurmworkflow::helper_use_setup_lines(instructions, setup_lines)

  slurmworkflow::step_tmpl_bash_lines(instructions)
}

#' Step template to run EpiModel network simulations with scenarios
#'
#' This step template will run \code{n_rep} replications of each scenarios in
#' the \code{scenarios_list}. It runs them as multiple batches of up to
#' \code{n_cores} simulations at a time. The simfiles are then stored in the
#' \code{output_dir} folder and are named using the following pattern:
#' "sim__name_of_scenario__2.Rds". Where the last number is the batch number
#' for this particular scenario. Each scenario is therefore run over
#' \code{ceiling(n_rep / n_cores)} batches.
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
#'
#' @inheritParams EpiModel::netsim
#' @inheritParams slurmworkflow::step_tmpl_map
#'
#' @inherit slurmworkflow::step_tmpl_rscript return
#' @inheritSection slurmworkflow::step_tmpl_bash_lines Step Template
#'
#' @export
step_tmpl_netsim_scenarios <- function(x, param, init, control,
                                       scenarios_list, n_rep, n_cores,
                                       output_dir,
                                       libraries = NULL,
                                       setup_lines = NULL,
                                       max_array_size = NULL) {
  libraries <- c("slurmworkflow", "EpiModelHPC", libraries)
  if (is.null(scenarios_list)) {
    scenarios_list <- data.frame(.at = 0, .scenario.id = "empty_scenario")
    scenarios_list <- EpiModel::create_scenario_list(scenarios_list)
  }

  n_batch <- ceiling(n_rep / n_cores)
  batchs_list <- rep(seq_len(n_batch), length(scenarios_list))
  scenarios_list <- rep(scenarios_list, each = n_batch)

  inner_fun <- function(scenario, batch_num,
                        est, param, init, control,
                        libraries, output_dir,
                        n_batch, n_rep, n_cores) {
    lapply(libraries, function(l) library(l, character.only = TRUE))

    if (!fs::dir_exists(output_dir))
      fs::dir_create(output_dir, recursive = TRUE)

    # On last batch, adjust the number of simulation to be run
    if (batch_num == n_batch)
      n_cores <- n_rep - n_cores * (n_batch - 1)

    param_sc <- EpiModel::use_scenario(param, scenario)
    control$nsims <- n_cores
    control$ncores <- n_cores

    print(paste0("Starting simulation for scenario: ", scenario[["id"]]))
    print(paste0("Batch number: ", batch_num, " / ", n_batch))
    sim <- EpiModel::netsim(est, param_sc, init, control)

    file_name <- paste0("sim__", scenario[["id"]], "__", batch_num, ".rds")
    print(paste0("Saving simulation in file: ", file_name))
    saveRDS(sim, fs::path(output_dir, file_name))

    print("Done!")
  }

  step_tmpl_map(
    FUN = inner_fun,
    scenario = scenarios_list,
    batch_num = batchs_list,
    MoreArgs = list(
      est = x,
      param = param,
      init = init,
      control = control,
      libraries = libraries,
      output_dir = output_dir,
      n_batch = n_batch, n_rep = n_rep, n_cores = n_cores
    ),
    max_array_size = max_array_size,
    setup_lines = hpc_configs$r_loader
  )
}
