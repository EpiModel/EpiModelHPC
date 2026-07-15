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
#' @param reap_orphans Append a SIGTERM trap to \code{r_loader} that kills this
#'   job's R workers when the job is cancelled (default \code{TRUE}). See the
#'   "Orphaned workers" section.
#'
#' @inherit swf_configs_hyak return
#' @inheritParams swf_configs_hyak
#' @inheritSection swf_configs_hyak hpc_configs
#'
#' @section Orphaned workers:
#' RSPH runs \code{ProctrackType = proctrack/linuxproc} with no cgroups. That
#' tracks a job's processes by walking parent-PID chains. R's PSOCK workers (used
#' by \code{future::plan("multisession")}, and therefore by \code{swfcalib}) are
#' launched with \code{system(wait = FALSE)} and reparent to init immediately,
#' severing the chain. \code{scancel} then kills the step and leaves the workers
#' running at full CPU, invisible to SLURM, which schedules new work onto cores
#' they are still using.
#'
#' \code{scancel} sends SIGTERM before SIGKILL (\code{KillWait = 30s}), so the
#' trap reaps R processes whose environment carries this job's
#' \code{SLURM_JOB_ID}. That variable is unique per array task, so a cancelled
#' task never touches its siblings, and the trap is a no-op outside SLURM.
#'
#' It does not cover SIGKILL (node failure, OOM, \code{scancel -s KILL}). Cleaning
#' up afterwards is a poor substitute: \code{/projects} is PanFS, and SIGKILL to a
#' worker mid-write can wedge it unkillably in D state.
#'
#' @export
swf_configs_rsph <- function(partition = "preemptable",
                             r_version = "4.5.1",
                             git_version = "2.35.1",
                             mail_user = NULL,
                             reap_orphans = TRUE) {

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

  if (reap_orphans)
    hpc_configs[["r_loader"]] <- c(
      hpc_configs[["r_loader"]],
      swf_reap_orphans_lines()
    )

  return(hpc_configs)
}

#' Bash lines reaping this SLURM job's R workers on cancellation
#'
#' Three details are load-bearing:
#' \itemize{
#'   \item \code{grep -qxz}, not \code{-qz}. Without \code{-x} the match is an
#'   unanchored substring, so \code{SLURM_JOB_ID=4135} would match
#'   \code{41352064}. \code{/proc/<pid>/environ} is permission-gated across users
#'   but not across a user's own concurrent jobs, so nothing else prevents that.
#'   \item the \code{SLURM_JOB_ID} guard, so an unset variable makes the function
#'   a no-op rather than a pattern matching every R process the user owns.
#'   \item the trailing \code{:}, so the function always returns 0. The generated
#'   \code{job.sh} runs \code{set -e}, and the loop otherwise returns the last
#'   grep's status. On a normal exit this job's workers are already gone, so that
#'   grep fails against some other job's R process and the step would exit
#'   non-zero despite succeeding.
#' }
#'
#' @noRd
swf_reap_orphans_lines <- function() {
  c(
    paste(
      "cleanup_r_workers() { [ -n \"${SLURM_JOB_ID:-}\" ] || return 0;",
      "for p in $(pgrep -u \"$USER\" -x R 2>/dev/null); do",
      "grep -qxz \"SLURM_JOB_ID=$SLURM_JOB_ID\" /proc/$p/environ 2>/dev/null",
      "&& kill -9 \"$p\" 2>/dev/null; done; :; }"
    ),
    "trap cleanup_r_workers TERM EXIT"
  )
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
