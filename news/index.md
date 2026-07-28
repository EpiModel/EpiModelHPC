# Changelog

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
