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
#' OOM, \code{scancel -s KILL}) or, reliably, preemption. Sweeping up afterwards
#' is a poor substitute for trapping the SIGTERM: \code{/projects} is PanFS, and
#' a \code{SIGKILL} delivered to a worker mid-write can wedge it unkillably in D
#' state, which is the same condition \code{degen_watch.sh} classifies as a
#' filesystem stall. The root fix is
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
#'   One ssh per node covers all tasks on it. Reports both \code{jobid=}
#'   (\code{SLURM_JOB_ID}, the key for matching a task between probes) and
#'   \code{taskid=} (the array-qualified \code{<ArrayJobId>_<TaskId>}, the only
#'   id \code{scontrol} may be given).}
#'   \item{\code{degen_watch.sh}}{Classifies each running task and requeues the
#'   degenerate ones. Addresses every task by its array-qualified id: a bare
#'   \code{ArrayJobId} passed to \code{scontrol requeue} restarts the whole
#'   array. Set \code{PATTERN} to match your job names; it is matched against
#'   the job name and scopes both the nodes probed and the tasks judged, so a
#'   node shared with another of your campaigns is safe.}
#'   \item{\code{deploy_doctor.sh}}{A one-CPU companion job that sweeps for the
#'   life of a campaign and self-terminates when it drains. Submit it with
#'   \code{sbatch}; it carries its own \code{#SBATCH} defaults (1 CPU, 2G, 3
#'   days, job name \code{deploy_doctor}) and locates its sibling scripts via
#'   \code{scontrol}, since \code{sbatch} runs a spool copy of the script from a
#'   directory the siblings are not in. Add \code{--partition} yourself, and
#'   \code{--time} longer than the campaign.}
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

# Bash lines that register a campaign in the watch list. Not exported; the
# public entry point is `add_doctor_register_step`.
doctor_register_lines <- function(wf_name, watch_dir) {
  c(
    "# deploy-doctor watch-list registration (EpiModelHPC::add_doctor_register_step)",
    "# Mark this campaign live so the shared deploy doctor is kept running until the",
    "# campaign's teardown step deregisters it. See ?add_doctor_teardown_step.",
    paste0("swf_watch_dir=\"", watch_dir, "\""),
    "mkdir -p \"${swf_watch_dir}\"",
    paste0("touch \"${swf_watch_dir}/", wf_name, "\""),
    ":"
  )
}

# Bash lines that deregister a campaign and, when it was the last one, stop the
# doctor. Not exported; the public entry point is `add_doctor_teardown_step`.
# The `rm` MUST precede the emptiness test: that ordering is what makes the
# decision race-free when two campaigns finish at once (whichever removes its
# marker last observes an empty directory). The `${USER:-$(whoami)}` fallback
# covers a step environment started with `--export=NONE` where USER is unset,
# and the `|| :` plus trailing `:` keep the step's `set -e` from failing on a
# no-op scancel.
doctor_teardown_lines <- function(wf_name, watch_dir, job_name) {
  c(
    "# deploy-doctor teardown (EpiModelHPC::add_doctor_teardown_step)",
    "# Deregister this campaign and, if it was the last one the shared doctor was",
    "# watching, stop the doctor. Race-free: each campaign removes its own marker",
    "# before testing emptiness, so whichever finishes last always sees an empty",
    "# dir and no concurrent sibling is left unmonitored.",
    paste0("swf_watch_dir=\"", watch_dir, "\""),
    paste0("rm -f \"${swf_watch_dir}/", wf_name, "\""),
    "if [ ! -d \"${swf_watch_dir}\" ] || [ -z \"$(ls -A \"${swf_watch_dir}\" 2>/dev/null)\" ]; then",
    paste0("  scancel -u \"${USER:-$(whoami)}\" --name=", job_name, " 2>/dev/null || :"),
    "fi",
    ":"
  )
}

# Small, cheap sbatch resources for a watch-list step, overridable per call.
doctor_step_sbatch_opts <- function(sbatch_opts) {
  utils::modifyList(
    list(
      "mail-type"     = "FAIL",
      "cpus-per-task" = 1,
      "time"          = "00:05:00",
      "mem-per-cpu"   = "1G"
    ),
    sbatch_opts
  )
}

