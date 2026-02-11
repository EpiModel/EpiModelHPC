# Stochastic Network Models on High-Performance Computing Systems

Simulates stochastic network epidemic models for infectious disease
dynamics in parallel.

## Usage

``` r
netsim_hpc(
  x,
  param,
  init,
  control,
  cp.save.int = NULL,
  save.min = TRUE,
  save.max = FALSE,
  compress = TRUE,
  verbose = TRUE
)
```

## Arguments

- x:

  Character vector containing the file path of an Rdata file where an
  object of class `netest` is stored. Alternatively, if restarting a
  previous simulation, this may be a file path for an object of class
  `netsim`.

- param:

  Model parameters, as an object of class `param.net`.

- init:

  Initial conditions, as an object of class `init.net`.

- control:

  Control settings, as an object of class `control.net`.

- cp.save.int:

  Check-pointing save interval, which is used to specify how often
  intermediate data should be saved out to disk. When a job has been
  check-pointed, it will resume automatically at the last saved time
  step stored on disk. If set to `NULL`, then no intermediate data
  storage will occur.

- save.min:

  Argument passed to
  [`savesim`](http://epimodel.github.io/EpiModelHPC/reference/savesim.md).

- save.max:

  Argument passed to
  [`savesim`](http://epimodel.github.io/EpiModelHPC/reference/savesim.md).

- compress:

  Matches the `compress` argument for the
  [`save`](https://rdrr.io/r/base/save.html) function.

- verbose:

  If `FALSE`, suppress all output messages except errors.

## Details

This function provides a systematic method to running stochastic network
models in parallel on high-performance computing systems.

The main purpose of using `netsim_hpc` is for a standardized
checkpointing method. Checkpointing is defined as incrementally saving
simulation data for the purpose of reloading it if a simulation job is
canceled and restarted. If checkpointing is not needed, users are
advised to run their models directly with the
[`EpiModel::netsim`](http://epimodel.github.io/EpiModel/reference/netsim.md)
function.

This function performs the following tasks:

1.  Check for the existence of checkpointed data, using the
    [`check_cp`](http://epimodel.github.io/EpiModelHPC/reference/check_cp.md)
    function. If CP data are available, a checkpointed model will be
    run, else a new model will be run.

2.  Create a checkpoint directory if one does not exist at
    "data/simsimno". This and the related checkpointing functions will
    not occur if `cp.save.int` is set to `NULL`.

3.  Sets the checkpoint save interval at the number of time steps
    specified in `cp.save.int`.

4.  Resets the initialize module function to
    [`initialize_cp`](http://epimodel.github.io/EpiModelHPC/reference/initialize_cp.md)
    if in checkpoint state.

5.  Run the simulation, either new or checkpointed, with a call to
    [`EpiModel::netsim`](http://epimodel.github.io/EpiModel/reference/netsim.md).

6.  Save the completed simulation data, using the functionality of
    [`savesim`](http://epimodel.github.io/EpiModelHPC/reference/savesim.md).

7.  Remove the checkpointed data and file directory created in step 1,
    if it exists.

The `x` argument must specify a **file name** in a character string,
rather than a `netest` or `netsim` class object directly. This is mainly
for efficiency purposes in running the models in parallel.

If `save.min` and `save.max` are both set to `FALSE`, then the function
will return rather than save the output EpiModel object.
