#!/bin/bash
## Node-side: instantaneous CPU utilisation per SLURM task, for every R process
## this user has on this node. ONE ssh per node covers all tasks on it.
##
## Distribution-free by design: it measures the pathology (starvation) directly
## rather than inferring it from runtime, so it needs NO history and is valid on
## task #1 of a brand-new deploy, at any population size or scenario mix.
##
## Instantaneous, not lifetime: /proc/<pid>/stat utime+stime sampled twice and
## differenced. `ps %cpu` is a lifetime average and would hide a task that ran
## healthy for 20 min and then got starved -- exactly the transition we want.
##
## Reports the MEDIAN across a task's processes, because these tasks are 1 idle
## callr master (~3%) + N compute workers (~99%): the master drags the mean to
## ~89 when perfectly healthy, while the median sits at ~99-100. Healthy ~99 vs
## starved ~50 is a wide, unambiguous gap.
##
## Reports two identifiers per task, and they are not interchangeable. `jobid` is
## SLURM_JOB_ID, unique per task and the right key for matching a task between
## probes. `taskid` is what `scontrol` must be given: for an array task that is
## <ArrayJobId>_<TaskId>, because `scontrol requeue <ArrayJobId>` acts on EVERY
## task in the array, and the array's first task reports its SLURM_JOB_ID AS the
## bare ArrayJobId. For a non-array job the two are equal.
##
## Usage:  probe_node_cpu.sh [interval_secs]
## Output: one node line, then one line per SLURM task ->
##         nodeinfo=1 cores=<n> load1=<x>
##         jobid=<numeric> taskid=<numeric|arrayjob_task> nproc=<n> med_cpu=<pct>
##           top_cpu=<pct> dstate=<n>
##
## `med_cpu` is the median across the task's processes and is the starvation
## signal for the one-sim-one-core model. `top_cpu` is the busiest single
## process and is what identifies a workload that model does not describe: an
## rstan/cmdstanr task is one idle R wrapper plus a threaded binary at several
## hundred percent, where a median is meaningless.
set -u
INT="${1:-5}"
HZ=$(getconf CLK_TCK 2>/dev/null || echo 100)
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT

# Node-level context, reported whether or not this user has anything here. A
# task's own CPU says nothing about WHY it is low, and the per-task view cannot
# see the other tenants: processes owned by other users are invisible to this
# probe by construction. Load against core count is the one cheap number that
# distinguishes "this node is oversubscribed" from "this node is idle and my
# task is stuck on something else", which is exactly the question a starved
# reading raises.
printf 'nodeinfo=1 cores=%s load1=%s\n' \
  "$(nproc 2>/dev/null || echo '?')" \
  "$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo '?')"

