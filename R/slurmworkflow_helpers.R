#' Preset of Configuration for the HYAK Cluster
#'
#' @param hpc Which HPC to use on HYAK (either "klone" or "mox")
#' @param partition Which partition to use on HYAK (either "csde" or "ckpt")
#'
#' @return a list containing `default_sbatch_opts`, `renv_sbatch_opts` and
#'    `r_loader` (see the "hpc_configs" section)
#'
#' @section hpc_configs:
#' - `default_sbatch_opts` is a list of sbatch options to be passed to
#' `slurmworkflow::create_workflow`.
#' - `renv_sbatch_opts` is a list of sbatch options to be passed to
#' `slurmworkflow::step_tmpl_renv_restore`. It provides sane defaults for
#' building the dependencies of an R project using `renv`
#' - `r_loader` is a set of bash lines to make the R software available. This is
#' passed to the `setup_lines` arguments of the `slurmworkflow::step_tmpl_`
#' functions that requires it.
#'
#' @export
swf_configs_hyak <- function(hpc = "klone", partition = "csde") {
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
      "spack load r@4.1.2"
    )
  } else if (hpc == "klone") {
    hpc_configs[["r_loader"]] <- c(
      ". /gscratch/csde/spack/spack/share/spack/setup-env.sh",
      "spack load r@4.1.2"
    )
  }

  return(hpc_configs)
}

#' Preset of Configuration for the RSPH Cluster
#'
#' @param partition Which partition to use on RSPH (either "compute" or
#'  "epimodel")
#'
#' @inherit swf_configs_hyak return
#' @inheritSection swf_configs_hyak hpc_configs
#'
#' @export
swf_configs_rsph <- function(partition = "preemptable") {
  if (!partition %in% c("preemptable", "epimodel"))
    stop("On RSPH, partition must be one of \"preemptable\" or \"epimodel\"")

  hpc_configs <- list()
  hpc_configs[["default_sbatch_opts"]] <-  list(
    "partition" = partition,
    "mail-type" = "FAIL"
  )

  hpc_configs[["renv_sbatch_opts"]] <- swf_renv_sbatch_opts()

  hpc_configs[["r_loader"]] <- c(
    ". /gscratch/csde/spack/spack/share/spack/setup-env.sh",
    "spack load r@4.1.2"
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

