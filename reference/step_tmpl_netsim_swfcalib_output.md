# Step template to run sims with the result of an `swfcalib` calibration

Step template to run sims with the result of an `swfcalib` calibration

## Usage

``` r
step_tmpl_netsim_swfcalib_output(
  path_to_x,
  param,
  init,
  control,
  calib_object,
  n_rep,
  n_cores,
  output_dir,
  libraries = NULL,
  setup_lines = NULL,
  max_array_size = NULL
)
```

## Arguments

- path_to_x:

  Path to a Fitted network model object saved with `saveRDS`. (See the
  `x` argument to the
  [`EpiModel::netsim`](http://epimodel.github.io/EpiModel/reference/netsim.md)
  function)

- param:

  Model parameters, as an object of class `param.net`.

- init:

  Initial conditions, as an object of class `init.net`.

- control:

  Control settings, as an object of class `control.net`.

- calib_object:

  a formatted calibration object

- n_rep:

  The number of replication to be run for each scenario.

- n_cores:

  The number of CPUs on which the simulations will be run.

- output_dir:

  The folder where the simulation files are to be stored.

- libraries:

  A character vector containing the name of the libraries required for
  the model to run. (e.g. EpiModelHIV or EpiModelCOVID)

- setup_lines:

  (optional) a vector of bash lines to be run first. This can be used to
  load the required modules (like R, python, etc).

- max_array_size:

  maximum number of array jobs to be submitted at the same time. Should
  be strictly less than the maximum number of jobs you are allowed to
  submit to slurm on your HPC.

## Value

a template function to be used by `add_workflow_step`

## Checkpointing

This function takes care of editing `.checkpoint.dir` to create unique
sub directories for each scenario. The
[`EpiModel::control.net`](http://epimodel.github.io/EpiModel/reference/control.net.md)
way of setting up checkpoints can be used transparently.

## Step Template

Step Templates are helper functions to be used within
`add_workflow_step`. Some basic ones are provided by the `slurmworkflow`
package. They instruct the workflow to run either a bash script, a set
of bash lines given as a character vector or an R script. Additional
Step Templates can be created to simplify specific tasks. The easiest
way to do so is as wrappers around existing templates.
