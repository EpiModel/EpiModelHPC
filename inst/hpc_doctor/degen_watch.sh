#!/bin/bash
## Catch DEGENERATING SLURM tasks by measuring CPU starvation directly, and
## requeue them before they burn the walltime and lose their unit.
##
## ===================== WHY CPU, NOT RUNTIME =====================
## Degeneration is not "slow", it is STARVED. Healthy netsim/swfcalib workers sit
## at ~99% CPU; starved ones at ~50% (measured node7 vs node20/21/22, 2026-07-18)
## because orphaned workers still pinned to cores SLURM has re-allocated are
## sharing those cores (no cgroup containment on this cluster).
##
## Measuring CPU instead of runtime means:
##   - NO history required. Works on task #1 of a brand-new deploy. There is no
##     cold-start window where the threshold is unknown and we might overcorrect.
##   - NO per-project calibration. Valid across settings, population sizes,
##     scenario mixes, and other projects (swfcalib etc.) -- just change PATTERN.
##   - It cannot mistake "legitimately long scenario" for "broken": a slow task
##     doing real work still reads ~99% and is left alone. Runtime-based rules
##     cannot make that distinction at all, which is how they overcorrect.
##
## Guards against false positives:
##   MIN_AGE   - ignore young tasks (startup/est-file I/O is legitimately idle)
##   2 strikes - a starved reading must repeat after RECHECK secs before we act,
##               so a transient I/O dip cannot trigger a requeue
##   dstate    - processes in uninterruptible I/O are reported distinctly; that
##               is a filesystem stall, not CPU contention
##   MAX_RESTARTS - a genuinely pathological unit cannot requeue forever
##
## Action is REQUEUE, not cancel: the task re-runs its own unit, so no gap is
## left behind. We then hold it, add the node it degenerated on to that task's
## ExcNodeList, and release -- a bare requeue landed straight back on node7.
##
## Every scontrol/squeue call addresses the task by its ARRAY-QUALIFIED id
## (`taskid=` from the probe, <ArrayJobId>_<TaskId>), never by the raw
## SLURM_JOB_ID. Given a bare ArrayJobId, `scontrol requeue` restarts EVERY task
## in the array, and the array's first task reports its SLURM_JOB_ID as exactly
## that bare id. See "Field evidence, third campaign" in README.md.
##
## Usage:
##   bash degen_watch.sh                 # report only (default, safe)
##   bash degen_watch.sh --requeue       # act on confirmed starvation
##   PATTERN='swfcalib_step' bash degen_watch.sh    # other projects
set -u
ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}   # self-locating; override to point elsewhere
PATTERN=${PATTERN:?set PATTERN to a regex matching your job names, e.g. 'swfcalib_step'}
REQUEUE=0; [ "${1:-}" = "--requeue" ] && REQUEUE=1
CPU_FLOOR=${CPU_FLOOR:-70}     # median worker cpu% below this = starved
MIN_AGE=${MIN_AGE:-5}          # minutes; below this we never judge a task
RECHECK=${RECHECK:-45}         # seconds between strike 1 and strike 2
INT=${INT:-5}                  # sampling interval per probe
MAX_RESTARTS=${MAX_RESTARTS:-3}
MIN_PROC=${MIN_PROC:-2}       # below this the task is starting up or tearing down, not judgeable
IO_RECHECK=${IO_RECHECK:-300}   # seconds per D-state (filesystem) stall recheck cycle
IO_MAX_CYCLES=${IO_MAX_CYCLES:-3}  # recheck cycles a filesystem stall gets before requeue (they usually clear)
IO_MIN_FRAC=${IO_MIN_FRAC:-50}  # pct of a task's procs in D-state to call it a filesystem stall
HUNG_CPU=${HUNG_CPU:-5}         # median cpu% at or below this, with few procs blocked, = hung
NODE_OFFENSE_LIMIT=${NODE_OFFENSE_LIMIT:-3}   # confirmed CPU-STARVATION events on one node before it is a repeat offender
# Campaign-scoped node offense ledger. Keyed to the doctor's own SLURM job so a
# new campaign starts a clean ledger and concurrent doctors (e.g. two projects)
# never share one. Append-only; one line per confirmed intervention.
STATE_FILE=${STATE_FILE:-${TMPDIR:-/tmp}/doctor_offenses_${USER:-u}_${SLURM_JOB_ID:-manual}.tsv}

