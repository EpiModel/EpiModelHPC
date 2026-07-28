# Preset of Configuration for the RSPH Cluster

Preset of Configuration for the RSPH Cluster

## Usage

``` r
swf_configs_rsph(
  partition = "preemptable",
  r_version = "4.5.1",
  mail_user = NULL,
  cleanup_workers = TRUE
)
```

## Arguments

- partition:

  Which partition to use on RSPH (either "compute" or "epimodel")

- r_version:

  Which version of R to load

- mail_user:

  The mail address to send the messages to, default is NULL (see 'sbatch
  –mail-type' argument)

- cleanup_workers:

  If `TRUE` (the default), append
  [`swf_cleanup_r_workers`](http://epimodel.github.io/EpiModelHPC/reference/swf_cleanup_r_workers.md)
  to `r_loader` so each step reaps its own R workers on cancel or
  timeout. RSPH has no cgroup containment, so without this, workers
  survive `scancel` and squat on cores SLURM has re-allocated, starving
  later tasks. See
  [`swf_cleanup_r_workers`](http://epimodel.github.io/EpiModelHPC/reference/swf_cleanup_r_workers.md).

## Value

a list containing `default_sbatch_opts`, `renv_sbatch_opts` and
`r_loader` (see the "hpc_configs" section)

## Node setup

`r_loader` sources the shared spack environment, unloads everything, and
loads R. It deliberately does not load git: git is on the default path
on RSPH, and the project template has not loaded it for some time. The
`git_version` argument was removed accordingly.

## hpc_configs

1.  `default_sbatch_opts` is a list of sbatch options to be passed to
    [`slurmworkflow::create_workflow`](https://epimodel.github.io/slurmworkflow/reference/create_workflow.html).

2.  `renv_sbatch_opts` is a list of sbatch options to be passed to
    `slurmworkflow::step_tmpl_renv_restore`. It provides sane defaults
    for building the dependencies of an R project using `renv`

3.  `r_loader` is a set of bash lines to make the R software available.
    This is passed to the `setup_lines` arguments of the
    `slurmworkflow::step_tmpl_` functions that requires it.
