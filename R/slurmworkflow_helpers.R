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
#' @param partition The RSPH partition, or partitions, to submit to: a single
#'   name, a character vector, or a comma-separated string such as
#'   `"epimodel,CIDMATH"`. With several partitions, SLURM starts each job on
#'   whichever can run it first. The default, `"epimodel"`, is the lab's
#'   dedicated partition. See the "Partitions" section for the valid names.
#' @param r_version Which version of R to load with spack. Use the full version
#'   (`"4.6.1"` or `"4.5.1"`) matching the R version in the project lockfile. A
#'   partial version such as `"4.3"` can match several spack builds, which makes
#'   `spack load` fail, so it gives a warning.
#' @param cleanup_workers If \code{TRUE} (the default), append
#'   \code{\link{swf_cleanup_r_workers}} to \code{r_loader} so each step reaps
#'   its own R workers on cancel or timeout. RSPH has no cgroup containment, so
#'   without this, workers survive \code{scancel} and squat on cores SLURM has
#'   re-allocated, starving later tasks. See \code{\link{swf_cleanup_r_workers}}.
#'
#' @inheritParams swf_configs_hyak
#'
#' @return a list with four elements:
#' * `default_sbatch_opts`: sbatch options to pass to
#'   `slurmworkflow::create_workflow()`. They set the partition list,
#'   `mail-type = "FAIL"` and, when `mail_user` is given, `mail-user`.
#' * `renv_sbatch_opts`: sbatch options for the [step_tmpl_renv_restore()] step:
#'   16 GB of memory, 4 CPUs and 180 minutes, as in the EpiModelHIV-Template.
#'   The first restore under a new R version builds every package from source
#'   and takes longer than later ones.
#' * `r_loader`: bash lines that make R available on a compute node. Pass them
#'   to the `setup_lines` argument of the `step_tmpl_` functions.
#' * `max_cores`: the largest `cpus-per-task` a single task can request on
#'   every listed partition. It is 32, except 16 when `interactive-cpu` is
#'   listed and 31 when `largemem` is listed.
#'
#' @section Partitions:
#' The RSPH partitions as of October 2026. All nodes have 32 cores.
#'
#' | Partition | Time limit | Max cores per task | Notes |
#' |---|---|---|---|
#' | `epimodel` | none | 32 | The lab's dedicated nodes; the default |
#' | `CIDMATH` | none | 32 | Dedicated nodes shared with three other groups |
#' | `short-cpu` | 8 hours | 32 | The cluster's default partition |
#' | `day-long-cpu` | 1 day | 32 | |
#' | `week-long-cpu` | 7 days | 32 | At most 6 nodes per job |
#' | `month-long-cpu` | 31 days | 32 | At most 4 nodes per job |
#' | `interactive-cpu` | 12 hours | 16 | Meant for `srun` sessions |
#' | `largemem` | 7 days | 31 | High-memory nodes |
#'
#' The `preemptable` partition no longer exists, and asking for it is an error.
#'
#' `default_sbatch_opts` sets no `time`, so a step without its own `time` runs
#' up to the limit of the partition it lands on. A step whose `time` exceeds a
#' partition's limit can only start on the other partitions in the list.
#'
#' RSPH gives each CPU 5 GB of memory by default (`DefMemPerCPU = 5120`) and
#' does not enforce memory requests. A step that uses more than it asked for is
#' not killed, but it can starve other jobs on the node, so request what each
#' step needs with `mem-per-cpu`. Keep `mem = "0"` (a whole node) for network
#' estimation.
#'
#' SLURM's `MaxArraySize` is 1001 on RSPH, so one array holds at most 1001
#' tasks (indices 0 to 1000). We use `max_array_size = 1000` in array steps.
#'
#' @section Node setup:
#' \code{r_loader} sources the shared spack environment, unloads everything, and
#' loads R. It deliberately does not load git: git is on the default path on
#' RSPH, and the project template has not loaded it for some time. The
#' \code{git_version} argument was removed accordingly.
#'
#' @examples
#' hpc_configs <- swf_configs_rsph(mail_user = "user@emory.edu")
#' hpc_configs$default_sbatch_opts
#'
#' # Start each step on whichever partition can run it first
#' swf_configs_rsph(c("epimodel", "CIDMATH", "short-cpu"))$default_sbatch_opts
#'
#' # A project whose lockfile records R 4.5
#' swf_configs_rsph(r_version = "4.5.1", cleanup_workers = FALSE)$r_loader
#'
#' @export
swf_configs_rsph <- function(partition = "epimodel",
                             r_version = "4.6.1",
                             mail_user = NULL,
                             cleanup_workers = TRUE) {

  partition <- rsph_check_partition(partition)

  if (!grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", r_version[1])) {
    warning(
      "`r_version = \"", r_version[1], "\"` is not a full version. ",
      "It can match several spack builds and make `spack load` fail. ",
      "Use a full version such as \"4.6.1\".",
      call. = FALSE
    )
  }

  partitions <- rsph_partitions()

  hpc_configs <- list()
  hpc_configs[["default_sbatch_opts"]] <-  list(
    "partition" = paste(partition, collapse = ","),
    "mail-type" = "FAIL"
  )

  if (!is.null(mail_user))
    hpc_configs[["default_sbatch_opts"]][["mail-user"]] <- mail_user

  hpc_configs[["renv_sbatch_opts"]] <- swf_renv_sbatch_opts()
  hpc_configs[["renv_sbatch_opts"]][["time"]] <- 180

  hpc_configs[["r_loader"]] <- c(
    ". /projects/epimodel/spack/share/spack/setup-env.sh",
    "spack unload -a",
    paste0("spack load r@", r_version)
  )

  if (isTRUE(cleanup_workers)) {
    hpc_configs[["r_loader"]] <- c(
      hpc_configs[["r_loader"]],
      swf_cleanup_r_workers()
    )
  }

  hpc_configs[["max_cores"]] <- min(
    partitions$max_cores[match(partition, partitions$partition)]
  )

  return(hpc_configs)
}

