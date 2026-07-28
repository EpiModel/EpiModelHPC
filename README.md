# EpiModelHPC

<!-- badges: start -->
[![R-CMD-check](https://github.com/EpiModel/EpiModelHPC/workflows/R-CMD-check/badge.svg)](https://github.com/EpiModel/EpiModelHPC/actions)
<!-- badges: end -->

EpiModelHPC extends the [EpiModel](https://github.com/EpiModel/EpiModel) R package for running stochastic network epidemic models on high-performance computing (HPC) systems. If you are already using EpiModel's `netsim` function to simulate epidemic dynamics on local hardware and need to scale up -- running hundreds of simulations across parameter scenarios on a multi-node cluster -- EpiModelHPC provides the tools to get there.

## How EpiModelHPC Relates to EpiModel

[EpiModel](https://www.epimodel.org/) is the core R package for simulating mathematical models of infectious disease dynamics using stochastic, individual-based network models based on exponential-family random graph models (ERGMs). EpiModel handles network estimation (`netest`), epidemic simulation (`netsim`), and analysis of results on a single machine.

EpiModelHPC does not replace any of this. Instead, it wraps and extends EpiModel's simulation engine with functionality needed when models become too computationally intensive for a single workstation:

- **Parallelization**: Distributes simulation replicates across multiple cores on an HPC node.
- **Checkpointing**: Automatically saves intermediate simulation state at configurable intervals, so that long-running jobs can resume from where they left off if interrupted (e.g., by a wall-time limit).
- **Scenario Batching**: Runs multiple parameter scenarios (defined via `EpiModel::create_scenario_list`) in batched parallel jobs, with deterministic file naming for downstream merging.
- **Result Merging**: Merges outputs from distributed batch jobs back into single simulation objects or tidy data frames for analysis.

If your simulations complete in reasonable time on a laptop, you likely do not need this package. EpiModelHPC is designed for the point at which you need to run large numbers of replicates, sweep across many scenarios, or your model's per-replicate runtime exceeds what is practical without job scheduling.

## How slurmworkflow Fits In

[slurmworkflow](https://github.com/EpiModel/slurmworkflow) is a companion R package that provides a general-purpose framework for defining and submitting multi-step Slurm job workflows from R. It handles the mechanics of writing sbatch scripts, managing job dependencies, and organizing output directories.

EpiModelHPC builds directly on slurmworkflow by providing **step templates** -- pre-built workflow steps tailored to common EpiModel tasks:

| EpiModelHPC Step Template | Purpose |
|---|---|
| `step_tmpl_netsim_scenarios()` | Submit scenario-based `netsim` simulations as a Slurm array job |
| `step_tmpl_merge_netsim_scenarios()` | Merge batched simulation files into one file per scenario |
| `step_tmpl_merge_netsim_scenarios_tibble()` | Convert merged results to tidy tibble format |
| `step_tmpl_netsim_swfcalib_output()` | Run simulations using calibrated parameters from [swfcalib](https://github.com/EpiModel/swfcalib) |
| `step_tmpl_renv_restore()` | Ensure the HPC project environment is up to date via `renv` |

Each step template has a corresponding standalone function (e.g., `netsim_scenarios()`) that runs the same logic locally for testing before submitting to the cluster.

A typical applied workflow looks like:

1. **Estimate networks** locally with `EpiModel::netest`.
2. **Test simulations** locally with `netsim_scenarios()` on a small number of replicates.
3. **Define a slurmworkflow** using `step_tmpl_netsim_scenarios()` and `step_tmpl_merge_netsim_scenarios()` to run at scale on the cluster.
4. **Merge and analyze** results locally or on the cluster.

EpiModelHPC also provides pre-configured cluster settings for specific HPC environments (`swf_configs_hyak()` for the University of Washington HYAK cluster, `swf_configs_rsph()` for the Emory RSPH cluster) that supply sensible default sbatch options and R module-loading commands.

## Installation

EpiModelHPC and its companion packages are hosted on GitHub. Install with:

```r
if (!require("remotes")) install.packages("remotes")
remotes::install_github("EpiModel/EpiModelHPC")
```

This will also install `slurmworkflow` and `swfcalib` from their GitHub repositories.

## Key Functions

### Simulation
- **`netsim_scenarios()`** -- Run multiple scenarios locally with batched parallelization. Mirrors `step_tmpl_netsim_scenarios()` for local testing.
- **`netsim_swfcalib_output()`** -- Run scenarios built from the result of an `swfcalib` calibration.

### File Management
- **`merge_netsim_scenarios()`** -- Merge per-batch simulation files into one `netsim` object per scenario.
- **`merge_netsim_scenarios_tibble()`** -- Convert scenario results to a single tidy tibble per scenario with configurable column selection and time-step truncation.
- **`get_scenarios_batches_infos()`** / **`get_scenarios_tibble_infos()`** -- Inspect output directories to list available simulation files and their associated scenarios.

### HPC Configuration
- **`swf_configs_hyak()`** / **`swf_configs_rsph()`** -- Return lists of sbatch options, renv build settings, and R module-loading commands for supported clusters.
- **`swf_cleanup_r_workers()`** -- Bash lines trapping `TERM`/`EXIT` to reap a job's own R workers, so cancelled jobs do not leave orphans squatting on cores. Included in `swf_configs_rsph()` by default.
- **`hpc_doctor_script()`** -- Path to the bundled shell tools that detect and requeue CPU-starved SLURM tasks. See `inst/hpc_doctor/README.md`.
- **`add_doctor_register_step()`** / **`add_doctor_teardown_step()`** -- Workflow steps that keep a shared deploy doctor running until the last campaign watching it finishes.

## System Requirements

While developed for Linux-based HPC clusters running the [Slurm](https://slurm.schedmd.com/) workload manager, the local scenario functions work on any system with multiple cores, including macOS and Windows workstations. The slurmworkflow integration, the step templates, and the HPC doctor tooling are specific to Slurm-managed clusters.

## Resources

- **EpiModel website**: <https://www.epimodel.org/>
- **EpiModelHPC documentation**: <https://epimodel.github.io/EpiModelHPC/>
- **slurmworkflow**: <https://github.com/EpiModel/slurmworkflow>
- **Bug reports**: <https://github.com/EpiModel/EpiModelHPC/issues>
