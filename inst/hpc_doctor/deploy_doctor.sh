#!/bin/bash
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
## Usage (standalone, alongside any campaign):
##   sbatch deploy_doctor.sbatch
##   PATTERN='swfcalib_step' sbatch deploy_doctor.sbatch     # other projects
set -u
ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}   # self-locating; override to point elsewhere
PATTERN=${PATTERN:?set PATTERN to a regex matching your job names, e.g. 'swfcalib_step'}
INTERVAL=${INTERVAL:-600}      # seconds between sweeps
IDLE_EXIT=${IDLE_EXIT:-6}      # consecutive empty sweeps before self-terminating
ACT=${ACT---requeue}          # set ACT='' for report-only

cd "$ROOT" || exit 1
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
