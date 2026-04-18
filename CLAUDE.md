# EpiModelHPC

## Overview
EpiModelHPC is an R package that extends [EpiModel](https://github.com/EpiModel/EpiModel) for running batched scenario simulations on Slurm-based HPC systems. It provides scenario orchestration, [slurmworkflow](https://github.com/EpiModel/slurmworkflow) step templates, and [swfcalib](https://github.com/EpiModel/swfcalib) integration helpers.

## Package Structure
- `R/` - 5 source files
- `man/` - 19 roxygen2-generated .Rd files
- `vignettes/` - slurmworkflow integration vignette
- `tests/` - testthat tests

## Key Dependencies
- **EpiModel** (>= 2.7.0) - core epidemic modeling framework
- **slurmworkflow** - Slurm workflow management (GitHub: EpiModel/slurmworkflow)
- **swfcalib** - calibration framework (GitHub: EpiModel/swfcalib)
- **future / future.apply** - scenario-level parallelization
- **callr** - isolated R process execution for local scenario runs

## Key Functions
- `netsim_scenarios()` / `step_tmpl_netsim_scenarios()` - scenario-based simulation (local / HPC)
- `netsim_swfcalib_output()` / `step_tmpl_netsim_swfcalib_output()` - run sims from calibrated parameters
- `merge_netsim_scenarios()` / `step_tmpl_merge_netsim_scenarios()` - merge batch results
- `merge_netsim_scenarios_tibble()` / `step_tmpl_merge_netsim_scenarios_tibble()` - convert results to tibble
- `swfcalib_proposal_to_scenario()` - convert swfcalib proposals to EpiModel scenarios
- `step_tmpl_renv_restore()` - renv setup on HPC
- `verbose.hpc.net()` - HPC-friendly progress printing

## Build & Check
```bash
R CMD build .
R CMD check EpiModelHPC_*.tar.gz
```

## Style
- roxygen2 with markdown for documentation
- Pipe operator: `|>` (base R pipe)
- tidyverse style (dplyr, rlang)
- Do not use `call. = FALSE` in `stop()` or `warning()` calls