#' Deploy-Doctor Watch-List Workflow Steps
#'
#' @description
#' \code{add_doctor_register_step} and \code{add_doctor_teardown_step} add the
#' two halves of the deploy-doctor watch list to a \code{slurmworkflow}
#' workflow. Together they stop the shared deploy doctor
#' (\code{\link{hpc_doctor_script}}) automatically once the last campaign it is
#' watching has finished, so it no longer runs to its walltime or needs a manual
#' \code{scancel}.
#'
#' @details
#' The deploy doctor is one standalone SLURM job, launched once per deploy and
#' shared across every concurrent campaign whose job name matches its
#' \code{PATTERN}. It therefore must not be stopped when any single workflow
#' finishes, only when the last one does. The watch list is a directory holding
#' one empty marker file per live campaign. Add the register step near the start
#' of a workflow (right after the workflow is created) and the teardown step as
#' the final step:
#'
#' \enumerate{
#'   \item the register step creates the marker for this campaign;
#'   \item the teardown step removes this campaign's marker and, only if the
#'   directory is then empty, stops the doctor.
#' }
#'
#' Pass the same directory to the doctor itself as \code{WATCH_DIR} when you
#' submit it. The teardown step is the primary stop signal and is immediate, but
#' the doctor also self-terminates after a run of empty sweeps, and \code{WATCH_DIR}
#' is what tells it which kind of empty queue it is looking at. With a campaign
#' still registered it waits the full \code{IDLE_EXIT}, treating an empty queue as
#' a lull between steps; with nothing registered it exits after the shorter
#' \code{IDLE_FAST}. The watch list only ever makes it more patient, and
#' \code{IDLE_EXIT} still caps the wait, so a stale marker left by a workflow that
#' died before its teardown ran cannot hold the doctor open to its walltime.
#'
#' Because each campaign removes its own marker before testing emptiness,
#' whichever campaign finishes last always observes an empty directory. No
#' concurrent sibling is ever left unmonitored, and there is no interleaving in
#' which two simultaneous finishes both leave the doctor running. \code{slurmworkflow}
#' chains steps with \code{afterany}, so the teardown runs even when an earlier
#' step fails. Register and teardown are a matched pair: a workflow that registers
#' but never tears down leaves a stale marker that blocks teardown for other
#' campaigns, and a teardown with no matching doctor is a harmless no-op.
#'
#' @param wf a \code{slurmworkflow} workflow summary (e.g. from
#'   \code{slurmworkflow::create_workflow}).
#' @param wf_name the campaign name, used as the marker file name. It must be
#'   identical in the register and teardown calls and unique per concurrent
#'   campaign; the workflow name is the natural choice.
#' @param watch_dir the watch-list directory, relative to the HPC repository
#'   root (the working directory of a workflow step job). Defaults to
#'   \code{data/run/.doctor_watch}, which is gitignored in the standard EpiModel
#'   project layout.
#' @param job_name the SLURM job name of the deploy doctor to stop. Defaults to
#'   \code{deploy_doctor}, matching the \code{#SBATCH --job-name} default in the
#'   bundled \code{deploy_doctor.sh}. If you rename the doctor's job at submit
#'   time to scope it to one project, pass the same name here or the teardown
#'   will not find it.
#' @param sbatch_opts a named list of sbatch options, merged over the step
#'   defaults (1 CPU, 5 minutes, 1G, mail on FAIL).
#'
#' @return the updated workflow summary, with one step appended.
#'
#' @seealso \code{\link{hpc_doctor_script}} for the doctor itself.
#'
#' @examples
#' \dontrun{
#' wf <- make_em_workflow("my_campaign", override = TRUE)
#' wf <- add_doctor_register_step(wf, "my_campaign")
#' # ... netsim / merge / process steps ...
#' wf <- add_doctor_teardown_step(wf, "my_campaign")
#' }
#'
#' @name doctor_watch_steps
#' @export
add_doctor_register_step <- function(wf, wf_name,
                                     watch_dir = "data/run/.doctor_watch",
                                     sbatch_opts = list()) {
  slurmworkflow::add_workflow_step(
    wf_summary  = wf,
    step_tmpl   = slurmworkflow::step_tmpl_bash_lines(
      doctor_register_lines(wf_name, watch_dir)
    ),
    sbatch_opts = doctor_step_sbatch_opts(sbatch_opts)
  )
}

#' @rdname doctor_watch_steps
#' @export
add_doctor_teardown_step <- function(wf, wf_name,
                                     watch_dir = "data/run/.doctor_watch",
                                     job_name = "deploy_doctor",
                                     sbatch_opts = list()) {
  slurmworkflow::add_workflow_step(
    wf_summary  = wf,
    step_tmpl   = slurmworkflow::step_tmpl_bash_lines(
      doctor_teardown_lines(wf_name, watch_dir, job_name)
    ),
    sbatch_opts = doctor_step_sbatch_opts(sbatch_opts)
  )
}
