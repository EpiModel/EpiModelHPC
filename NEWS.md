# EpiModelHPC 2.7.0

## BREAKING CHANGES

-   Removed all legacy HPC functions. Their functionality is now covered by
    EpiModel's built-in controls and the scenario pipeline in this package:
    -   `netsim_hpc()` -- use `EpiModel::netsim()` directly with
        `ncores` in `control.net()` for parallelism.
    -   `check_cp()`, `initialize_cp()`, `save_cpdata()` -- use EpiModel's
        `.checkpoint.dir` and `.checkpoint.steps` in `control.net()`.
    -   `savesim()`, `merge_simfiles()`, `process_simfiles()` -- use
        `merge_netsim_scenarios()` or `merge_netsim_scenarios_tibble()`.
    -   `sbatch_master()` -- use `slurmworkflow` step templates
        (`step_tmpl_netsim_scenarios()`, etc.).
    -   `pull_env_vars()` -- handled internally by `slurmworkflow`.
    -   `swf_configs_hyak()`, `swf_configs_rsph()` -- pass SLURM
        configuration directly to `slurmworkflow` step functions.

-   Dropped dependencies: `doParallel`, `foreach`, `ergm`, `tergm`, `tidyr`,
    `network`.

-   Now requires EpiModel >= 2.7.0.

## OTHER

-   Package scope narrowed to scenario orchestration (`netsim_scenarios`,
    `netsim_swfcalib_output`), `slurmworkflow` step templates, and `swfcalib`
    integration helpers.
