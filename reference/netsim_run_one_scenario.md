# Run one `netsim` call with a scenario and saves the results deterministically

This inner function is called by `netsim_scenarios` and
`step_tmpl_netsim_scenarios`.

## Usage

``` r
netsim_run_one_scenario(
  scenario,
  batch_num,
  path_to_x,
  param,
  init,
  control,
  libraries,
  output_dir,
  n_batch,
  n_rep,
  n_cores
)
```

## Arguments

- scenario:

  A single "`EpiModel` scenario" to be used in the simulation

- batch_num:

  The batch number, calculated from the number of replications and CPUs
  required.

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

- libraries:

  A character vector containing the name of the libraries required for
  the model to run. (e.g. EpiModelHIV or EpiModelCOVID)

- output_dir:

  The folder where the simulation files are to be stored.

- n_batch:

  The number of batches to be run `ceiling(n_rep / n_cores)`.

- n_rep:

  The number of replication to be run for each scenario.

- n_cores:

  The number of CPUs on which the simulations will be run.

## Checkpointing

This function takes care of editing `.checkpoint.dir` to create unique
sub directories for each scenario. The
[`EpiModel::control.net`](http://epimodel.github.io/EpiModel/reference/control.net.md)
way of setting up checkpoints can be used transparently.
