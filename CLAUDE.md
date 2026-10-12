# EpiModelHPC

## Overview
EpiModelHPC is an R package that extends the core [EpiModel](https://github.com/EpiModel/EpiModel) package for running stochastic network epidemic models on high-performance computing (HPC) systems. It provides scenario batching, merging of simulation output, cluster presets, and step templates for [slurmworkflow](https://github.com/EpiModel/slurmworkflow), which handles Slurm-based job scheduling. Parallelism and checkpointing come from EpiModel itself (`ncores`, `.checkpoint.dir` and `.checkpoint.steps` in `control.net()`).

## Package Structure
- `R/` - 5 source files with core functionality
- `man/` - roxygen2-generated documentation
- `vignettes/` - detailed vignette on slurmworkflow integration
- `tests/` - testthat tests

## Key Dependencies
- **EpiModel** (>= 2.5.0) - core epidemic modeling framework
- **slurmworkflow** - Slurm workflow management (GitHub: EpiModel/slurmworkflow)
- **swfcalib** - calibration framework (GitHub: EpiModel/swfcalib)
- **future / future.apply** - scenario-level parallelization

## Key Functions
- `netsim_scenarios()` / `step_tmpl_netsim_scenarios()` - scenario-based simulation (local / HPC)
- `merge_netsim_scenarios()` / `step_tmpl_merge_netsim_scenarios()` - merge batch results
- `merge_netsim_scenarios_tibble()` - convert results to tibble
- `swf_configs_hyak()` / `swf_configs_rsph()` - cluster presets (`swf_configs_rsph()` knows the current RSPH partitions; `preemptable` no longer exists)
- `step_tmpl_renv_restore()` - renv setup on HPC
- `hpc_doctor_script()`, `add_doctor_register_step()`, `add_doctor_teardown_step()` - workflow monitoring helpers

## Removed in 2.8.0
The pre-`slurmworkflow` HPC path is gone, so do not suggest these functions: `netsim_hpc()` (use `EpiModel::netsim()` with `ncores` in `control.net()`), `check_cp()`, `initialize_cp()`, `save_cpdata()` (use EpiModel's `.checkpoint.dir` and `.checkpoint.steps`), `savesim()`, `merge_simfiles()`, `process_simfiles()` (use `merge_netsim_scenarios()` or `merge_netsim_scenarios_tibble()`), `sbatch_master()` (use the slurmworkflow step templates), and `pull_env_vars()` (handled by slurmworkflow). See NEWS.md.

## Build & Check
```bash
R CMD build .
R CMD check EpiModelHPC_*.tar.gz
```

## Style
- roxygen2 with markdown for documentation
- Pipe operator: `|>` (base R pipe)
- tidyverse style (dplyr, tidyr, rlang)
