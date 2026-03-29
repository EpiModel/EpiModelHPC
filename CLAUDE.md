# EpiModelHPC

## Overview

EpiModelHPC is an R package that extends the core
[EpiModel](https://github.com/EpiModel/EpiModel) package for running
stochastic network epidemic models on high-performance computing (HPC)
systems. It provides parallelization, checkpointing, scenario batching,
and integration with
[slurmworkflow](https://github.com/EpiModel/slurmworkflow) for
Slurm-based job scheduling.

## Package Structure

- `R/` - 13 source files with core functionality
- `man/` - roxygen2-generated documentation (32 .Rd files)
- `vignettes/` - detailed vignette on slurmworkflow integration
- `tests/` - testthat tests

## Key Dependencies

- **EpiModel** (\>= 2.5.0) - core epidemic modeling framework
- **slurmworkflow** - Slurm workflow management (GitHub:
  EpiModel/slurmworkflow)
- **swfcalib** - calibration framework (GitHub: EpiModel/swfcalib)
- **doParallel / foreach** - parallel execution
- **future / future.apply** - scenario-level parallelization

## Key Functions

- [`netsim_hpc()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md) -
  parallel netsim with checkpointing
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
- [`step_tmpl_renv_restore()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_renv_restore.md) -
  renv setup on HPC

## Build & Check

``` bash
R CMD build .
R CMD check EpiModelHPC_*.tar.gz
```

## Style

- roxygen2 with markdown for documentation
- Pipe operator: `|>` (base R pipe)
- tidyverse style (dplyr, tidyr, rlang)
