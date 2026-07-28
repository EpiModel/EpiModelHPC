#!/bin/bash
#SBATCH --job-name=deploy_doctor
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=3-00:00:00
#SBATCH --output=deploy_doctor-%j.out
## "Deploy doctor": a tiny long-running companion job that watches a campaign's
## array tasks for CPU starvation and requeues degenerate ones, for the whole
## life of the workflow. One CPU, mostly asleep.
##
## WHY THIS EXISTS (measured 2026-07-18): slurmworkflow submits netsim in slices
## of 500 and the next slice only goes in when the LAST task of the current one
## finishes. Drain cost per slice:
##     normal slices        2-16%  of slice wall time
##     degenerate slices    43-68% (tails of 178 and 188 MINUTES)
## The catastrophic barriers ARE the degenerate stragglers. Catching one at ~35m
## instead of letting it ride to a 1-4h wall collapses a 68% tail to ~10%, so
## this recovers most of the idle time as a side effect of fixing degeneration.
##
## It detects starvation by CPU utilisation, not runtime, so it needs no history
## and works on day 1 of any new deploy (see degen_watch.sh header). It requeues
## rather than cancels, so a caught task re-runs its own unit and leaves no gap.
##
## Scope: this version ONLY doctors tasks. It deliberately does NOT submit next
## slices early (pipelining). That would need exclusive ownership of slice
## progression -- if it submitted while step2's built-in array_max chaining also
## submitted, two tasks would write the same sim__<scenario>__<batch>.rds
## concurrently and CORRUPT it, not merely waste compute. Prototype that on a
## throwaway workflow first.
##
## The #SBATCH defaults above are deliberate. Submitted with no directives this
## job inherits the partition default walltime, which on RSPH killed it at ~8h
## against campaigns running one to five days (issue #56). Set --time longer
## than the campaign, and add --partition yourself: partition names are
## cluster-specific and there is no safe default to bake in.
##
## --job-name matches the `job_name` default of EpiModelHPC's
## `add_doctor_teardown_step()`, which stops the doctor with
## `scancel --name=deploy_doctor`. If you rename the job to scope it to one
## project, pass the same name to that function or teardown will not find it.
##
## WHEN THE DOCTOR STOPS (issue #54). Three signals, in order of authority:
##   1. `add_doctor_teardown_step()` scancels it when the LAST registered
##      campaign finishes. This is the normal path and it is immediate.
##   2. WATCH_DIR, the same watch list that teardown maintains. If it is set and
##      non-empty, a campaign is still registered, so an empty queue is a lull
##      between steps and the doctor waits the full IDLE_EXIT before believing
##      it. The watch list can only make the doctor MORE patient, never less.
##   3. The queue itself. With no campaign registered, an empty queue for
##      IDLE_FAST sweeps is enough. This is also the backstop that keeps a stale
##      marker (a workflow that died before its teardown ran) from pinning the
##      doctor to its walltime: IDLE_EXIT still caps the wait either way.
## Measured 2026-07-27/28 on a live doxy campaign: 103 sweeps over 20.5h, and
## the matching-task count never once reached zero. Empty-queue states during a
## running campaign are rare, which is why IDLE_FAST can be small.
##
## PENDING-SIDE BARRIERS (issue #55). slurmworkflow submits netsim in slices and
## the next slice only goes in when the LAST task of the current one finishes, so
## a single queued straggler gates the whole slice. There is no process to probe,
## so the CPU/D-state detector cannot see it: the old loop just logged a normal
## "sweeping" line and then found nothing running. Observed for nine hours (55
## consecutive sweeps) in the India rollout. Sweeps with tasks pending and none
## running are now counted and, past BARRIER_WARN, reported with each pending
## task's SLURM reason. This is observability only; it does not touch slice
## progression, so it carries none of the double-write risk described above.
##
## Usage (standalone, alongside any campaign):
##   PATTERN='doxy-' sbatch --partition=<yours> deploy_doctor.sh
##   PATTERN='swfcalib_step' sbatch --partition=<yours> deploy_doctor.sh
## With the watch list, so a shared doctor outlives any one campaign:
##   PATTERN='doxy-' WATCH_DIR=data/run/.doctor_watch sbatch ... deploy_doctor.sh
## From R, to get the installed path:
##   EpiModelHPC::hpc_doctor_script("deploy_doctor.sh")
## Output lands in deploy_doctor-<jobid>.out in the submission directory.
set -u
PATTERN=${PATTERN:?set PATTERN to a regex matching your job names, e.g. 'swfcalib_step'}
INTERVAL=${INTERVAL:-600}      # seconds between sweeps
IDLE_EXIT=${IDLE_EXIT:-6}      # empty sweeps before exiting while a campaign is still registered
IDLE_FAST=${IDLE_FAST:-2}      # empty sweeps before exiting when none is
BARRIER_WARN=${BARRIER_WARN:-3}  # pending-only sweeps before reporting a barrier
WATCH_DIR=${WATCH_DIR:-}       # optional; the watch list add_doctor_register_step maintains
ACT=${ACT---requeue}          # set ACT='' for report-only

