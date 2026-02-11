# Step Template to Create a Single Sim File per Scenarios Using the Files From `netsim_scenarios`

Step Template to Create a Single Sim File per Scenarios Using the Files
From `netsim_scenarios`

## Usage

``` r
step_tmpl_merge_netsim_scenarios_tibble(
  sim_dir,
  output_dir,
  steps_to_keep,
  cols = dplyr::everything(),
  n_cores = 1,
  setup_lines = NULL
)
```

## Arguments

- sim_dir:

  The folder where the simulation files are to be stored.

- output_dir:

  The folder where the merged files will be stored.

- steps_to_keep:

  Numbers of time steps add the end of the simulation to keep in the
  `data.frame`.

- cols:

  columns to keep in the `data.frame`. By default all columns are kept.
  And in any case, the `batch_number`, `sim` and `time` are always kept.

- n_cores:

  Parallelize the process over `n_cores` (default = 1)

- setup_lines:

  (optional) a vector of bash lines to be run first. This can be used to
  load the required modules (like R, python, etc).

## Value

a template function to be used by `add_workflow_step`

## Step Template

Step Templates are helper functions to be used within
`add_workflow_step`. Some basic ones are provided by the `slurmworkflow`
package. They instruct the workflow to run either a bash script, a set
of bash lines given as a character vector or an R script. Additional
Step Templates can be created to simplify specific tasks. The easiest
way to do so is as wrappers around existing templates.
