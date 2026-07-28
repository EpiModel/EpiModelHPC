# Bash Lines to Reap a Job's Own R Workers on Cancel or Timeout

Returns bash lines defining a `cleanup_r_workers` shell function and
trapping it on `TERM` and `EXIT`. Append them to the `setup_lines` of
any `step_tmpl_` function, or to a project's own node-setup vector. They
are included by default in the `r_loader` of
[`swf_configs_rsph`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md).

## Usage

``` r
swf_cleanup_r_workers()
```

## Value

a character vector of bash lines

## Why this is needed

The RSPH cluster runs `ProctrackType=proctrack/linuxproc` with
`TaskPlugin=task/affinity` and no cgroup containment, so SLURM locates a
job's processes by walking parent-PID chains. R's PSOCK workers reparent
to init once their launcher exits, which severs that chain. On any
non-clean termination (`scancel`, TIME_LIMIT, or preemption) the master
dies and the workers survive, still pinned to their original core mask.
SLURM marks those cores free and schedules new work onto them, so two
independent process sets share the same cores and each gets roughly half
a core. The next task to land there runs many times slower and is
eventually killed at its walltime, which leaks more workers in turn.

Measured on 2026-07-18: cancelling one calibration array left 163
orphans on 15 nodes for about 2.5 hours (roughly 400 core-hours), and
two unrelated projects were degraded on the same node in the same
two-hour window.

## Implementation notes

Three details are load-bearing and were each bugs in an earlier draft.

1.  `grep -qxz`, not `-qz`. Without `-x` the match is an unanchored
    substring, so `SLURM_JOB_ID=4135` matches `41352064`, and an empty
    `SLURM_JOB_ID` degrades the pattern to `SLURM_JOB_ID=` which matches
    every R process the user owns, including other live jobs.
    `/proc/<pid>/environ` is permission-gated across users but not
    across one user's own concurrent jobs.

2.  The `[ -n "${SLURM_JOB_ID:-}" ] || return 0` guard, so the function
    is a no-op outside SLURM rather than a wildcard.

3.  The trailing `:` so it always returns 0. Step scripts run `set -e`,
    and on a normal exit the workers are already gone, so the final
    `grep` fails and the step would exit non-zero despite succeeding.

`SLURM_JOB_ID` is unique per array task, so a cancelled task reaps only
its own workers. Do not key this on `SLURM_ARRAY_JOB_ID`, which would
kill every task in the array.

## Limits

This is containment, not protection. It stops a dying job from leaving
orphans; it does nothing to protect a job from orphans already squatting
on the cores it was handed. It also does not cover `SIGKILL` (node
failure, OOM, `scancel -s KILL`) or, reliably, preemption. The root fix
is cgroup containment (`ProctrackType=proctrack/cgroup` plus
`TaskPlugin=task/cgroup` with `ConstrainCores=yes`), which is an
administrative change.

## Examples

``` r
if (FALSE) { # \dontrun{
setup_lines <- c(hpc_configs$r_loader, swf_cleanup_r_workers())
} # }
```
