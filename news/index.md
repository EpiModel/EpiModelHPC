# Changelog

## EpiModelHPC 2.9.1

### BUG FIXES

- `degen_watch.sh` no longer judges the job it is running inside. The
  doctor’s own job name necessarily matches `PATTERN`, since that is how
  it is scoped to a campaign, so it sits inside its own task set; and
  once the process scan widened past `pgrep -x R` in 2.9.0, its own
  `sleep` and `ssh` processes became visible too. That reads as a task
  at 0% CPU with nothing in D-state, which is exactly the `hung`
  signature, so the doctor confirmed itself hung once per sweep and
  would have requeued itself. Caught on the first campaign to run 2.9.0:
  ten consecutive confirmations of the doctor’s own job id, spared only
  because its restart counter already sat at `MAX_RESTARTS`. Any task
  whose `jobid` equals `SLURM_JOB_ID` is now skipped before
  classification.

## EpiModelHPC 2.9.0

### NEW FEATURES

- The doctor no longer assumes a task’s work happens in R. Task
  membership is decided by `SLURM_JOB_ID` from `/proc/<pid>/environ`
  rather than by process name, so a compiled child such as an
  `rstan`/`cmdstanr` `model_<hash>` binary is attributed to the task
  that launched it. `pgrep -x R` saw only the idle R wrapper and
  reported `nproc=1 med_cpu=0` for a task consuming four cores. The
  batch script wrapper is excluded by name so `nproc` still reflects the
  workload and a starting task keeps its `MIN_PROC` grace period.
- `probe_node_cpu.sh` reports `top_cpu=`, the busiest single process in
  a task, and `degen_watch.sh` declines to judge any task whose
  `top_cpu` exceeds `MULTICORE_CPU` (default 150), reporting it as
  `threaded`. The whole detector rests on one simulation per core at
  about 100%, which is what makes a median a starvation signal; a
  threaded binary at several hundred percent is outside that model, and
  a healthy 4-thread chain cannot be told from a contended 8-thread one
  from outside the process. Under-flagging is the correct failure, since
  the alternative is requeuing a healthy Bayesian fit.
- `probe_node_cpu.sh` reports `nodeinfo=1 cores= load1=` per node,
  printed for any node that produced a suspect. The probe only sees the
  invoking user’s processes, so another account’s job can starve a task
  with nothing in the per-task view to show for it. Load against core
  count separates a suspect on a node at 30 of 32, where contention is
  real and excluding the node may be justified, from the same suspect on
  a node at 4 of 32, where it is not.

### BUG FIXES

- `degen_watch.sh` warns when the probe reached its nodes but attributed
  no process to any running task. The existing guard only covered a
  probe that returned nothing at all, which the new per-node line makes
  impossible.
- `probe_node_cpu.sh` no longer leaks “Permission denied” to stderr when
  scanning processes it cannot read. `2>/dev/null` after an input
  redirect is set up only after the failing open, so it never caught the
  shell’s own message; it now precedes the redirect. Only reachable
  since the scan widened beyond the user’s own R processes.

## EpiModelHPC 2.8.3

### BUG FIXES

- `degen_watch.sh` no longer reports an idle task as CPU-starved, and no
  longer excludes the node it was running on. `dstate == 0` defaulted to
  `cpustarv` at any CPU level, but losing a share of the cores to a
  competitor reads near 50% and a task with no competitor and no I/O
  wait reads near zero. On a 64-task `swfcalib` array, 100 of 127
  confirmed events read 0-3% against 23 at the genuine 51% signature;
  the nodes blamed were idle and process-free minutes later, and the
  requeued tasks had never begun work, all stopping inside package
  loading. `dstate == 0` with CPU at or below `HUNG_CPU` is now
  classified `hung`: still requeued promptly, but the node is not
  implicated, matching what the classifier already did for the same
  condition when one process happened to be in D-state.
- The confirmation line reports the classification (`CONFIRMED HUNG`,
  `CONFIRMED CPU-STARVED`, `CONFIRMED IO-STALLED`) instead of a blanket
  `CONFIRMED STARVED`. The label is what sends an operator looking for a
  competitor that may never have been there. The `CONFIRMED` token is
  unchanged, so existing log greps still match.

## EpiModelHPC 2.8.2

### OTHER

