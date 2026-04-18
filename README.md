# EpiModelHPC

<!-- badges: start -->
[![R-CMD-check](https://github.com/EpiModel/EpiModelHPC/workflows/R-CMD-check/badge.svg)](https://github.com/EpiModel/EpiModelHPC/actions)
<!-- badges: end -->

EpiModelHPC extends the [EpiModel](https://github.com/EpiModel/EpiModel) R package for running batched scenario simulations on Slurm-based high-performance computing (HPC) systems. If you are already using EpiModel's `netsim` function to simulate epidemic dynamics on local hardware and need to scale up -- running hundreds of simulations across parameter scenarios on a multi-node cluster -- EpiModelHPC provides the tools to get there.

## How EpiModelHPC Relates to EpiModel

[EpiModel](https://www.epimodel.org/) is the core R package for simulating mathematical models of infectious disease dynamics using stochastic, individual-based network models based on exponential-family random graph models (ERGMs). EpiModel handles network estimation (`netest`), epidemic simulation (`netsim`), parallelism (`ncores` in `control.net`), checkpointing (`.checkpoint.dir` / `.checkpoint.steps` in `control.net`), and analysis of results.

EpiModelHPC does not replace any of this. Instead, it wraps and extends EpiModel's simulation engine with functionality needed when models must run at scale on a cluster:

- **Scenario Batching**: Runs multiple parameter scenarios (defined via `EpiModel::create_scenario_list`) in batched parallel jobs, with deterministic file naming for downstream merging.
- **Result Merging**: Merges outputs from distributed batch jobs back into single simulation objects or tidy data frames for analysis.
- **slurmworkflow Integration**: Provides step templates that plug directly into [slurmworkflow](https://github.com/EpiModel/slurmworkflow) job pipelines.
- **swfcalib Integration**: Bridges [swfcalib](https://github.com/EpiModel/swfcalib) calibration results into EpiModel scenarios for production runs.

If your simulations complete in reasonable time on a laptop, you likely do not need this package. EpiModelHPC is designed for the point at which you need to run large numbers of replicates or sweep across many scenarios using Slurm job scheduling.

## How slurmworkflow Fits In

[slurmworkflow](https://github.com/EpiModel/slurmworkflow) is a companion R package that provides a general-purpose framework for defining and submitting multi-step Slurm job workflows from R. It handles the mechanics of writing sbatch scripts, managing job dependencies, and organizing output directories.

EpiModelHPC builds directly on slurmworkflow by providing **step templates** -- pre-built workflow steps tailored to common EpiModel tasks:

| EpiModelHPC Step Template | Purpose |
|---|---|
| `step_tmpl_netsim_scenarios()` | Submit scenario-based `netsim` simulations as a Slurm array job |
| `step_tmpl_merge_netsim_scenarios()` | Merge batched simulation files into one file per scenario |
| `step_tmpl_merge_netsim_scenarios_tibble()` | Convert merged results to tidy tibble format |
| `step_tmpl_netsim_swfcalib_output()` | Run simulations using calibrated parameters from swfcalib |
| `step_tmpl_renv_restore()` | Ensure the HPC project environment is up to date via `renv` |

Each step template has a corresponding standalone function (e.g., `netsim_scenarios()`) that runs the same logic locally for testing before submitting to the cluster.

A typical applied workflow looks like:

1. **Estimate networks** locally with `EpiModel::netest`.
2. **Test simulations** locally with `netsim_scenarios()` on a small number of replicates.
3. **Define a slurmworkflow** using `step_tmpl_netsim_scenarios()` and `step_tmpl_merge_netsim_scenarios()` to run at scale on the cluster.
4. **Merge and analyze** results locally or on the cluster.

## Installation

EpiModelHPC and its companion packages are hosted on GitHub. Install with:

```r
if (!require("remotes")) install.packages("remotes")
remotes::install_github("EpiModel/EpiModelHPC")
```

This will also install `slurmworkflow` and `swfcalib` from their GitHub repositories.

## Key Functions

### Scenario Simulation
- **`netsim_scenarios()`** -- Run multiple scenarios locally with batched parallelization. Mirrors `step_tmpl_netsim_scenarios()` for local testing.
- **`netsim_swfcalib_output()`** -- Run simulations using calibrated parameters from swfcalib.

### File Management
- **`merge_netsim_scenarios()`** -- Merge per-batch simulation files into one `netsim` object per scenario.
- **`merge_netsim_scenarios_tibble()`** -- Convert scenario results to a single tidy tibble per scenario with configurable column selection and time-step truncation.
- **`get_scenarios_batches_infos()`** / **`get_scenarios_tibble_infos()`** -- Inspect output directories to list available simulation files and their associated scenarios.

### Calibration Helpers
- **`swfcalib_proposal_to_scenario()`** -- Convert an swfcalib proposal into an EpiModel scenario.

## System Requirements

Developed for Linux-based HPC clusters running the [Slurm](https://slurm.schedmd.com/) workload manager. The standalone functions (`netsim_scenarios()`, `merge_netsim_scenarios()`) work on any system for local testing. The step templates are specific to Slurm-managed clusters.

## Resources

- **EpiModel website**: <https://www.epimodel.org/>
- **EpiModelHPC documentation**: <https://epimodel.github.io/EpiModelHPC/>
- **slurmworkflow**: <https://github.com/EpiModel/slurmworkflow>
- **Bug reports**: <https://github.com/EpiModel/EpiModelHPC/issues>