#' RSPH partitions and the most cores a single task can request on each
#'
#' Checked with `scontrol show partition` on 2026-10-12.
#' @noRd
rsph_partitions <- function() {
  data.frame(
    partition = c(
      "epimodel", "CIDMATH", "short-cpu", "day-long-cpu", "week-long-cpu",
      "month-long-cpu", "interactive-cpu", "largemem"
    ),
    max_cores = c(32, 32, 32, 32, 32, 32, 16, 31),
    stringsAsFactors = FALSE
  )
}

#' Validate and normalize the `partition` argument of `swf_configs_rsph`
#'
#' Accepts a vector or a comma-separated string, matches names without regard
#' to case, and returns the canonical names without duplicates.
#' @noRd
rsph_check_partition <- function(partition) {
  if (!is.character(partition) || anyNA(partition))
    stop("`partition` must be a character vector of RSPH partition names")

  requested <- trimws(unlist(strsplit(partition, ",", fixed = TRUE)))
  requested <- requested[nzchar(requested)]
  if (length(requested) == 0)
    stop("`partition` must name at least one RSPH partition")

  if ("preemptable" %in% tolower(requested)) {
    stop(
      "The \"preemptable\" partition no longer exists on RSPH. ",
      "Use \"epimodel\" (the lab's dedicated nodes), or a list such as ",
      "c(\"epimodel\", \"short-cpu\", \"day-long-cpu\") to run on whichever ",
      "partition starts first.",
      call. = FALSE
    )
  }

  valid <- rsph_partitions()$partition
  idx <- match(tolower(requested), tolower(valid))
  if (anyNA(idx)) {
    stop(
      "Unknown RSPH partition: ",
      paste0("\"", requested[is.na(idx)], "\"", collapse = ", "), ". ",
      "Valid partitions are ", paste0("\"", valid, "\"", collapse = ", "), ".",
      call. = FALSE
    )
  }

  unique(valid[idx])
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
