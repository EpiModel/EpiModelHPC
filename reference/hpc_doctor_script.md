# Path to a Bundled HPC Doctor Script

Returns the installed path of one of the shell tools shipped with this
package for diagnosing and recovering degenerate SLURM tasks. Copy the
script to the cluster, or reference it directly from a deploy script.

## Usage

``` r
hpc_doctor_script(
  name = c("deploy_doctor.sh", "degen_watch.sh", "probe_node_cpu.sh", "term_orphans.sh")
)
```

## Arguments

- name:

  Which script to locate. One of `"deploy_doctor.sh"`,
  `"degen_watch.sh"`, `"probe_node_cpu.sh"`, `"term_orphans.sh"`.

## Value

a length-one character path

## The tools

- `probe_node_cpu.sh`:

  Node-side. Reports instantaneous CPU utilisation per SLURM task for
  every R process the user has on that node. One ssh per node covers all
  tasks on it. Reports both `jobid=` (`SLURM_JOB_ID`, the key for
  matching a task between probes) and `taskid=` (the array-qualified
  `<ArrayJobId>_<TaskId>`, the only id `scontrol` may be given).

- `degen_watch.sh`:

  Classifies each running task and requeues the degenerate ones.
  Addresses every task by its array-qualified id: a bare `ArrayJobId`
  passed to `scontrol requeue` restarts the whole array. Set `PATTERN`
  to match your job names; it is matched against the job name and scopes
  both the nodes probed and the tasks judged, so a node shared with
  another of your campaigns is safe.

- `deploy_doctor.sh`:

  A one-CPU companion job that sweeps for the life of a campaign and
  self-terminates when it drains. Submit it with `sbatch`; it carries
  its own `#SBATCH` defaults (1 CPU, 2G, 3 days, job name
  `deploy_doctor`) and locates its sibling scripts via `scontrol`, since
  `sbatch` runs a spool copy of the script from a directory the siblings
  are not in. Add `--partition` yourself, and `--time` longer than the
  campaign.

- `term_orphans.sh`:

  SIGTERMs genuinely orphaned R workers on a node. Safe on nodes shared
  with other users.

## Detect by CPU, not by runtime

Healthy workers sit at about 99 percent CPU and starved ones at about 50
percent. Measuring CPU rather than elapsed time is distribution-free: it
needs no runtime history, so there is no cold-start window on a new
deploy, it needs no per-project calibration, and it cannot mistake a
legitimately long scenario for a broken one. A slow task doing real work
still reads 99 percent and is left alone, a distinction a runtime
threshold cannot make.

## PPID is not an orphan test

[`parallelly::makeClusterPSOCK`](https://parallelly.futureverse.org/reference/makeClusterPSOCK.html)
reparents healthy workers to init, so a live worker legitimately shows
`PPID=1`. Verified on 2026-07-18: 88 `PPID=1` R processes across six
nodes were all healthy workers of live jobs. Killing on that heuristic
destroys running work. The correct test, used by `term_orphans.sh`, is
whether the process's `SLURM_JOB_ID` still resolves to a job alive in
`squeue`.

## Examples

``` r
if (FALSE) { # \dontrun{
hpc_doctor_script("deploy_doctor.sh")
} # }
```
