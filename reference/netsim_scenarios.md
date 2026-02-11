# Function to run EpiModel network simulations with scenarios

This function will run `n_rep` replications of each scenarios in the
`scenarios_list`. It runs them as multiple batches of up to `n_cores`
simulations at a time. The simfiles are then stored in the `output_dir`
folder and are named using the following pattern:
"sim\_\_name_of_scenario\_\_2.rds". Where the last number is the batch
number for this particular scenario. Each scenario is therefore run over
`ceiling(n_rep / n_cores)` batches. This function is meant to mimic the
behavior of `step_tmpl_netsim_scenarios` in your local machine. It
should fail in a similar fashion an reciprocally, if it runs correctly
locally, moving to an HPC should not produce any issue.

## Usage

``` r
netsim_scenarios(
  path_to_x,
  param,
  init,
  control,
  scenarios_list,
  n_rep,
  n_cores,
  output_dir,
  libraries = NULL,
  ...
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

- scenarios_list:

  A list of scenarios to be run. Produced by the
  [`EpiModel::create_scenario_list`](http://epimodel.github.io/EpiModel/reference/create_scenario_list.md)
  function

- n_rep:

  The number of replication to be run for each scenario.

- n_cores:

  The number of CPUs on which the simulations will be run.

- output_dir:

  The folder where the simulation files are to be stored.

- libraries:

  A character vector containing the name of the libraries required for
  the model to run. (e.g. EpiModelHIV or EpiModelCOVID)

- ...:

  for compatibility reasons

## Checkpointing

This function takes care of editing `.checkpoint.dir` to create unique
sub directories for each scenario. The
[`EpiModel::control.net`](http://epimodel.github.io/EpiModel/reference/control.net.md)
way of setting up checkpoints can be used transparently.
