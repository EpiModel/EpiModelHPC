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
  [`EpiModel::netsim`](https://epimodel.github.io/EpiModel/reference/netsim.html)
  function)

- param:

  Model parameters, as an object of class
  [`param.net`](https://epimodel.github.io/EpiModel/reference/param.net.html).
  Includes transmission probability (`inf.prob`), act rate (`act.rate`),
  recovery rate (`rec.rate`), and demographic rates for models with
  vital dynamics. Custom parameters for extended models may also be
  passed through `param.net`.

- init:

  Initial conditions, as an object of class
  [`init.net`](https://epimodel.github.io/EpiModel/reference/init.net.html).
  Specifies the initial number of infected nodes (`i.num`) and, for SIR
  models, recovered nodes (`r.num`). For two-group models, the
  corresponding `.g2` parameters are also required.

- control:

  Control settings, as an object of class
  [`control.net`](https://epimodel.github.io/EpiModel/reference/control.net.html).
  Key settings include `type` (disease model: `"SI"`, `"SIR"`, or
  `"SIS"`), `nsteps` (number of time steps), `nsims` (number of
  simulations), `tergmLite` (lightweight mode for performance), and
  `resimulate.network` (required for models with vital dynamics). For
  extended models, custom module functions are also passed here.

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
[`EpiModel::control.net`](https://epimodel.github.io/EpiModel/reference/control.net.html)
way of setting up checkpoints can be used transparently.