# Timestamp EACH sample from /proc/uptime rather than assuming the nominal
# interval: reading ~36 procs takes real time, so dividing by INT alone inflates
# every reading (measured ~1.27x, giving impossible >100% for 1-thread workers).
# Every process the user owns, not just those named `R`, filtered to those that
# carry a SLURM_JOB_ID. Membership of a task is decided by that variable rather
# than by the process name, because a task's real work is not always in R: an
# rstan/cmdstanr job is an idle R wrapper plus a compiled `model_<hash>` binary
# doing everything at several hundred percent, and `pgrep -x R` saw only the
# wrapper. Children inherit the variable, so the binary is attributed correctly
# (verified on a live cmdstan array: the model binary carries both
# SLURM_JOB_ID and SLURM_ARRAY_TASK_ID). Login shells, sshd and the probe's own
# processes have no SLURM_JOB_ID and drop out for free.
for p in $(pgrep -u "$USER" 2>/dev/null); do
  # The batch script wrapper is always present, always idle, and is never the
  # workload. Counting it would inflate `nproc` past MIN_PROC during startup and
  # cost the master-only grace period that keeps a starting task from being
  # judged.
  case "$(cat "/proc/$p/comm" 2>/dev/null)" in slurm_script) continue;; esac
  # `2>/dev/null` BEFORE the input redirect, not after. Redirections apply left
  # to right, so a trailing one is set up after the open has already failed and
  # the shell has already written "Permission denied" to the real stderr. Only
  # matters now that the scan is every process rather than our own R ones:
  # setuid processes are unreadable and short-lived ones vanish mid-scan.
  env_kv=$(tr '\0' '\n' 2>/dev/null < "/proc/$p/environ")
  jid=$(sed -n 's/^SLURM_JOB_ID=//p' <<< "$env_kv" | head -1)
  [ -n "${jid:-}" ] || continue
  # The array-qualified id, taken from the task's own environment rather than
  # inferred later. PSOCK workers inherit it from the master, so every process
  # of a task agrees.
  ajid=$(sed -n 's/^SLURM_ARRAY_JOB_ID=//p' <<< "$env_kv" | head -1)
  atid=$(sed -n 's/^SLURM_ARRAY_TASK_ID=//p' <<< "$env_kv" | head -1)
  if [ -n "${ajid:-}" ] && [ -n "${atid:-}" ]; then tid="${ajid}_${atid}"; else tid="$jid"; fi
  t=$(awk '{print $14+$15}' "/proc/$p/stat" 2>/dev/null)
  u=$(awk '{print $1}' /proc/uptime 2>/dev/null)
  [ -n "${t:-}" ] && [ -n "${u:-}" ] && echo "$jid $tid $p $t $u" >> "$tmp"
done
[ -s "$tmp" ] || { echo "no-r-procs"; exit 0; }

sleep "$INT"

while read -r jid tid p t0 u0; do
  t1=$(awk '{print $14+$15}' "/proc/$p/stat" 2>/dev/null)
  u1=$(awk '{print $1}' /proc/uptime 2>/dev/null)
  st=$(awk '{print $3}' "/proc/$p/stat" 2>/dev/null)
  [ -n "${t1:-}" ] && [ -n "${u1:-}" ] || continue
  awk -v j="$jid" -v k="$tid" -v a="$t0" -v b="$t1" -v x="$u0" -v y="$u1" -v hz="$HZ" -v s="${st:-R}" \
      'BEGIN{ dt=y-x; if (dt<=0) dt=1; printf "%s %s %d %s\n", j, k, (b-a)*100.0/(dt*hz), s }'
done < "$tmp" | awk '
  { j=$1; tid[j]=$2; v[j]=v[j] $3 " "; n[j]++; if ($4=="D") d[j]++ }
  END {
    for (j in v) {
      m = split(v[j], a, " ")
      for (i=1;i<=m;i++) for (k=i+1;k<=m;k++) if (a[k]+0 < a[i]+0) { t=a[i]; a[i]=a[k]; a[k]=t }
      # Drop the single lowest sample before taking the median: that is always the
      # idle callr master (~3%), and with an even process count it would otherwise
      # be averaged into the median and drag a healthy task down (e.g. master+1
      # worker = [3,99] -> median 51 -> false "starved"). Dropping it gives 99.
      lo = (m >= 2) ? 2 : 1
      c  = m - lo + 1
      med = (c % 2) ? a[lo + int((c-1)/2)] \
                    : int((a[lo + int(c/2) - 1] + a[lo + int(c/2)]) / 2)
      # The busiest single process, which is what tells a MULTI-THREADED workload
      # apart from a starved single-threaded one. Nothing in the one-sim-one-core
      # model ever exceeds ~100%; a reading well above it means threads, and the
      # median stops being interpretable. `degen_watch.sh` uses this to decline
      # to judge rather than to guess.
      printf "jobid=%s taskid=%s nproc=%d med_cpu=%d top_cpu=%d dstate=%d\n", \
             j, tid[j], n[j], med, a[m], (j in d ? d[j] : 0)
    }
  }'
