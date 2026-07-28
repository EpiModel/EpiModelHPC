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
## Usage (standalone, alongside any campaign):
##   PATTERN='doxy-' sbatch --partition=<yours> deploy_doctor.sh
##   PATTERN='swfcalib_step' sbatch --partition=<yours> deploy_doctor.sh
## From R, to get the installed path:
##   EpiModelHPC::hpc_doctor_script("deploy_doctor.sh")
## Output lands in deploy_doctor-<jobid>.out in the submission directory.
set -u
PATTERN=${PATTERN:?set PATTERN to a regex matching your job names, e.g. 'swfcalib_step'}
INTERVAL=${INTERVAL:-600}      # seconds between sweeps
IDLE_EXIT=${IDLE_EXIT:-6}      # consecutive empty sweeps before self-terminating
ACT=${ACT---requeue}          # set ACT='' for report-only

# --- locate the sibling scripts -------------------------------------------
# `sbatch` COPIES the submitted script into the node's spool directory and runs
# it from there, so plain `BASH_SOURCE` self-location puts ROOT at
# /var/spool/slurmd/job<ID>/, where degen_watch.sh is not. `scontrol show job`
# still reports the ORIGINAL submitted path, so ask SLURM first and fall back to
# self-location only when running outside a job. An explicit ROOT always wins.
resolve_root() {
  local cmd
  if [ -n "${ROOT:-}" ]; then printf '%s\n' "$ROOT"; return; fi
  if [ -n "${SLURM_JOB_ID:-}" ] && command -v scontrol >/dev/null 2>&1; then
    cmd=$(scontrol show job "$SLURM_JOB_ID" 2>/dev/null \
          | tr ' ' '\n' | sed -n 's/^Command=//p' | head -1)
    if [ -n "$cmd" ] && [ -d "$(dirname "$cmd")" ]; then
      printf '%s\n' "$(dirname "$cmd")"; return
    fi
  fi
  printf '%s\n' "$(dirname "${BASH_SOURCE[0]:-$0}")"
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
echo "[doctor] start $(date -Is) host=$(hostname) pattern=/$PATTERN/ interval=${INTERVAL}s act=${ACT:-report-only}"
idle=0; sweep=0; seen=0
while :; do
  sweep=$((sweep+1))
  n=$(squeue -u "$USER" -h -t RUNNING,PENDING -o "%j" 2>/dev/null | grep -Ec "$PATTERN" || true)
  if [ "${n:-0}" -eq 0 ]; then
    idle=$((idle+1))
    # Only treat "no tasks" as END-of-campaign once we have actually SEEN work.
    # Otherwise a doctor launched at campaign start (e.g. from step 1, or from the
    # deploy script) would exit during step 1's renv restore -- which can run 180
    # min -- long before the netsim array it is meant to watch ever appears.
    if [ "$seen" -eq 0 ]; then
      echo "[doctor] $(date -Is) sweep=$sweep waiting for campaign to start (no tasks yet)"
    else
      echo "[doctor] $(date -Is) sweep=$sweep no matching tasks (idle ${idle}/${IDLE_EXIT})"
      if [ "$idle" -ge "$IDLE_EXIT" ]; then
        echo "[doctor] $(date -Is) campaign appears finished; exiting cleanly"; break
      fi
    fi
  else
    idle=0; seen=1
    echo "[doctor] $(date -Is) sweep=$sweep matching_tasks=$n -- sweeping"
    ROOT="$ROOT" PATTERN="$PATTERN" bash "$ROOT/degen_watch.sh" $ACT 2>&1 \
      | grep -vE '^  ok ' | sed 's/^/[doctor]   /'
  fi
  sleep "$INTERVAL"
done
echo "[doctor] stop $(date -Is) after $sweep sweeps"