- [`make_calibrated_scenario()`](http://epimodel.github.io/EpiModelHPC/reference/make_calibrated_scenario.md)
  calls
  [`swfcalib::load_calib_object()`](https://epimodel.github.io/swfcalib/reference/load_calib_object.html)
  and
  [`swfcalib::get_default_proposal()`](https://epimodel.github.io/swfcalib/reference/get_default_proposal.html)
  with `::` now that both are exported (EpiModel/swfcalib#34), clearing
  the `:::` NOTE from `R CMD check`. Requires a swfcalib built from
  `main` at or after that merge; the version there is unchanged at
  0.0.0.9000, so `DESCRIPTION` cannot state the requirement.

## EpiModelHPC 2.8.1

### BUG FIXES

- `deploy_doctor.sh` locates its sibling scripts correctly when a
  project wrapper submits itself and then runs the installed doctor by
  full path. 2.6.3 made `scontrol show job` outrank `$BASH_SOURCE`,
  which is right for `sbatch deploy_doctor.sh` but wrong here:
  `scontrol` reports the wrapper, not the doctor. The startup guard
  caught it, so the job failed loudly rather than sweeping nothing, but
  it failed. Each candidate is now tested for the siblings instead of
  being ranked blind, so both launch styles work with no `ROOT` set.

## EpiModelHPC 2.8.0

### BREAKING CHANGES

- Removed the pre-`slurmworkflow` HPC path. It was driven by environment
  variables exported from a hand-written master sbatch script, and
  nothing in the package or in any current project still reached it.
  Replacements:
  - `netsim_hpc()`: use
    [`EpiModel::netsim()`](https://epimodel.github.io/EpiModel/reference/netsim.html)
    directly, with `ncores` in
    [`control.net()`](https://epimodel.github.io/EpiModel/reference/control.net.html)
    for parallelism.
  - `check_cp()`, `initialize_cp()`, `save_cpdata()`: use EpiModel’s
    `.checkpoint.dir` and `.checkpoint.steps` in
    [`control.net()`](https://epimodel.github.io/EpiModel/reference/control.net.html).
  - `savesim()`, `merge_simfiles()`, `process_simfiles()`: use
    [`merge_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios.md)
    or
    [`merge_netsim_scenarios_tibble()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios_tibble.md).
  - `sbatch_master()`: use the `slurmworkflow` step templates,
    [`step_tmpl_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_scenarios.md)
    and friends.
  - `pull_env_vars()`: handled internally by `slurmworkflow`.
  - `verbose.hpc.net()`: no replacement. It printed progress for
    `netsim_hpc()` only.
- Dropped dependencies, all unused once the above went: `doParallel`,
  `foreach`, `ergm`, `tergm`, `tidyr`, and `network` from Suggests.

### OTHER

- `CLAUDE.md` and `_pkgdown.yml` are excluded from the built package.
- Removed `test-netsimpar.R`, which exercised
  [`EpiModel::netsim()`](https://epimodel.github.io/EpiModel/reference/netsim.html)
  rather than anything in this package.
- Refreshed stale metadata: the `Description` field no longer advertises
  PBS check-pointing, the package documentation no longer carries a
  hand-maintained version table, and three dead URLs are fixed.

## EpiModelHPC 2.7.0

### NEW FEATURES

- The deploy doctor reports pending-side barriers. `slurmworkflow`
  submits netsim in slices and the next slice only goes in when the last
  task of the current one finishes, so one queued straggler stops all
  progress. There is no process to probe, so the CPU detector was blind
  to it. Sweeps with tasks pending and none running are now counted and,
  past `BARRIER_WARN`, reported with each pending task’s SLURM reason.
  Observability only; slice progression is untouched.

- The deploy doctor exits promptly when a campaign really is finished.
  It reads the same watch list
  [`add_doctor_teardown_step()`](http://epimodel.github.io/EpiModelHPC/reference/doctor_watch_steps.md)
  maintains, passed as `WATCH_DIR`. With a campaign still registered an
  empty queue is treated as a lull between steps and it waits the full
  `IDLE_EXIT`; with none registered it exits after the shorter
  `IDLE_FAST`. The watch list can only make it more patient, so a stale
  marker cannot hold it open to its walltime.

### BUG FIXES

- Task counting uses `squeue -r`, so a collapsed pending array range
  contributes the tasks it actually holds rather than one. Reported
  counts read higher than before for the same queue.

## EpiModelHPC 2.6.4

### BREAKING CHANGES

- [`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md)
  no longer takes `git_version` and no longer loads git. Git is the
  system binary on the RSPH compute nodes, verified against the cluster.
  [`swf_configs_hyak()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_hyak.md)
  is unchanged.

### OTHER

- [`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md)
  defaults `r_version` to 4.5.1, up from 4.2.1.

## EpiModelHPC 2.6.0

### NEW FEATURES

- [`swf_cleanup_r_workers()`](http://epimodel.github.io/EpiModelHPC/reference/swf_cleanup_r_workers.md)
  returns bash lines trapping `TERM` and `EXIT` to reap a job’s own R
  workers. RSPH runs `proctrack/linuxproc` with no cgroup containment,
  so PSOCK workers reparent to init and survive `scancel`, staying
  pinned to cores SLURM has already re-allocated. One cancelled
  calibration array left 163 orphans on 15 nodes for about 2.5 hours.
  [`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md)
  appends the trap to `r_loader` by default; set
  `cleanup_workers = FALSE` to opt out.

- [`hpc_doctor_script()`](http://epimodel.github.io/EpiModelHPC/reference/hpc_doctor_script.md)
  locates four bundled shell tools that detect and recover degenerate
  SLURM tasks by measuring CPU utilisation rather than elapsed runtime.
  See `inst/hpc_doctor/README.md`.

- [`add_doctor_register_step()`](http://epimodel.github.io/EpiModelHPC/reference/doctor_watch_steps.md)
  and
  [`add_doctor_teardown_step()`](http://epimodel.github.io/EpiModelHPC/reference/doctor_watch_steps.md)
  maintain a watch list so a deploy doctor shared across concurrent
  campaigns is stopped only when the last one finishes.
