# Preset of Configuration for the HYAK Cluster

Preset of Configuration for the HYAK Cluster

## Usage

``` r
swf_configs_hyak(
  hpc = "klone",
  partition = "csde",
  r_version = "4.2.2",
  mail_user = NULL
)
```

## Arguments

- hpc:

  Which HPC to use on HYAK (either "klone" or "mox")

- partition:

  Which partition to use on HYAK (either "csde" or "ckpt")

- r_version:

  Which version of R to load

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
