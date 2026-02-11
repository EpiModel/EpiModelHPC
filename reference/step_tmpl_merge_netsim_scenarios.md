# Step Template to Create a Single Sim File per Scenarios Using the Files From `netsim_scenarios`

Step Template to Create a Single Sim File per Scenarios Using the Files
From `netsim_scenarios`

## Usage

``` r
step_tmpl_merge_netsim_scenarios(
  sim_dir,
  output_dir,
  keep.transmat = TRUE,
  keep.network = TRUE,
  keep.nwstats = TRUE,
  keep.other = TRUE,
  param.error = FALSE,
  keep.diss.stats = TRUE,
  truncate.at = NULL,
  n_cores = 1,
  setup_lines = NULL
)
```

## Arguments

- sim_dir:

  The folder where the simulation files are to be stored.

- output_dir:

  The folder where the merged files will be stored.

- keep.transmat:

  If `TRUE`, keep the transmission matrices from the original `x` and
  `y` elements. Note: transmission matrices only saved when
  (`save.transmat == TRUE`).

- keep.network:

  If `TRUE`, keep the `networkDynamic` objects from the original `x` and
  `y` elements. Note: network only saved when (`tergmLite == FALSE`).

- keep.nwstats:

  If `TRUE`, keep the network statistics (as set by the
  `nwstats.formula` parameter in `control.netsim`) from the original `x`
  and `y` elements.

- keep.other:

  If `TRUE`, keep the other simulation elements (as set by the
  `save.other` parameter in `control.netsim`) from the original `x` and
  `y` elements.

- param.error:

  If `TRUE`, if `x` and `y` have different params (in
  [`param.net`](http://epimodel.github.io/EpiModel/reference/param.net.md))
  or controls (passed in
  [`control.net`](http://epimodel.github.io/EpiModel/reference/control.net.md))
  an error will prevent the merge. Use `FALSE` to override that check.

- keep.diss.stats:

  If `TRUE`, keep `diss.stats` from the original `x` and `y` objects.

- truncate.at:

  Time step at which to left-truncate the time series.

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
