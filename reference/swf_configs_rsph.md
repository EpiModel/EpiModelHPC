# Preset of Configuration for the RSPH Cluster

Preset of Configuration for the RSPH Cluster

## Usage

``` r
swf_configs_rsph(
  partition = "preemptable",
  r_version = "4.2.1",
  git_version = "2.35.1",
  mail_user = NULL
)
```

## Arguments

- partition:

  Which partition to use on RSPH (either "compute" or "epimodel")

- r_version:

  Which version of R to load

- git_version:

  Which version of Git to load

- mail_user:

  The mail address to send the messages to, default is NULL (see 'sbatch
  –mail-type' argument)

## Value

a list containing `default_sbatch_opts`, `renv_sbatch_opts` and
`r_loader` (see the "hpc_configs" section)

## hpc_configs

1.  `default_sbatch_opts` is a list of sbatch options to be passed to
    [`slurmworkflow::create_workflow`](https://epimodel.github.io/slurmworkflow/reference/create_workflow.html).

2.  `renv_sbatch_opts` is a list of sbatch options to be passed to
    `slurmworkflow::step_tmpl_renv_restore`. It provides sane defaults
    for building the dependencies of an R project using `renv`

3.  `r_loader` is a set of bash lines to make the R software available.
    This is passed to the `setup_lines` arguments of the
    `slurmworkflow::step_tmpl_` functions that requires it.