to_min() {
  local t="$1" d=0 h=0 m=0 s=0 n
  case "$t" in *-*) d="${t%%-*}"; t="${t#*-}";; esac
  n=$(awk -F: '{print NF}' <<< "$t")
  if [ "$n" -eq 3 ]; then IFS=: read -r h m s <<< "$t"; else IFS=: read -r m s <<< "$t"; fi
  echo $(( 10#${d:-0}*1440 + 10#${h:-0}*60 + 10#${m:-0} ))
}

nodes=$(squeue -u "$USER" -h -t RUNNING -o "%N %j" | grep -E "$PATTERN" | awk '{print $1}' | sort -u)
[ -n "$nodes" ] || { echo "no running tasks matching /$PATTERN/"; exit 0; }
echo "probing $(wc -w <<< "$nodes") node(s) hosting tasks matching /$PATTERN/  (floor=${CPU_FLOOR}% min_age=${MIN_AGE}m)"

probe_all() {  # -> "<node> jobid=.. nproc=.. med_cpu=.. dstate=.."
  for n in $nodes; do
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$n" \
        "bash $ROOT/probe_node_cpu.sh $INT" 2>/dev/null \
      | grep -E '^jobid=' | sed "s|^|$n |"
  done
}

suspects=""
while read -r node rest; do
  [ -n "${node:-}" ] || continue
  jid=$(sed -n 's/.*jobid=\([0-9]*\).*/\1/p' <<< "$rest")
  med=$(sed -n 's/.*med_cpu=\([0-9]*\).*/\1/p' <<< "$rest")
  [ -n "${jid:-}" ] && [ -n "${med:-}" ] || continue
  # Falls back to jid only for a probe old enough to predate `taskid=`; a
  # same-vintage probe always supplies it.
  tid=$(sed -n 's/.*taskid=\([0-9_]*\).*/\1/p' <<< "$rest"); tid=${tid:-$jid}
  np=$(sed -n 's/.*nproc=\([0-9]*\).*/\1/p' <<< "$rest")
  if [ "${np:-0}" -lt "$MIN_PROC" ]; then
    printf "  startup   %-10s %-8s %s (nproc<$MIN_PROC: master-only, not judged)\n" "$jid" "$node" "$rest"; continue
  fi
  if [ "$med" -ge "$CPU_FLOOR" ]; then
    printf "  ok        %-10s %-8s %s\n" "$jid" "$node" "$rest"
  else
    printf "  SUSPECT   %-10s %-8s %s\n" "$jid" "$node" "$rest"
    suspects="$suspects $jid:$node:$tid"
  fi
done < <(probe_all)

suspects=$(echo $suspects)
[ -n "$suspects" ] || { echo "---"; echo "all tasks healthy (median CPU >= ${CPU_FLOOR}%)"; exit 0; }

echo "--- strike 1 done; re-checking suspects in ${RECHECK}s (transient dips must not trigger) ---"
sleep "$RECHECK"

acted=0; cleared=0
for s in $suspects; do
  IFS=: read -r jid node tid <<< "$s"
  tid=${tid:-$jid}
  # Anchor the match on the field boundary: a bare `jobid=$jid` substring-matches
  # any longer id sharing that prefix, and acting on the wrong task is the one
  # mistake this script must not make.
  rest=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$node" \
         "bash $ROOT/probe_node_cpu.sh $INT" 2>/dev/null | grep -E "jobid=$jid( |$)" || true)
  if [ -z "$rest" ]; then echo "  $tid: gone (finished/moved) - nothing to do"; continue; fi
  med=$(sed -n 's/.*med_cpu=\([0-9]*\).*/\1/p' <<< "$rest")
  dst=$(sed -n 's/.*dstate=\([0-9]*\).*/\1/p' <<< "$rest")
  npr=$(sed -n 's/.*nproc=\([0-9]*\).*/\1/p' <<< "$rest")
  if [ "${med:-100}" -ge "$CPU_FLOOR" ]; then
    echo "  $tid: recovered (${med}%) - transient, SPARED"; cleared=$((cleared+1)); continue
  fi

  age_raw=$(squeue -j "$tid" -h -o "%M" 2>/dev/null | head -1)
  age=$( [ -n "${age_raw:-}" ] && to_min "$age_raw" || echo 0 )
  if [ "$age" -lt "$MIN_AGE" ]; then
    echo "  $tid: starved (${med}%) but only ${age}m old (< ${MIN_AGE}m startup grace) - SPARED"; continue
  fi
  # Classify the failure: these are different problems needing different actions.
  # Weigh dstate against nproc rather than treating any D-state process as proof of
  # a filesystem stall. A task is a master plus N workers, so one blocked process
  # out of nine is a very different condition from seven out of nine.
  #
  #   dstate == 0                      -> CPU STARVATION. Orphaned workers squat on
  #      cores SLURM re-allocated. The NODE is implicated: requeue AND exclude it.
  #
  #   dstate >= IO_MIN_FRAC% of nproc  -> FILESYSTEM (PanFS) STALL. The node is NOT
  #      at fault and these commonly clear on their own (observed 2026-07-18: two
  #      node4 tasks read 4-5% with every proc in D-state, then the node was back to
  #      4 tasks at 99%/dstate=0 minutes later). D-state procs may also be
  #      unkillable, and SIGKILL mid-PanFS-write wedges them permanently. So wait
  #      much longer and never blame the node. Note that a requeue does not fix this
  #      either: the task relocates but meets the same filesystem, so the long wait
  #      is doing the real work and the requeue is a last resort.
  #
  #   dstate < IO_MIN_FRAC% and med <= HUNG_CPU -> HUNG TASK. Nearly every process
  #      is idle rather than blocked, so this is not an I/O stall and waiting out
  #      IO_RECHECK accomplishes nothing. Requeue promptly. Do not exclude the node:
  #      a hang is not evidence of contention, which is what dstate == 0 detects.
  #      (Observed 2026-07-19: nine procs, median 0%, one in D-state, requeued
  #      correctly but only after being routed down the filesystem branch.)
  exclude_node=1; kind=cpustarv
  if [ "${dst:-0}" -gt 0 ]; then
    exclude_node=0
    [ "${npr:-0}" -gt 0 ] || npr=1          # never divide by zero on a partial probe
    io_pct=$(( dst * 100 / npr ))
    if [ "$io_pct" -lt "$IO_MIN_FRAC" ] && [ "${med:-100}" -le "$HUNG_CPU" ]; then
      kind=hung
      echo "  $tid: HUNG ${med}% with only ${dst}/${npr} proc(s) in D-state (idle, not blocked)"
      echo "     not a filesystem stall; skipping the ${IO_RECHECK}s wait"
    else
      kind=iostall
      echo "  $tid: IO-STALL ${med}% with ${dst}/${npr} proc(s) in D-state (filesystem, not contention)"
      # Filesystem stalls are usually transient: while this task is judged, its
      # siblings on the same node recover (observed 2026-07-20: every overnight
      # requeue had a sibling that came back to 98-99%, and one suspect finished
      # during the wait). A requeue barely helps (PanFS is cluster-wide, the task
      # relocates but meets the same filesystem) and re-queues behind the whole
      # array, so give the stall several recheck cycles before treating it as real.
      cleared_io=0
      for c in $(seq 1 "$IO_MAX_CYCLES"); do
        echo "     IO recheck $c/$IO_MAX_CYCLES: waiting ${IO_RECHECK}s to let it clear"
        sleep "$IO_RECHECK"
        rest3=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$node" \
                "bash $ROOT/probe_node_cpu.sh $INT" 2>/dev/null | grep -E "jobid=$jid( |$)" || true)
        if [ -z "$rest3" ]; then
          echo "     task gone (finished during the wait) - SPARED"; cleared_io=1; break
        fi
        med3=$(sed -n 's/.*med_cpu=\([0-9]*\).*/\1/p' <<< "$rest3")
        if [ "${med3:-100}" -ge "$CPU_FLOOR" ]; then
          echo "     cleared (${med3}%) - SPARED, filesystem recovered"; cleared_io=1; break
        fi
      done
      if [ "$cleared_io" = 1 ]; then cleared=$((cleared+1)); continue; fi
      echo "     still stalled after ${IO_MAX_CYCLES}x${IO_RECHECK}s -> requeue (last resort), NOT excluding $node"
    fi
  fi

  restarts=$(scontrol show job "$tid" 2>/dev/null | grep -oE "Restarts=[0-9]+" | head -1 | cut -d= -f2)
  restarts=${restarts:-0}
  echo "  $tid: CONFIRMED STARVED ${med}% on $node (age ${age}m, restarts $restarts)"

  # Node offense ledger, gated by CLASSIFICATION. Escalation-to-exclusion only
  # counts CPU-STARVATION events (dstate==0), where the node genuinely harbours
  # orphaned workers squatting on its cores: a node that keeps CPU-starving fresh
  # tasks is at fault and should be avoided. Filesystem stalls are logged too (for
  # visibility) but do NOT drive exclusion, because the classifier already ruled
  # the node not-at-fault and the field data show these are transient and
  # cluster-wide, not node-specific (observed 2026-07-20: node3 filesystem-stalled
  # twice overnight, yet its sibling tasks recovered each time; excluding it would
  # have been wrong). Escalating on filesystem stalls contradicted the classifier.
  # Counting happens even in report-only mode. State is campaign-scoped (see
  # STATE_FILE), so this is not a persistent blocklist; it resets each campaign.
  echo "$node $kind" >> "$STATE_FILE" 2>/dev/null || true
  cpu_offenses=$(grep -cE "^$node cpustarv$" "$STATE_FILE" 2>/dev/null || echo 0)
  all_offenses=$(grep -cE "^$node " "$STATE_FILE" 2>/dev/null || echo 1)
  if [ "${cpu_offenses:-0}" -ge "$NODE_OFFENSE_LIMIT" ]; then
    echo "     REPEAT OFFENDER: $node has $cpu_offenses CPU-starvation event(s) this campaign (limit $NODE_OFFENSE_LIMIT; $all_offenses total)"
    if [ "$exclude_node" != "1" ]; then
      echo "     escalating: excluding $node on this requeue (repeated CPU starvation implicates the node)"
      exclude_node=1
    fi
  elif [ "${all_offenses:-1}" -ge "$NODE_OFFENSE_LIMIT" ]; then
    echo "     note: $node has $all_offenses confirmed events this campaign ($cpu_offenses CPU-starvation); not excluding (filesystem stalls are transient/cluster-wide)"
  fi

  [ "$REQUEUE" = "1" ] || continue
  if [ "$restarts" -ge "$MAX_RESTARTS" ]; then echo "     restarts exhausted; leaving it"; continue; fi
  # Last line of defence before the destructive call. An unqualified ArrayJobId
  # would requeue the whole array, and the failure is silent: the sibling tasks
  # simply vanish from the next probe and get logged as "gone (finished/moved)".
  case "$tid" in
    *_*) ;;
    *) if scontrol show job "$tid" 2>/dev/null | grep -q "ArrayTaskId="; then
         echo "     !! $tid is an unqualified array job id; refusing to requeue (would restart the whole array)"
         continue
       fi;;
  esac
  scontrol requeue "$tid" >/dev/null 2>&1 || { echo "     !! requeue failed"; continue; }
  sleep 3; scontrol hold "$tid" >/dev/null 2>&1; sleep 2
  if [ "$exclude_node" = "1" ]; then
    prev=$(scontrol show job "$tid" 2>/dev/null | grep -oE "ExcNodeList=[^ ]*" | head -1 | cut -d= -f2)
    case "$prev" in ""|"(null)") newexc="$node";; *) newexc="$prev,$node";; esac
    scontrol update jobid="$tid" ExcNodeList="$newexc" >/dev/null 2>&1
    got=$(scontrol show job "$tid" 2>/dev/null | grep -oE "ExcNodeList=[^ ]*" | head -1)
  else
    got="(node not excluded: filesystem stall, node not at fault)"
  fi
  scontrol release "$tid" >/dev/null 2>&1
  echo "     requeued + $got + released"
  acted=$((acted+1))
done

echo "---"
echo "confirmed_starved_requeued=$acted  cleared_as_transient=$cleared"
[ "$REQUEUE" = "1" ] || echo "report-only; pass --requeue to act"
