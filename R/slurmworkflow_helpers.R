#' Preset of Configuration for the HYAK Cluster
#'
#' @param hpc Which HPC to use on HYAK (either "klone" or "mox")
#' @param partition Which partition to use on HYAK (either "csde" or "ckpt")
#' @param r_version Which version of R to load
#' @param mail_user The mail address to send the messages to, default is NULL
#'   (see 'sbatch --mail-type' argument)
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
                             r_version = "4.2.2", mail_user = NULL) {
  if (hpc == "klone") {
    if (!partition %in% c("ckpt", "compute"))
      stop("On ", hpc, ", partition must be one of \"compute\" or \"ckpt\"")
  } else if (hpc == "mox") {
    if (!partition %in% c("csde", "ckpt"))
      stop("On ", hpc, ", partition must be one of \"csde\" or \"ckpt\"")
  } else {
    stop("On HYAK, `hpc` must be one of \"mox\" or \"klone\"")
  }

  hpc_configs <- list()
  hpc_configs[["default_sbatch_opts"]] <-  list(
    "account" = if (partition == "ckpt") "csde-ckpt" else "csde",
    "partition" = partition,
    "mail-type" = "FAIL"
  )

  if (!is.null(mail_user))
    hpc_configs[["default_sbatch_opts"]][["mail-user"]] <- mail_user


  hpc_configs[["renv_sbatch_opts"]] <- swf_renv_sbatch_opts()

  if (hpc == "mox") {
    hpc_configs[["renv_sbatch_opts"]][["partition"]] <- "build"
    hpc_configs[["r_loader"]] <- c(
      ". /gscratch/csde/spack/spack/share/spack/setup-env.sh",
      "spack unload -a",
      paste0("spack load r@", r_version),
      "spack load git"
    )
  } else if (hpc == "klone") {
    hpc_configs[["r_loader"]] <- c(
      ". /gscratch/csde/spack/spack/share/spack/setup-env.sh",
      "spack unload -a",
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
#' @param git_version Which version of Git to load
#'
#' @inherit swf_configs_hyak return
#' @inheritParams swf_configs_hyak
#' @inheritSection swf_configs_hyak hpc_configs
#'
#' @export
swf_configs_rsph <- function(partition = "preemptable",
                             r_version = "4.2.1",
                             git_version = "2.35.1",
                             mail_user = NULL) {

  if (!partition %in% c("preemptable", "epimodel"))
    stop("On RSPH, partition must be one of \"preemptable\" or \"epimodel\"")

  hpc_configs <- list()
  hpc_configs[["default_sbatch_opts"]] <-  list(
    "partition" = partition,
    "mail-type" = "FAIL"
  )

  if (!is.null(mail_user))
    hpc_configs[["default_sbatch_opts"]][["mail-user"]] <- mail_user

  hpc_configs[["renv_sbatch_opts"]] <- swf_renv_sbatch_opts()

  hpc_configs[["r_loader"]] <- c(
    ". /projects/epimodel/spack/share/spack/setup-env.sh",
    "spack unload -a",
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
#' @param lockfile (optional) path to an alternative lockfile to restore
#'
#' @return a template function to be used by \code{add_workflow_step}
#'
#' @export
step_tmpl_renv_restore <- function(git_branch, setup_lines = NULL, lockfile = NULL) {
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

  instructions <- slurmworkflow::helper_use_setup_lines(instructions, setup_lines)

  slurmworkflow::step_tmpl_bash_lines(instructions)
}
