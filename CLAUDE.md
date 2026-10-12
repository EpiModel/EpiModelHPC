# EpiModelHPC

## Overview

EpiModelHPC is an R package that extends the core
[EpiModel](https://github.com/EpiModel/EpiModel) package for running
stochastic network epidemic models on high-performance computing (HPC)
systems. It provides scenario batching, merging of simulation output,
cluster presets, and step templates for
[slurmworkflow](https://github.com/EpiModel/slurmworkflow), which
handles Slurm-based job scheduling. Parallelism and checkpointing come
from EpiModel itself (`ncores`, `.checkpoint.dir` and
`.checkpoint.steps` in `control.net()`).

## Package Structure

- `R/` - 5 source files with core functionality
- `man/` - roxygen2-generated documentation
- `vignettes/` - detailed vignette on slurmworkflow integration
- `tests/` - testthat tests

## Key Dependencies

- **EpiModel** (\>= 2.5.0) - core epidemic modeling framework
- **slurmworkflow** - Slurm workflow management (GitHub:
  EpiModel/slurmworkflow)
- **swfcalib** - calibration framework (GitHub: EpiModel/swfcalib)
- **future / future.apply** - scenario-level parallelization

## Key Functions

- [`netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_scenarios.md)
  /
  [`step_tmpl_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_scenarios.md) -
  scenario-based simulation (local / HPC)
- [`merge_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios.md)
  /
  [`step_tmpl_merge_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_merge_netsim_scenarios.md) -
  merge batch results
- [`merge_netsim_scenarios_tibble()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios_tibble.md) -
  convert results to tibble
- [`swf_configs_hyak()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_hyak.md)
  /
  [`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md) -
  cluster presets
  ([`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md)
  knows the current RSPH partitions; `preemptable` no longer exists)
- [`step_tmpl_renv_restore()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_renv_restore.md) -
  renv setup on HPC
- [`hpc_doctor_script()`](http://epimodel.github.io/EpiModelHPC/reference/hpc_doctor_script.md),
  [`add_doctor_register_step()`](http://epimodel.github.io/EpiModelHPC/reference/doctor_watch_steps.md),
  [`add_doctor_teardown_step()`](http://epimodel.github.io/EpiModelHPC/reference/doctor_watch_steps.md) -
  workflow monitoring helpers

## Removed in 2.8.0

The pre-`slurmworkflow` HPC path is gone, so do not suggest these
functions: `netsim_hpc()` (use
[`EpiModel::netsim()`](https://epimodel.github.io/EpiModel/reference/netsim.html)
with `ncores` in `control.net()`), `check_cp()`, `initialize_cp()`,
`save_cpdata()` (use EpiModel’s `.checkpoint.dir` and
`.checkpoint.steps`), `savesim()`, `merge_simfiles()`,
`process_simfiles()` (use
[`merge_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios.md)
or
[`merge_netsim_scenarios_tibble()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios_tibble.md)),
`sbatch_master()` (use the slurmworkflow step templates), and
`pull_env_vars()` (handled by slurmworkflow). See NEWS.md.

## Build & Check

``` bash
R CMD build .
R CMD check EpiModelHPC_*.tar.gz
```

## Style

- roxygen2 with markdown for documentation
- Pipe operator: `|>` (base R pipe)
- tidyverse style (dplyr, tidyr, rlang)
