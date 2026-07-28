# EpiModelHPC

EpiModelHPC extends the [EpiModel](https://github.com/EpiModel/EpiModel)
R package for running stochastic network epidemic models on
high-performance computing (HPC) systems. If you are already using
EpiModel’s `netsim` function to simulate epidemic dynamics on local
hardware and need to scale up – running hundreds of simulations across
parameter scenarios on a multi-node cluster – EpiModelHPC provides the
tools to get there.

## How EpiModelHPC Relates to EpiModel

[EpiModel](https://www.epimodel.org/) is the core R package for
simulating mathematical models of infectious disease dynamics using
stochastic, individual-based network models based on exponential-family
random graph models (ERGMs). EpiModel handles network estimation
(`netest`), epidemic simulation (`netsim`), and analysis of results on a
single machine.

EpiModelHPC does not replace any of this. Instead, it wraps and extends
EpiModel’s simulation engine with functionality needed when models
become too computationally intensive for a single workstation:

- **Parallelization**: Distributes simulation replicates across multiple
  cores on an HPC node.
- **Checkpointing**: Automatically saves intermediate simulation state
  at configurable intervals, so that long-running jobs can resume from
  where they left off if interrupted (e.g., by a wall-time limit).
- **Scenario Batching**: Runs multiple parameter scenarios (defined via
  [`EpiModel::create_scenario_list`](https://epimodel.github.io/EpiModel/reference/create_scenario_list.html))
  in batched parallel jobs, with deterministic file naming for
  downstream merging.
- **Result Merging**: Merges outputs from distributed batch jobs back
  into single simulation objects or tidy data frames for analysis.

If your simulations complete in reasonable time on a laptop, you likely
do not need this package. EpiModelHPC is designed for the point at which
you need to run large numbers of replicates, sweep across many
scenarios, or your model’s per-replicate runtime exceeds what is
practical without job scheduling and checkpointing.

## How slurmworkflow Fits In

[slurmworkflow](https://github.com/EpiModel/slurmworkflow) is a
companion R package that provides a general-purpose framework for
defining and submitting multi-step Slurm job workflows from R. It
handles the mechanics of writing sbatch scripts, managing job
dependencies, and organizing output directories.

EpiModelHPC builds directly on slurmworkflow by providing **step
templates** – pre-built workflow steps tailored to common EpiModel
tasks:

| EpiModelHPC Step Template | Purpose |
|----|----|
| [`step_tmpl_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_scenarios.md) | Submit scenario-based `netsim` simulations as a Slurm array job |
| [`step_tmpl_merge_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_merge_netsim_scenarios.md) | Merge batched simulation files into one file per scenario |
| [`step_tmpl_merge_netsim_scenarios_tibble()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_merge_netsim_scenarios_tibble.md) | Convert merged results to tidy tibble format |
| [`step_tmpl_netsim_swfcalib_output()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_swfcalib_output.md) | Run simulations using calibrated parameters from [swfcalib](https://github.com/EpiModel/swfcalib) |
| [`step_tmpl_renv_restore()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_renv_restore.md) | Ensure the HPC project environment is up to date via `renv` |

Each step template has a corresponding standalone function (e.g.,
[`netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_scenarios.md))
that runs the same logic locally for testing before submitting to the
cluster.

A typical applied workflow looks like:

1.  **Estimate networks** locally with
    [`EpiModel::netest`](https://epimodel.github.io/EpiModel/reference/netest.html).
2.  **Test simulations** locally with
    [`netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_scenarios.md)
    on a small number of replicates.
3.  **Define a slurmworkflow** using
    [`step_tmpl_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_scenarios.md)
    and
    [`step_tmpl_merge_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_merge_netsim_scenarios.md)
    to run at scale on the cluster.
4.  **Merge and analyze** results locally or on the cluster.

EpiModelHPC also provides pre-configured cluster settings for specific
HPC environments
([`swf_configs_hyak()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_hyak.md)
for the University of Washington HYAK cluster,
[`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md)
for the Emory RSPH cluster) that supply sensible default sbatch options
and R module-loading commands.

## Installation

EpiModelHPC and its companion packages are hosted on GitHub. Install
with:

``` r

if (!require("remotes")) install.packages("remotes")
remotes::install_github("EpiModel/EpiModelHPC")
```

This will also install `slurmworkflow` and `swfcalib` from their GitHub
repositories.

## Key Functions

### Simulation

- **[`netsim_hpc()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md)**
  – Run `netsim` in parallel with automatic checkpointing. Best for
  single-scenario runs where checkpoint/resume is the primary need.
- **[`netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_scenarios.md)**
  – Run multiple scenarios locally with batched parallelization. Mirrors
  [`step_tmpl_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_scenarios.md)
  for local testing.

### Checkpointing

- **[`check_cp()`](http://epimodel.github.io/EpiModelHPC/reference/check_cp.md)**
  /
  **[`initialize_cp()`](http://epimodel.github.io/EpiModelHPC/reference/initialize_cp.md)**
  /
  **[`save_cpdata()`](http://epimodel.github.io/EpiModelHPC/reference/save_cpdata.md)**
  – Low-level checkpointing utilities used internally by
  [`netsim_hpc()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md).
  Checkpoint data are saved to `data/sim<N>/` directories and cleaned up
  on successful completion.

### File Management

- **[`merge_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios.md)**
  – Merge per-batch simulation files into one `netsim` object per
  scenario.
- **[`merge_netsim_scenarios_tibble()`](http://epimodel.github.io/EpiModelHPC/reference/merge_netsim_scenarios_tibble.md)**
  – Convert scenario results to a single tidy tibble per scenario with
  configurable column selection and time-step truncation.
- **[`get_scenarios_batches_infos()`](http://epimodel.github.io/EpiModelHPC/reference/get_scenarios_batches_infos.md)**
  /
  **[`get_scenarios_tibble_infos()`](http://epimodel.github.io/EpiModelHPC/reference/get_scenarios_tibble_infos.md)**
  – Inspect output directories to list available simulation files and
  their associated scenarios.

### HPC Configuration

- **[`swf_configs_hyak()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_hyak.md)**
  /
  **[`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md)**
  – Return lists of sbatch options, renv build settings, and R
  module-loading commands for supported clusters.
- **[`pull_env_vars()`](http://epimodel.github.io/EpiModelHPC/reference/pull_env_vars.md)**
  – Extract Slurm environment variables (e.g., `SLURM_ARRAY_TASK_ID`)
  into R’s global environment.

## System Requirements

While developed for Linux-based HPC clusters running the
[Slurm](https://slurm.schedmd.com/) workload manager, the core
parallelization and checkpointing functionality works on any system with
multiple cores, including macOS and Windows workstations. The
slurmworkflow integration and step templates are specific to
Slurm-managed clusters.

## Resources

- **EpiModel website**: <https://www.epimodel.org/>
- **EpiModelHPC documentation**:
  <https://epimodel.github.io/EpiModelHPC/>
- **slurmworkflow**: <https://github.com/EpiModel/slurmworkflow>
- **Bug reports**: <https://github.com/EpiModel/EpiModelHPC/issues>
