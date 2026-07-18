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
## Usage:  probe_node_cpu.sh [interval_secs]
## Output: one line per SLURM task ->
##         jobid=<numeric> nproc=<n> med_cpu=<pct> dstate=<n>
set -u
INT="${1:-5}"
HZ=$(getconf CLK_TCK 2>/dev/null || echo 100)
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT

# Timestamp EACH sample from /proc/uptime rather than assuming the nominal
# interval: reading ~36 procs takes real time, so dividing by INT alone inflates
# every reading (measured ~1.27x, giving impossible >100% for 1-thread workers).
for p in $(pgrep -u "$USER" -x R 2>/dev/null); do
  jid=$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | sed -n 's/^SLURM_JOB_ID=//p' | head -1)
  [ -n "${jid:-}" ] || continue
  t=$(awk '{print $14+$15}' "/proc/$p/stat" 2>/dev/null)
  u=$(awk '{print $1}' /proc/uptime 2>/dev/null)
  [ -n "${t:-}" ] && [ -n "${u:-}" ] && echo "$jid $p $t $u" >> "$tmp"
done
[ -s "$tmp" ] || { echo "no-r-procs"; exit 0; }

sleep "$INT"

while read -r jid p t0 u0; do
  t1=$(awk '{print $14+$15}' "/proc/$p/stat" 2>/dev/null)
  u1=$(awk '{print $1}' /proc/uptime 2>/dev/null)
  st=$(awk '{print $3}' "/proc/$p/stat" 2>/dev/null)
  [ -n "${t1:-}" ] && [ -n "${u1:-}" ] || continue
  awk -v j="$jid" -v a="$t0" -v b="$t1" -v x="$u0" -v y="$u1" -v hz="$HZ" -v s="${st:-R}" \
      'BEGIN{ dt=y-x; if (dt<=0) dt=1; printf "%s %d %s\n", j, (b-a)*100.0/(dt*hz), s }'
done < "$tmp" | awk '
  { j=$1; v[j]=v[j] $2 " "; n[j]++; if ($3=="D") d[j]++ }
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
      printf "jobid=%s nproc=%d med_cpu=%d dstate=%d\n", j, n[j], med, (j in d ? d[j] : 0)
    }
  }'
