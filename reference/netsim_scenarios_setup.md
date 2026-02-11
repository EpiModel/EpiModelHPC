# Helper function to create the parameters for `netsim_run_one_scenario`

Helper function to create the parameters for `netsim_run_one_scenario`

## Usage

``` r
netsim_scenarios_setup(
  path_to_x,
  param,
  init,
  control,
  scenarios_list,
  n_rep,
  n_cores,
  output_dir,
  libraries
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

## Value

a list of arguments for `netsim_run_one_scenario`
