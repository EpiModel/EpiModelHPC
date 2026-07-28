#!/bin/bash
## SIGTERM orphaned R workers left behind by cancelled/timed-out jobs.
##
## CORRECT ORPHAN TEST -- read this before changing anything:
##   PPID=1 is NOT a valid orphan test. EpiModel/swfcalib run their workers via
##   parallelly::makeClusterPSOCK, which REPARENTS HEALTHY WORKERS TO INIT, so a
##   perfectly live worker legitimately shows PPID=1. (Verified 2026-07-18: 88
##   PPID=1 R procs across 6 nodes were all healthy workers of live jobs.)
##   The real test is whether the process's SLURM_JOB_ID still resolves to a job
##   that is alive in squeue. That is what this script uses.
##
## This matters because the cluster runs ProctrackType=proctrack/linuxproc with
## NO cgroup containment, so PSOCK workers survive scancel, stay invisible to
## SLURM, and keep spinning at ~98% CPU on cores SLURM then re-allocates -- which
## starves the next task to ~50% of a core and makes an 8-min job take hours.
##
## Safe on nodes shared with other users: only ever inspects `ps -u $USER`.
## Sends SIGTERM (graceful), not SIGKILL.
##
## Usage:  ssh <node> "bash /path/to/term_orphans.sh [min_age_secs]"
##         DRY=1 to report only.
set -u
THRESH=${1:-600}
DRY="${DRY:-}"

if ! command -v squeue >/dev/null 2>&1; then
  echo "ERROR: squeue not available on $(hostname); cannot verify job liveness. Aborting." >&2
  exit 2
fi

# Every identifier a live job of ours may present: task id (%i), array base (%A), array job (%F).
LIVE=$(squeue -h -u "$USER" -o "%i %A %F" 2>/dev/null | tr ' ' '\n' | sed '/^$/d' | sort -u)

orphans=""
while read -r pid age; do
  [ -n "${pid:-}" ] || continue
  [ "$age" -ge "$THRESH" ] 2>/dev/null || continue
  env_file="/proc/$pid/environ"
  [ -r "$env_file" ] || continue
  jid=$(tr '\0' '\n' < "$env_file" 2>/dev/null | sed -n 's/^SLURM_JOB_ID=//p' | head -1)
  if [ -z "$jid" ]; then
    continue                                   # no SLURM lineage: not ours to judge, skip
  fi
  if ! grep -qx -- "$jid" <<< "$LIVE"; then
    orphans="$orphans $pid"                    # job is GONE -> genuine orphan
  fi
done < <(ps -u "$USER" -o pid=,etimes=,comm= | awk '$3=="R"{print $1, $2}')

orphans=$(echo $orphans)
if [ -z "$orphans" ]; then
  echo "$(hostname): no orphans (all R procs map to live jobs, or younger than ${THRESH}s)"
  echo -n "  R procs for $USER here: "; ps -u "$USER" -o comm= | grep -c '^R$'
  exit 0
fi

echo "$(hostname): ORPHANS (SLURM_JOB_ID no longer live):"
for p in $orphans; do
  ps -o pid=,etimes=,%cpu=,rss=,comm= -p "$p" 2>/dev/null \
    | awk '{printf "  PID %-9s age %-7ss cpu %-6s%% rss %-8.0fMB %s\n",$1,$2,$3,$4/1024,$5}'
done

if [ -n "$DRY" ]; then echo "  DRY=1 set; nothing killed."; exit 0; fi
echo "  sending SIGTERM..."
kill -15 $orphans 2>/dev/null
sleep 8
still=""
for p in $orphans; do kill -0 "$p" 2>/dev/null && still="$still $p"; done
echo "  survivors:${still:- none}"
echo -n "  R procs for $USER remaining here: "; ps -u "$USER" -o comm= | grep -c '^R$'
