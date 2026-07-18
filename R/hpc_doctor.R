#' Bash Lines to Reap a Job's Own R Workers on Cancel or Timeout
#'
#' Returns bash lines defining a \code{cleanup_r_workers} shell function and
#' trapping it on \code{TERM} and \code{EXIT}. Append them to the
#' \code{setup_lines} of any \code{step_tmpl_} function, or to a project's own
#' node-setup vector. They are included by default in the \code{r_loader} of
#' \code{\link{swf_configs_rsph}}.
#'
#' @section Why this is needed:
#' The RSPH cluster runs \code{ProctrackType=proctrack/linuxproc} with
#' \code{TaskPlugin=task/affinity} and no cgroup containment, so SLURM locates a
#' job's processes by walking parent-PID chains. R's PSOCK workers reparent to
#' init once their launcher exits, which severs that chain. On any non-clean
#' termination (\code{scancel}, TIME_LIMIT, or preemption) the master dies and
#' the workers survive, still pinned to their original core mask. SLURM marks
#' those cores free and schedules new work onto them, so two independent process
#' sets share the same cores and each gets roughly half a core. The next task to
#' land there runs many times slower and is eventually killed at its walltime,
#' which leaks more workers in turn.
#'
#' Measured on 2026-07-18: cancelling one calibration array left 163 orphans on
#' 15 nodes for about 2.5 hours (roughly 400 core-hours), and two unrelated
#' projects were degraded on the same node in the same two-hour window.
#'
#' @section Implementation notes:
#' Three details are load-bearing and were each bugs in an earlier draft.
#' \enumerate{
#'   \item \code{grep -qxz}, not \code{-qz}. Without \code{-x} the match is an
#'   unanchored substring, so \code{SLURM_JOB_ID=4135} matches \code{41352064},
#'   and an empty \code{SLURM_JOB_ID} degrades the pattern to
#'   \code{SLURM_JOB_ID=} which matches every R process the user owns, including
#'   other live jobs. \code{/proc/<pid>/environ} is permission-gated across
#'   users but not across one user's own concurrent jobs.
#'   \item The \code{[ -n "${SLURM_JOB_ID:-}" ] || return 0} guard, so the
#'   function is a no-op outside SLURM rather than a wildcard.
#'   \item The trailing \code{:} so it always returns 0. Step scripts run
#'   \code{set -e}, and on a normal exit the workers are already gone, so the
#'   final \code{grep} fails and the step would exit non-zero despite
#'   succeeding.
#' }
#'
#' \code{SLURM_JOB_ID} is unique per array task, so a cancelled task reaps only
#' its own workers. Do not key this on \code{SLURM_ARRAY_JOB_ID}, which would
#' kill every task in the array.
#'
#' @section Limits:
#' This is containment, not protection. It stops a dying job from leaving
#' orphans; it does nothing to protect a job from orphans already squatting on
#' the cores it was handed. It also does not cover \code{SIGKILL} (node failure,
#' OOM, \code{scancel -s KILL}) or, reliably, preemption. The root fix is
#' cgroup containment (\code{ProctrackType=proctrack/cgroup} plus
#' \code{TaskPlugin=task/cgroup} with \code{ConstrainCores=yes}), which is an
#' administrative change.
#'
#' @return a character vector of bash lines
#'
#' @examples
#' \dontrun{
#' setup_lines <- c(hpc_configs$r_loader, swf_cleanup_r_workers())
#' }
#'
#' @export
swf_cleanup_r_workers <- function() {
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

#' Path to a Bundled HPC Doctor Script
#'
#' Returns the installed path of one of the shell tools shipped with this
#' package for diagnosing and recovering degenerate SLURM tasks. Copy the script
#' to the cluster, or reference it directly from a deploy script.
#'
#' @param name Which script to locate. One of \code{"deploy_doctor.sh"},
#'   \code{"degen_watch.sh"}, \code{"probe_node_cpu.sh"},
#'   \code{"term_orphans.sh"}.
#'
#' @section The tools:
#' \describe{
#'   \item{\code{probe_node_cpu.sh}}{Node-side. Reports instantaneous CPU
#'   utilisation per SLURM task for every R process the user has on that node.
#'   One ssh per node covers all tasks on it.}
#'   \item{\code{degen_watch.sh}}{Classifies each running task and requeues the
#'   degenerate ones. Set \code{PATTERN} to match your job names.}
#'   \item{\code{deploy_doctor.sh}}{A one-CPU companion job that sweeps for the
#'   life of a campaign and self-terminates when it drains.}
#'   \item{\code{term_orphans.sh}}{SIGTERMs genuinely orphaned R workers on a
#'   node. Safe on nodes shared with other users.}
#' }
#'
#' @section Detect by CPU, not by runtime:
#' Healthy workers sit at about 99 percent CPU and starved ones at about 50
#' percent. Measuring CPU rather than elapsed time is distribution-free: it
#' needs no runtime history, so there is no cold-start window on a new deploy,
#' it needs no per-project calibration, and it cannot mistake a legitimately
#' long scenario for a broken one. A slow task doing real work still reads 99
#' percent and is left alone, a distinction a runtime threshold cannot make.
#'
#' @section PPID is not an orphan test:
#' \code{parallelly::makeClusterPSOCK} reparents healthy workers to init, so a
#' live worker legitimately shows \code{PPID=1}. Verified on 2026-07-18: 88
#' \code{PPID=1} R processes across six nodes were all healthy workers of live
#' jobs. Killing on that heuristic destroys running work. The correct test, used
#' by \code{term_orphans.sh}, is whether the process's \code{SLURM_JOB_ID} still
#' resolves to a job alive in \code{squeue}.
#'
#' @return a length-one character path
#'
#' @examples
#' \dontrun{
#' hpc_doctor_script("deploy_doctor.sh")
#' }
#'
#' @export
hpc_doctor_script <- function(name = c("deploy_doctor.sh", "degen_watch.sh",
                                       "probe_node_cpu.sh", "term_orphans.sh")) {
  name <- match.arg(name)
  path <- system.file("hpc_doctor", name, package = "EpiModelHPC")
  if (!nzchar(path)) {
    stop("Could not locate bundled script: ", name)
  }
  path
}