# Resolve WATCH_DIR against the SUBMISSION directory, before the `cd "$ROOT"`
# below moves us into the installed package. `add_doctor_register_step()`
# documents its watch_dir as relative to the repository root, which is where the
# doctor is submitted from, so a bare `data/run/.doctor_watch` has to mean that
# and not a path inside the renv library.
if [ -n "$WATCH_DIR" ]; then
  case "$WATCH_DIR" in
    /*) ;;
    *) WATCH_DIR="${SLURM_SUBMIT_DIR:-$PWD}/$WATCH_DIR" ;;
  esac
fi

# Non-empty watch list means at least one campaign has registered and not yet
# torn down. Absent or empty means nothing claims to be live.
watch_list_live() {
  [ -n "$WATCH_DIR" ] || return 1
  [ -d "$WATCH_DIR" ] || return 1
  [ -n "$(ls -A "$WATCH_DIR" 2>/dev/null)" ]
}

# --- locate the sibling scripts -------------------------------------------
# Two launch styles have to work, and they need opposite answers.
#
#   sbatch deploy_doctor.sh          `sbatch` COPIES the script into the node's
#                                    spool directory and runs it there, so
#                                    BASH_SOURCE is /var/spool/slurmd/job<ID>/
#                                    and the siblings are NOT there. `scontrol
#                                    show job` still reports the ORIGINAL
#                                    submitted path, which is right.
#
#   bash "$(hpc_doctor_script(...))" A project wrapper submits itself and runs
#   from inside a wrapper job         the installed doctor by full path. Here
#                                     BASH_SOURCE is the package's hpc_doctor
#                                     directory and is right, while `scontrol`
#                                     reports the WRAPPER, which is wrong.
#
# Neither source is trustworthy on its own, so test each candidate for the
# siblings rather than ranking them blind. An explicit ROOT always wins.
has_siblings() { [ -r "$1/degen_watch.sh" ] && [ -r "$1/probe_node_cpu.sh" ]; }

resolve_root() {
  local self cmd
  if [ -n "${ROOT:-}" ]; then printf '%s\n' "$ROOT"; return; fi
  self=$(dirname "${BASH_SOURCE[0]:-$0}")
  if has_siblings "$self"; then printf '%s\n' "$self"; return; fi
  if [ -n "${SLURM_JOB_ID:-}" ] && command -v scontrol >/dev/null 2>&1; then
    cmd=$(scontrol show job "$SLURM_JOB_ID" 2>/dev/null \
          | tr ' ' '\n' | sed -n 's/^Command=//p' | head -1)
    if [ -n "$cmd" ] && has_siblings "$(dirname "$cmd")"; then
      printf '%s\n' "$(dirname "$cmd")"; return
    fi
  fi
  # Nothing resolved. Return the self-location so the failure message below
  # names the most likely place the user meant.
  printf '%s\n' "$self"
}
ROOT=$(resolve_root)
# Canonicalise to absolute BEFORE the cd. A relative ROOT would otherwise
# resolve twice, once here and again in "$ROOT/degen_watch.sh" after the cd has
# moved us, and fail in a second, more confusing way.
ROOT=$(cd "$ROOT" 2>/dev/null && pwd) || {
  echo "[doctor] FATAL: ROOT is not a readable directory" >&2; exit 1; }
cd "$ROOT" || exit 1

# Fail LOUDLY, before the first sweep, if the workers are not where we think.
# Every failure in this launch path is otherwise silent: the loop keeps its
# schedule, the job stays RUNNING and green in `squeue`, and the campaign runs
# unprotected for the doctor's whole walltime while the log fills with sweeps
# that did nothing. Issue #56 is ten hours of exactly that. Exiting non-zero
# here makes SLURM report FAILED instead.
for dep in degen_watch.sh probe_node_cpu.sh; do
  [ -r "$ROOT/$dep" ] || {
    echo "[doctor] FATAL: $dep not readable under ROOT=$ROOT" >&2
    echo "[doctor] Point ROOT at the installed hpc_doctor directory, e.g." >&2
    echo "[doctor]   ROOT=\$(Rscript -e 'cat(dirname(EpiModelHPC::hpc_doctor_script(\"deploy_doctor.sh\")))')" >&2
    echo "[doctor] It must be an absolute path on a filesystem the compute nodes share." >&2
    exit 1
  }
done
echo "[doctor] start $(date -Is) host=$(hostname) pattern=/$PATTERN/ interval=${INTERVAL}s act=${ACT:-report-only} watch_dir=${WATCH_DIR:-none}"
idle=0; sweep=0; seen=0; barrier=0
while :; do
  sweep=$((sweep+1))
  # One squeue pass, split by state. Both #54 and #55 turn on this split:
  # RUNNING is the only state the probe can measure, PENDING is what gates a
  # slice barrier, and only "neither" means the campaign is actually over.
  # `-r` expands array elements so a collapsed pending range counts as the tasks
  # it really holds. Without it a row like 41746874_[46-63] counted as one, which
  # understated pending work about twofold on a live campaign (26 vs 43).
  states=$(squeue -u "$USER" -h -r -t RUNNING,PENDING -o "%T|%j" 2>/dev/null \
           | awk -F'|' -v pat="$PATTERN" '$2 ~ pat {print $1}')
  n_run=$(grep -cx RUNNING <<< "$states" || true)
  n_pend=$(grep -cx PENDING <<< "$states" || true)
  n=$((n_run + n_pend))

  if [ "$n" -eq 0 ]; then
    barrier=0
    idle=$((idle+1))
    # Only treat "no tasks" as END-of-campaign once we have actually SEEN work.
    # Otherwise a doctor launched at campaign start (e.g. from step 1, or from the
    # deploy script) would exit during step 1's renv restore -- which can run 180
    # min -- long before the netsim array it is meant to watch ever appears.
    if [ "$seen" -eq 0 ]; then
      echo "[doctor] $(date -Is) sweep=$sweep waiting for campaign to start (no tasks yet)"
    else
      if watch_list_live; then
        thr=$IDLE_EXIT; why="a campaign is still registered in the watch list"
      else
        thr=$IDLE_FAST; why="no campaign registered"
      fi
      # Never wait longer than the old ceiling. This is what stops a stale marker,
      # left by a workflow that died before its teardown step ran, from holding
      # the doctor open until its walltime.
      [ "$thr" -gt "$IDLE_EXIT" ] && thr=$IDLE_EXIT
      echo "[doctor] $(date -Is) sweep=$sweep no matching tasks (idle ${idle}/${thr}; ${why})"
      if [ "$idle" -ge "$thr" ]; then
        echo "[doctor] $(date -Is) campaign appears finished; exiting cleanly"; break
      fi
    fi
  elif [ "$n_run" -eq 0 ]; then
    # Tasks queued, none running: a pending-side barrier. Nothing to probe, so
    # the sweep is skipped rather than run to report "no running tasks".
    idle=0; seen=1; barrier=$((barrier+1))
    if [ "$barrier" -ge "$BARRIER_WARN" ]; then
      echo "[doctor] $(date -Is) sweep=$sweep !! BARRIER matching_tasks=$n (0 running, ${n_pend} pending) for $((barrier * INTERVAL / 60))m -- no netsim progress"
      # The reason field separates a scheduler-starved task (Priority, Resources)
      # from one held or blocked for another cause, including a task the doctor
      # itself requeued to the back of a deep queue.
      squeue -u "$USER" -h -r -t PENDING -o "%i|%j|%r" 2>/dev/null \
        | awk -F'|' -v pat="$PATTERN" '$2 ~ pat {printf "[doctor]     pending %-16s reason=%s\n", $1, $3}' \
        | head -10
    else
      echo "[doctor] $(date -Is) sweep=$sweep matching_tasks=$n (0 running, ${n_pend} pending) -- nothing to probe"
    fi
  else
    idle=0; seen=1; barrier=0
    echo "[doctor] $(date -Is) sweep=$sweep matching_tasks=$n (${n_run} running, ${n_pend} pending) -- sweeping"
    ROOT="$ROOT" PATTERN="$PATTERN" bash "$ROOT/degen_watch.sh" $ACT 2>&1 \
      | grep -vE '^  ok ' | sed 's/^/[doctor]   /'
  fi
  sleep "$INTERVAL"
done
echo "[doctor] stop $(date -Is) after $sweep sweeps"
