# Helper function to create the parameters for `netsim_run_swfcalib_scenario`

Helper function to create the parameters for
`netsim_run_swfcalib_scenario`

## Usage

``` r
netsim_swfcalib_output_setup(
  path_to_x,
  param,
  init,
  control,
  calib_object,
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

- calib_object:

  a formatted calibration object

- n_rep:

  The number of replication to be run for each scenario.

- n_cores:

  number of cores to run the processing on

- output_dir:

  The folder where the simulation files are to be stored.

- libraries:

  A character vector containing the name of the libraries required for
  the model to run. (e.g. EpiModelHIV or EpiModelCOVID)
